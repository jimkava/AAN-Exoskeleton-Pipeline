from __future__ import annotations

import json
import os
import re
import sqlite3
import subprocess
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

HERE = Path(__file__).resolve().parent
DATA = Path(os.environ.get("AAN_DATA_DIR", HERE / "local_data")).resolve()
DB = DATA / "sessions.sqlite3"
SETTINGS_PATH = HERE / "settings.json"
DATA.mkdir(parents=True, exist_ok=True)
JOBS: dict[str, dict] = {}
LOCK = threading.Lock()

app = FastAPI(title="AAN Research Orchestrator", version="0.1.0")
app.mount("/static", StaticFiles(directory=HERE / "static"), name="static")


def db():
    con = sqlite3.connect(DB)
    con.row_factory = sqlite3.Row
    return con


with db() as con:
    con.execute("""
        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            participant_code TEXT NOT NULL,
            cohort TEXT NOT NULL,
            created_at TEXT NOT NULL,
            data_json TEXT NOT NULL
        )
    """)


class StrengthTest(BaseModel):
    left_max_force_n: float = Field(gt=0)
    right_max_force_n: float = Field(gt=0)
    left_lever_arm_m: float = Field(gt=0, le=1)
    right_lever_arm_m: float = Field(gt=0, le=1)
    trials_left_n: list[float] = Field(default_factory=list)
    trials_right_n: list[float] = Field(default_factory=list)


class SessionIn(BaseModel):
    participant_code: str = Field(min_length=2, max_length=32)
    cohort: Literal["healthy", "patient"]
    consent_confirmed: bool
    body_mass_kg: float = Field(gt=0, le=300)
    height_m: float = Field(gt=0.5, le=2.5)
    thigh_length_m: float = Field(gt=0, le=1.2)
    shank_length_m: float = Field(gt=0, le=1.2)
    trunk_length_m: float = Field(gt=0, le=1.2)
    knee_extensor_test: StrengthTest


def load_settings() -> dict:
    if not SETTINGS_PATH.exists():
        return {}
    try:
        return json.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def clean_code(code: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_-]{2,32}", code):
        raise HTTPException(422, "Use a pseudonymous code (letters, numbers, _ or -), not a name.")
    return code


def get_session(session_id: str):
    with db() as con:
        row = con.execute("SELECT * FROM sessions WHERE id = ?", (session_id,)).fetchone()
    if not row:
        raise HTTPException(404, "Session not found.")
    return row


def run_job(job_id: str, command: list[str], cwd: Path, log_path: Path):
    try:
        with log_path.open("w", encoding="utf-8") as log:
            proc = subprocess.Popen(command, cwd=str(cwd), stdout=log, stderr=subprocess.STDOUT, shell=False)
            with LOCK:
                JOBS[job_id]["pid"] = proc.pid
                JOBS[job_id]["status"] = "running"
            code = proc.wait()
        with LOCK:
            JOBS[job_id]["status"] = "completed" if code == 0 else "failed"
            JOBS[job_id]["return_code"] = code
    except Exception as exc:
        with LOCK:
            JOBS[job_id]["status"] = "failed"
            JOBS[job_id]["error"] = str(exc)


def start_job(stage: str, command: list[str], cwd: Path, session_id: str):
    job_id = str(uuid.uuid4())
    log_path = DATA / session_id / "logs" / f"{stage}-{job_id}.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with LOCK:
        JOBS[job_id] = {"id": job_id, "session_id": session_id, "stage": stage, "status": "queued", "log": str(log_path)}
    threading.Thread(target=run_job, args=(job_id, command, cwd, log_path), daemon=True).start()
    return job_id


@app.get("/")
def home():
    return FileResponse(HERE / "static" / "index.html")


