"""
FesRobex - Weak30 model generation
Reduces max isometric force of the right vastii (vas_med_r, vas_int_r,
vas_lat_r) by 30% relative to the RRA-adjusted subject01 model.

Input : 01_Input_Files/subject01_simbody_adjusted.osim
Output: 03_projectGait2392_weakness/subject01_simbody_weak30.osim
"""
from pathlib import Path
import opensim as osim

ROOT      = Path(__file__).resolve().parents[1]   # repo root
MODEL_IN  = ROOT / "01_Input_Files" / "subject01_simbody_adjusted.osim"
MODEL_OUT = ROOT / "03_projectGait2392_weakness" / "subject01_simbody_weak30.osim"

FACTOR = 0.7

model = osim.Model(str(MODEL_IN))
model.initSystem()

muscles = ["vas_med_r", "vas_int_r", "vas_lat_r"]
for name in muscles:
    m = model.getMuscles().get(name)
    original = m.getMaxIsometricForce()
    m.setMaxIsometricForce(original * FACTOR)
    print(f"{name}: {original:.1f} -> {original*FACTOR:.1f} N (-30%)")

model.printToXML(str(MODEL_OUT))
print(f"\nWeak30 model saved: {MODEL_OUT}")
