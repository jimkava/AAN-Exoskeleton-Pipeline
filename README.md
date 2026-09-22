# A Computational Framework for Actuator Selection in Assist-as-Needed Lower-Limb Exoskeletons

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![MATLAB](https://img.shields.io/badge/MATLAB-R2026a-orange.svg)
![OpenSim](https://img.shields.io/badge/OpenSim-4.5-blue.svg)

**Dimitrios Kavalieros, Panagiotis Vartholomeos** — *IEEE Transactions on Medical Robotics and Bionics* (submitted)

Code, models and data accompanying the paper. Progressive vasti weakness (20 %, 30 %, 50 %) is
induced in the OpenSim gait2392 model, a CMC diagnostic bounds the knee torque deficit, an
Adaptive Supervisor sets the exoskeleton penalty weight of an OpenSim MocoInverse problem from the
weakness level, and the resulting assistive torque drives an automated BLDC motor selection over a
cloud-hosted PostgreSQL database.

---

## 1. Repository structure

```
01_Input_Files/                 model, experimental data, OpenSim setup and constraint files
02_NORMAL/OutputReference/      unimpaired model and CMC solution (initial states, normal FD)
02_NORMAL/05_FD_NORMAL/Results/ unimpaired forward-dynamics kinematics (reference for figures)
03_projectGait2392_weakness/    weakness models, generation scripts, prescribed kinematics,
                                CMC / FD results used by the figures
04_Moco_AAN/                    static baseline, adaptive AAN, fixed-weight sweep, CMC-exo
                                verification, post-processing, motor selection
    Database Files/             motor database and database access functions
    Results_v3_Static/          MocoInverse solutions, Static Gap Strategy (Table V)
    Results_v3_Adaptive/        MocoInverse solutions, Adaptive architecture (Table V)
    Results_v5_CMC_Exo/         CMC-exo forward-dynamics kinematics used by the figures
05_Plots/                       figure scripts
    paper_figures/              figure files exactly as published
```

All scripts locate the repository root from their own position, so the repository can be cloned
anywhere.

---

## 2. Pipeline

| Paper | Stage | Script |
|---|---|---|
| §II-A | Weakness models: `F_max` of `vas_med_r`, `vas_int_r`, `vas_lat_r` scaled by λ ∈ {0.8, 0.7, 0.5} | `03_.../create_weak20_model.py`, `create_weak30_model.py`, `create_weak50_model.py` |
| §II-B | Prescribed kinematics: stance-phase Gaussian offsets on `knee_angle_r` | `03_.../create_newik_weak20.py` |
| §III-B, Table V | Static Gap Strategy baseline (w<sub>exo</sub> = 2,000) | `04_Moco_AAN/run_Gait2392_STATIC_GAP_v3.m` |
| §III-B, Table VI | Fixed-w<sub>exo</sub> sweep | `04_Moco_AAN/run_Gait2392_WEXO_SWEEP.m` |
| §III-C–F | Adaptive Supervisor + MocoInverse | `04_Moco_AAN/run_Gait2392_ADAPTIVE_AAN_v3.m` |
| §III-B, Table V | Filtered peaks and RMS (`SET = 'static'` or `'adaptive'`) | `04_Moco_AAN/FesRobex_FilterCheck.m` |
| §IV | CMC-exo verification | `04_Moco_AAN/run_Gait2392_CMC_WithExo_v5.m` |
| §V | Motor selection + cloud write-back | `04_Moco_AAN/run_MotorSelection_v6.m` |

The weakness models (`.osim`) and prescribed kinematics for all three levels are included directly,
so the MATLAB pipeline runs without the Python step.

---

## 2a. CMC diagnostic and forward dynamics (§II, §IV)

These stages run with the OpenSim CMC and Forward tools from the setup files in `01_Input_Files/`.
All paths inside the setup files are relative to that folder. Run from the OpenSim GUI
(Tools → Load setup) or from a command prompt in `01_Input_Files/`:

```
opensim-cmd run-tool Setup_CMC_weak50.xml
```

| Paper | Setup files | Target kinematics |
|---|---|---|
| Table IV (reserve limits ±1000 Nm) | `Setup_CMC_weak20.xml`, `_weak30.xml`, `_weak50.xml` | RRA kinematics of the unimpaired trial |
| §II-C (bounded reserve, ±25 / ±30 Nm) | `Setup_CMC_weak20_noknee30.xml`, `_weak30_noknee25.xml`, `_weak50_noknee.xml` | unimpaired IK |
| Table III, Figs. 6–7 | `Setup_CMC_normal.xml`, `_weak20_newik.xml`, `_weak30_newik.xml`, `_weak50_newik.xml` | prescribed kinematics (§II-B) |
| Figs. 3–5 | `Setup_Forward_normal.xml`, `_weak20_newik.xml`, `_weak30_newik.xml`, `_weak50_newik.xml` | driven by the corresponding CMC excitations |
| §IV-B | `Setup_Forward_weak20.xml`, `_weak30.xml`, `_weak50.xml`, `_weak50_noknee25.xml`, `_weak30_noknee25.xml` | driven by the corresponding CMC excitations |

Each Forward setup reads the controls and states written by the matching CMC run, so the CMC setup
must be run first. The repository includes only the CMC and FD outputs used by the figures.

`Setup_CMC_weak30_newik.xml` is a reconstruction: the original file was not preserved. It is
derived from `Setup_CMC_weak50_newik.xml`, with the start time taken from the original output
(see the comment at the top of the file).

---

## 3. Method summary

**Adaptive Supervisor (Eq. 9).**

$$w_{\mathrm{exo}}(\beta) = 10^{\,5 - 4\,\frac{\beta - \beta_{\min}}{\beta_{\max} - \beta_{\min}}},\qquad \beta_{\min} = 0.20,\ \beta_{\max} = 0.50$$

giving w<sub>exo</sub> = 100,000 / 4,642 / 10 for 20 / 30 / 50 % weakness. All muscles share
w<sub>m</sub> = 10⁻⁴ and all reserve actuators w<sub>c</sub> = 10⁴. Reserves are placed at every
degree of freedom except the right knee, where `knee_exo_device` takes that role (Eq. 6–7).

**Solver.** MocoInverse (CasADi / IPOPT, limited-memory Hessian), `mesh_interval = 0.035`,
`convergence_tolerance = 1e-1`, `max_iterations = 1000`. DeGroote–Fregly 2016 muscles.

**Post-processing (§III-B).** The exoskeleton control channel is low-pass filtered at 6 Hz
(fourth-order, zero-phase Butterworth). Peaks are the maxima of the filtered profiles within the
interior of the gait cycle (5–95 %); RMS values are computed over the complete cycle. The same
procedure is applied to both columns of Table V.

**Motor selection (§V-A).** Gear ratio G = 50 : 1, η = 0.8 (Eq. 11); winding temperature against
the 125 °C Class F limit with R<sub>th1</sub> = 8.0 °C/W (Eq. 12); supply-voltage check (Eq. 13);
lightest motor from a database of 34 BLDC actuators satisfying all criteria. Safety margin per
Eq. 14.

---

## 4. Results

**Assistive torque (Table V).**

| Weakness | w<sub>exo</sub> | Static peak / RMS (Nm) | Adaptive peak / RMS (Nm) |
|---|---|---|---|
| 20 % | 100,000 | 0.39 / 0.24 | 0.03 / 0.02 |
| 30 % | 4,642 | 0.41 / 0.28 | 0.23 / 0.15 |
| 50 % | 10 | 0.41 / 0.27 | 4.57 / 1.81 |

The adaptive solution at 20 % weakness reached the iteration limit before meeting the
dual-feasibility criterion; its value is reported for completeness. The solver status of each run
is recorded in the header of its `.sto` file.

**Fixed-w<sub>exo</sub> sweep (Table VI).** Severe-to-mild ratio 1.05 / 1.05 / 0.67 / 0.99 for
w<sub>exo</sub> = 2,000 / 200 / 20 / 2, against 152 for the adaptive law. All fixed-weight runs
converged.

**CMC-exo verification (§IV-B).** Knee-angle RMSE to normal gait: 1.37° / 1.43° / 1.36° for
Weak20 / Weak30 / Weak50.

**Motor selection (Table VII).**

| | Weak20 | Weak30 | Weak50 |
|---|---|---|---|
| Peak / RMS shaft torque (mNm) | 0.80 / 0.52 | 5.79 / 3.83 | 114.20 / 45.24 |
| Shaft speed (rpm) | 3275 | 3275 | 3275 |
| Selected motor (Maxon EC 45 flat, 30 W, 96 g) | PN 200142, 12 V | PN 200142, 12 V | PN 339282, 36 V |
| Required voltage (V) | 8.8 | 9.0 | 35.1 |
| Peak winding temperature (°C) | 25.0 | 25.2 | 47.0 |
| Safety margin (%) | 99.7 | 97.7 | 69.9 |

The Weak50 transition to the 36 V winding is driven by the electrical criterion (Eq. 13). Hardware
rating at the knee: 5.34 Nm (17 % above the 4.57 Nm peak).

---

## 5. Figures

Each script in `05_Plots/` regenerates one published figure from data included in the repository.
The files in `05_Plots/paper_figures/` are the exact versions used in the paper; some received final
layout adjustments after export. Figs. 2, 8 and 12 are drawn in TikZ within the manuscript.

| Fig. | Published file | Script |
|---|---|---|
| 1 | `Atrophy_Models_Panel7.jpg` | OpenSim GUI screenshot |
| 3 | `NewIK_knee_4levels_final4_a3.pdf` | `FesRobex_NewIK_KneePlot_4levels2.m` |
| 4 | `NewIK_knee_4levels_final4_b3.pdf` | `FesRobex_NewIK_KneePlot_4levels2.m` |
| 5 | `knee_velocity_4levels3.pdf` | `run_KneeVelocity_v2.m` |
| 6 | `Fig5_Activations_4levels2.pdf` | `FesRobex_Fig5_Activations_4levels.m` |
| 7 | `Fig6_ActiveForce_4levels.pdf` | `FesRobex_Fig4_ActiveForce_4levels.m` |
| 9 | `Fig8_exo_response_curve5.pdf` | `FesRobex_Fig8_ResponseCurve_v4.m` |
| 10 | `fig9_Exo_Assistance1.pdf` | `FesRobex_Fig9_ExoAssistance_v4.m` |
| 11 | `Fig_FD_CMCExo_Restoration1.pdf` | `plot_FD_CMCExo_Restoration.m` |

---

## 6. Requirements

- MATLAB (developed on R2026a) with the Signal Processing Toolbox
- OpenSim 4.5 with the MATLAB API configured
- Python with the `opensim` package — only for regenerating the weakness models
- `run_Gait2392_CMC_WithExo_v5.m` calls the OpenSim command-line tool at
  `C:\OpenSim 4.5\bin\opensim-cmd.exe`; edit the `run_tool` function if OpenSim is installed elsewhere
- Optional, for cloud write-back: the PostgreSQL JDBC driver (`postgresql-*.jar`, not included),
  placed in `04_Moco_AAN/Database Files/`

---

## 7. Cloud layer (optional)

`run_MotorSelection_v6.m` reads the motor database from Supabase (PostgreSQL) through a JDBC
connection and writes one row per scenario to the `simulation_results` table. Write-back is
DELETE-before-INSERT on the scenario key, so re-running replaces rows instead of duplicating them.
Results are shown in a Google Looker Studio dashboard:
[FesRobex: Cloud-integrated database for exoskeleton actuators](https://fesrobex.info/bio-actuator-pipeline/).

**No credentials are stored in this repository.** `connectToSupabase.m` reads them from environment
variables. On Windows, set them once in a command prompt and restart MATLAB:

```
setx SUPABASE_HOST "<host>"
setx SUPABASE_PORT "5432"
setx SUPABASE_DB   "postgres"
setx SUPABASE_USER "<user>"
setx SUPABASE_PASS "<password>"
```

**Without a database connection** the script falls back to the local copy of the motor database,
`Database Files/Maxon_MASTER_Combined_sqlDB.csv`, performs the full selection, and skips the
write-back. The cloud layer is therefore not needed to reproduce the results.

---

## 8. Reproduction

```matlab
cd 04_Moco_AAN
run_Gait2392_ADAPTIVE_AAN_v3    % optional: regenerates Results_v3_Adaptive (several hours)
FesRobex_FilterCheck            % Table V: SET = 'adaptive' -> 0.03 / 0.23 / 4.57 Nm
                                %          SET = 'static'   -> 0.39 / 0.41 / 0.41 Nm
run_MotorSelection_v6           % Table VII (local CSV if no database connection)
```

The MocoInverse solutions of both architectures are included, so the last two steps run in
seconds without re-solving.

---

## 9. Citation

D. Kavalieros and P. Vartholomeos, "A Computational Framework for Actuator Selection in
Assist-as-Needed Lower-Limb Exoskeletons," *IEEE Transactions on Medical Robotics and Bionics*
(submitted). Full citation details will be added on publication.

## 10. License

MIT — see [`LICENSE`](LICENSE).