@app.get("/api/health")
def health():
    settings = load_settings()
    return {
        "ok": True,
        "app_version": app.version,
        "configured": {
            "pose2sim_python": bool(settings.get("pose2sim_python")),
            "opensim_python": bool(settings.get("opensim_python")),
            "gait2392_model": bool(settings.get("gait2392_model")),
            "matlab_exe": bool(settings.get("matlab_exe")),
        },
        "stages": {
            "pose2sim": "launchable when configured with a per-session Config.toml",
            "scale_ik": "launchable when Pose2Sim TRC files and gait2392 paths are configured",
            "mocotrack": "awaiting the P3 contact-sphere setup and validation",
            "aan_matlab": "awaiting a participant-parameterized P3 MATLAB entry point",
            "motor_selection": "awaiting the participant-parameterized MATLAB handoff",
            "target_joint": "research method from P3 section 14 still needs implementation and validation",
        },
    }


@app.get("/api/sessions")
def list_sessions():
    with db() as con:
        rows = con.execute("SELECT id, participant_code, cohort, created_at, data_json FROM sessions ORDER BY created_at DESC").fetchall()
    return [
        {"id": r["id"], "participant_code": r["participant_code"], "cohort": r["cohort"],
         "created_at": r["created_at"], "measurements": json.loads(r["data_json"])}
        for r in rows
    ]


@app.post("/api/sessions")
def create_session(payload: SessionIn):
    code = clean_code(payload.participant_code)
    if not payload.consent_confirmed:
        raise HTTPException(422, "Confirm that the required consent/ethics steps are complete before recording research data.")
    strength = payload.knee_extensor_test
    t_left = strength.left_max_force_n * strength.left_lever_arm_m
    t_right = strength.right_max_force_n * strength.right_lever_arm_m
    beta = 1.0 - (t_right / t_left)
    record = payload.model_dump()
    record["knee_extensor_test"]["torque_left_nm"] = t_left
    record["knee_extensor_test"]["torque_right_nm"] = t_right
    record["beta_raw"] = beta
    record["lambda_raw"] = 1.0 - beta
    record["p2_domain_warning"] = not (0 <= beta <= 1)
    record["created_at"] = datetime.now(timezone.utc).isoformat()
    session_id = str(uuid.uuid4())
    (DATA / session_id).mkdir(parents=True, exist_ok=True)
    with db() as con:
        con.execute(
            "INSERT INTO sessions(id, participant_code, cohort, created_at, data_json) VALUES(?,?,?,?,?)",
            (session_id, code, payload.cohort, record["created_at"], json.dumps(record)),
        )
    return {"id": session_id, "measurements": record}


@app.get("/api/sessions/{session_id}")
def session_detail(session_id: str):
    row = get_session(session_id)
    return {"id": row["id"], "participant_code": row["participant_code"], "cohort": row["cohort"],
            "created_at": row["created_at"], "measurements": json.loads(row["data_json"])}


@app.put("/api/sessions/{session_id}/media/{camera}")
async def upload_video(session_id: str, camera: Literal["cam01", "cam02", "cam03"], file: UploadFile = File(...)):
    get_session(session_id)
    suffix = Path(file.filename or "").suffix.lower()
    if suffix not in {".mp4", ".mov", ".m4v"}:
        raise HTTPException(415, "Upload a camera video (.mp4, .mov, .m4v).")
    destination = DATA / session_id / "videos" / f"{camera}{suffix}"
    destination.parent.mkdir(parents=True, exist_ok=True)
    size = 0
    with destination.open("wb") as out:
        while chunk := await file.read(1024 * 1024):
            size += len(chunk)
            if size > 2 * 1024 * 1024 * 1024:
                out.close()
                destination.unlink(missing_ok=True)
                raise HTTPException(413, "Video exceeds the 2 GB per-file limit.")
            out.write(chunk)
    return {"saved": True, "camera": camera, "bytes": size, "path": str(destination)}


@app.put("/api/sessions/{session_id}/pose2sim-config")
async def upload_pose_config(session_id: str, file: UploadFile = File(...)):
    get_session(session_id)
    if Path(file.filename or "").name.lower() != "config.toml":
        raise HTTPException(415, "Upload a Pose2Sim file named Config.toml.")
    content = await file.read(1024 * 1024 + 1)
    if len(content) > 1024 * 1024:
        raise HTTPException(413, "Config.toml exceeds the 1 MB limit.")
    destination = DATA / session_id / "Config.toml"
    destination.write_bytes(content)
    return {"saved": True, "path": str(destination)}


