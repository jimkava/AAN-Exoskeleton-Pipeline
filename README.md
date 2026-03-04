# Simulation-Based Actuator Selection via Cloud Digital Twin for Assist-as-Needed Exoskeletons 🦿☁️

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2023a-blue.svg)](https://mathworks.com/)
[![OpenSim](https://img.shields.io/badge/OpenSim-Moco-orange.svg)](https://simtk.org/projects/moco)

This repository contains the code, musculoskeletal models, and cloud integration scripts developed for our IEEE paper methodology. It provides an advanced computational framework for gait restoration, replacing static evaluations with a dynamic **Cloud-Based Digital Twin**.

## 🚀 System Architecture

The automated pipeline executes the following sequence for each pathology severity level (10%–80% quadriceps weakness):
1. **Adaptive Supervisor & OpenSim Moco:** Simulates progressive atrophy and computes the dynamic Assist-as-Needed (AAN) compensatory torque.
2. **MATLAB Digital Twin:** Parses time-series data to perform Mechanical Reduction (50:1 gearbox) and Thermal Analysis.
3. **Automated Motor Selection:** Queries a BLDC database to select the optimal actuator (e.g., Maxon EC 45, 60 series) ensuring strict safety margins.
4. **Cloud Integration:** Pushes results to a PostgreSQL database (Supabase) and visualizes them in a real-time dashboard.

## 📊 Live Cloud Dashboard
You can view the real-time IoT dashboard and the motor selection database at our official project website:
[**FesRobEx Database**](https://fesrobex.info/fesrobexdatabase/)

## 📝 Citation
If you use this code or methodology in your research, please cite our corresponding IEEE paper:
*(Citation details will be added upon publication)*
