"""
FesRobex Project — New IK Generation for Weak20
================================================
Creates subject01_walk1_ik_weak20.mot with Gaussian-weighted
stance-phase offset of -5 degrees on knee_angle_r.

Based on the same methodology used for Weak30 (-8 deg) and
Weak50 (-15 deg) — Gaussian offset applied ONLY during stance
phase (t=0.60 to 1.20s), swing phase unchanged.

Scientific basis:
- Reserve actuator analysis: Weak20 = -25.62 Nm deficit
- Constrained reserve experiment: ~5 deg deviation at 20% weakness
- Linear interpolation: 0%->0deg, 30%->8deg, 50%->15deg
- Clinical: quadriceps avoidance gait (Berchuck 1990, Shuman 2011)

Author: Dimitrios Kavalieros
Date:   June 2026
"""

from pathlib import Path
import numpy as np

# ============================================================
# PATHS
# ============================================================
ROOT   = Path(__file__).resolve().parents[1]   # repo root
IK_IN  = ROOT / "01_Input_Files" / "subject01_walk1_ik.mot"
IK_OUT = ROOT / "03_projectGait2392_weakness" / "subject01_walk1_ik_weak20.mot"

# ============================================================
# GAUSSIAN OFFSET PARAMETERS — Weak20
# ============================================================
AMPLITUDE  = -5.0   # degrees — negative = more flexion (knee buckling)
T_CENTER   = 0.90   # seconds — peak of stance phase
SIGMA      = 0.20   # seconds — width of Gaussian
T_START    = 0.60   # seconds — start of stance phase offset
T_END      = 1.20   # seconds — end of stance phase offset

print("=" * 60)
print("FesRobex — New IK Generation: Weak20 (-5 deg)")
print("=" * 60)
print(f"Input:  {IK_IN}")
print(f"Output: {IK_OUT}")
print(f"Offset: {AMPLITUDE} deg (Gaussian, t={T_START}-{T_END}s)")
print()

# ============================================================
# READ ORIGINAL IK FILE
# ============================================================
with open(IK_IN, 'r') as f:
    lines = f.readlines()

# Find header end (endheader line)
header_end_idx = 0
for i, line in enumerate(lines):
    if 'endheader' in line.lower():
        header_end_idx = i
        break

header_lines = lines[:header_end_idx + 1]
data_lines   = lines[header_end_idx + 1:]

print(f"Header lines: {len(header_lines)}")
print(f"Data lines:   {len(data_lines)}")

# ============================================================
# PARSE COLUMN NAMES
# ============================================================
col_line = data_lines[0].strip()
columns  = col_line.split('\t')
print(f"Columns found: {len(columns)}")

# Find knee_angle_r column index
knee_col = None
for j, col in enumerate(columns):
    if col.strip() == 'knee_angle_r':
        knee_col = j
        print(f"knee_angle_r found at column index: {knee_col}")
        break

if knee_col is None:
    raise ValueError("ERROR: knee_angle_r column not found!")

# Find time column (always index 0)
time_col = 0

# ============================================================
# PROCESS DATA — Apply Gaussian offset
# ============================================================
output_data_lines = [data_lines[0]]  # keep header row

modified_count = 0
total_count    = 0

for line in data_lines[1:]:
    if line.strip() == '':
        output_data_lines.append(line)
        continue

    values = line.strip().split('\t')
    if len(values) < knee_col + 1:
        output_data_lines.append(line)
        continue

    total_count += 1

    try:
        t            = float(values[time_col])
        knee_angle   = float(values[knee_col])
    except ValueError:
        output_data_lines.append(line)
        continue

    # Apply Gaussian offset ONLY during stance phase
    if T_START <= t <= T_END:
        offset = AMPLITUDE * np.exp(-((t - T_CENTER)**2) / (2 * SIGMA**2))
        values[knee_col] = f"{knee_angle + offset:.6f}"
        modified_count += 1

    output_data_lines.append('\t'.join(values) + '\n')

print(f"Total frames:    {total_count}")
print(f"Modified frames: {modified_count} (stance phase)")
print(f"Unchanged frames:{total_count - modified_count} (swing phase)")

# ============================================================
# VERIFY OFFSET AT KEY TIMEPOINTS
# ============================================================
print()
print("Offset verification:")
for t_check in [0.65, 0.75, 0.90, 1.05, 1.20, 1.50]:
    if T_START <= t_check <= T_END:
        offset = AMPLITUDE * np.exp(-((t_check - T_CENTER)**2) / (2 * SIGMA**2))
        print(f"  t={t_check:.2f}s: offset = {offset:+.3f} deg")
    else:
        print(f"  t={t_check:.2f}s: offset =  0.000 deg (swing)")

# ============================================================
# WRITE OUTPUT FILE
# ============================================================
with open(IK_OUT, 'w') as f:
    f.writelines(header_lines)
    f.writelines(output_data_lines)

print()
print(f"✅ New IK file saved: {IK_OUT}")
print()
print("Next steps:")
print("  1. Run CMC with this file as desired_kinematics")
print("     Setup: Setup_CMC_weak20_newik.xml")
print("     Results: Results_CMC_weak20_newik/")
print("  2. Run Forward Dynamics")
print("     Results: Results_Forward_weak20_newik/")