@app.put("/api/sessions/{session_id}/calibration/{kind}/{camera}")
async def upload_calibration(session_id: str, kind: Literal["intrinsics", "extrinsics"],
                             camera: Literal["cam01", "cam02", "cam03"], file: UploadFile = File(...)):
    get_session(session_id)
    suffix = Path(file.filename or "").suffix.lower()
    if suffix not in {".mp4", ".mov", ".m4v", ".toml", ".yaml", ".yml", ".json"}:
        raise HTTPException(415, "Unsupported calibration asset.")
    folder = DATA / session_id / "calibration" / kind / camera
    folder.mkdir(parents=True, exist_ok=True)
    destination = folder / f"calibration{suffix}"
    content = await file.read(2 * 1024 * 1024 * 1024 + 1)
    if len(content) > 2 * 1024 * 1024 * 1024:
        raise HTTPException(413, "Calibration asset exceeds the 2 GB limit.")
    destination.write_bytes(content)
    return {"saved": True, "kind": kind, "camera": camera, "bytes": len(content)}


@app.get("/api/jobs/{job_id}")
def job_status(job_id: str):
    with LOCK:
        job = JOBS.get(job_id)
    if not job:
        raise HTTPException(404, "Job not found in this app run.")
    safe = dict(job)
    log = Path(safe.pop("log"))
    safe["log_tail"] = log.read_text(encoding="utf-8", errors="replace")[-12000:] if log.exists() else ""
    return safe


@app.post("/api/sessions/{session_id}/run/{stage}")
def run_stage(session_id: str, stage: Literal["pose2sim", "scale_ik", "mocotrack", "aan_matlab", "motor_selection"]):
    row = get_session(session_id)
    settings = load_settings()
    workspace = DATA / session_id
    if stage == "pose2sim":
        executable = settings.get("pose2sim_python")
        config = workspace / "Config.toml"
        if not executable or not Path(executable).is_file():
            raise HTTPException(409, "Configure pose2sim_python in settings.json first.")
        if not config.is_file():
            raise HTTPException(409, "Place a reviewed Pose2Sim Config.toml in this session workspace before running.")
        command = [str(executable), "-c", "from Pose2Sim import Pose2Sim; Pose2Sim.runAll()"]
        return {"job_id": start_job(stage, command, workspace, session_id), "status": "queued"}

    if stage == "scale_ik":
        python = settings.get("opensim_python")
        script = settings.get("p2s_gait2392_script")
        model = settings.get("gait2392_model")
        if not all(v and Path(v).is_file() for v in (python, script, model)):
            raise HTTPException(409, "Configure opensim_python, p2s_gait2392_script and gait2392_model in settings.json.")
        trc_files = sorted(p for p in workspace.rglob("*.trc") if "lstm" in p.name.lower())
        if not trc_files:
            raise HTTPException(409, "No Pose2Sim *_LSTM.trc output found.")
        trc = trc_files[-1]
        measurements = json.loads(row["data_json"])
        cmd = [str(python), str(script), "--model", str(model), "--static", str(trc),
               "--static_t", *map(str, settings.get("static_time_s", [0.5, 2.0])),
               "--walk", str(trc), "--mass", str(measurements["body_mass_kg"]),
               "--name", row["participant_code"], "--out", str(workspace / "gait2392")]
        return {"job_id": start_job(stage, cmd, workspace, session_id), "status": "queued"}

    raise HTTPException(501, "This P3 stage is not ready to run. The app will not call the P2 demo inputs or present them as participant results.")


@app.get("/api/sessions/{session_id}/files")
def list_files(session_id: str):
    get_session(session_id)
    root = DATA / session_id
    return [{"path": str(p.relative_to(root)), "bytes": p.stat().st_size}
            for p in root.rglob("*") if p.is_file()]


if __name__ == "__main__":
    import uvicorn
    host = "0.0.0.0" if os.environ.get("AAN_LAN", "").lower() == "true" else "127.0.0.1"
    uvicorn.run(app, host=host, port=int(os.environ.get("AAN_PORT", "8765")))
