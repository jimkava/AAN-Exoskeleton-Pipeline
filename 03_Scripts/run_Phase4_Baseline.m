% ----------------------------------------------------------------------- %
%   PROJECT: DropFoot_GaitRehab_FESRobex
%   PHASE 4: Adult Normal Baseline (Demand Analysis)
%   SCRIPT:  run_Phase4_Baseline.m
% ----------------------------------------------------------------------- %

clear; clc; close all;
import org.opensim.modeling.*;

%% 1. ΟΡΙΣΜΟΣ PATHS
ROOT = 'C:\OpenSim 4.5\sdk\Models\DropFoot_GaitRehab_FESRobex\Gaithab_FesRobex_project_22.12.25\MATLAB\Open-Loop Model\Moco_Phase4_Adult_Normal';

inputsDir  = fullfile(ROOT, '01_Inputs');
modelDir   = fullfile(ROOT, '02_Model_Base');
resultsDir = fullfile(ROOT, '04_Results', 'Baseline_0_Weakness');

if ~exist(resultsDir, 'dir'), mkdir(resultsDir); end

% Αρχεία
modelFile = fullfile(modelDir, 'subject01_NORMAL.osim');
ikFile    = fullfile(inputsDir, 'subject01_walk1_ik.mot');
grfMot    = fullfile(inputsDir, 'subject01_walk1_grf.mot');
grfXml    = fullfile(inputsDir, 'subject01_walk1_grf.xml');

if ~exist(modelFile, 'file'), error('Missing Model'); end
if ~exist(ikFile, 'file'), error('Missing IK'); end
if ~exist(grfXml, 'file'), error('Missing GRF XML'); end

%% 2. MODEL PROCESSOR
baseModel = Model(modelFile);
baseModel.initSystem();

% Εξωσκελετός
exo = CoordinateActuator();
exo.setName('knee_exo_device');
exo.setCoordinate(baseModel.getCoordinateSet().get('knee_angle_r'));
exo.setOptimalForce(100); 
exo.setMinControl(-2.0);   
exo.setMaxControl(2.0);    
baseModel.addForce(exo);

% GRF Fix
extLoads = ExternalLoads(grfXml, true);
extLoads.setDataFileName(grfMot); 
tempGrfXml = fullfile(resultsDir, 'GRF_Setup_Fixed.xml');
extLoads.print(tempGrfXml);

% Processor
modelProc = ModelProcessor(baseModel);
modelProc.append(ModOpAddExternalLoads(tempGrfXml));
modelProc.append(ModOpIgnoreTendonCompliance());
modelProc.append(ModOpReplaceMusclesWithDeGrooteFregly2016());
modelProc.append(ModOpIgnorePassiveFiberForcesDGF());
modelProc.append(ModOpAddReserves(100));

%% 3. SETUP MOCO INVERSE
inverse = MocoInverse();
inverse.setModel(modelProc);
inverse.setKinematics(TableProcessor(ikFile));
inverse.set_initial_time(0.4);
inverse.set_final_time(1.75);
inverse.set_mesh_interval(0.02);
inverse.set_convergence_tolerance(1e-3);
inverse.set_constraint_tolerance(1e-3);

%% 4. ΕΥΡΕΣΗ GOAL & ΕΦΑΡΜΟΓΗ ΒΑΡΩΝ (ΔΙΟΡΘΩΜΕΝΟ)
study = inverse.initialize();
problem = study.updProblem();

% --- ΜΕΘΟΔΟΣ TEXT PARSING (Αφού δούλεψε!) ---
debugFile = fullfile(resultsDir, 'Debug_Problem.omoco');
study.print(debugFile);
txt = fileread(debugFile);
tokens = regexp(txt, 'MocoControlGoal name="([^"]+)"', 'tokens');

if isempty(tokens)
    warning('Δεν βρέθηκε όνομα. Δοκιμή default "excitation_effort"...');
    goalName = 'excitation_effort';
else
    goalName = tokens{1}{1};
end

fprintf('ΕΝΤΟΠΙΣΤΗΚΕ ΤΟ GOAL: "%s"\n', goalName);

% Ανάκτηση του Goal
goal = MocoControlGoal.safeDownCast(problem.updGoal(goalName));

% --- ΝΕΟΣ ΤΡΟΠΟΣ ΟΡΙΣΜΟΥ ΒΑΡΩΝ (Iterative) ---
% Επειδή το setDefaultWeight δεν υπάρχει, θα ορίσουμε τα βάρη ένα-ένα.
fprintf('Ορισμός βαρών για κάθε Actuator...\n');

% Παίρνουμε όλα τα Forces από το baseModel (που περιέχει και τον Exo)
forceSet = baseModel.getForceSet();
for i = 0:forceSet.getSize()-1
    force = forceSet.get(i);
    forceName = char(force.getName());
    
    % Φτιάχνουμε το path, π.χ. /forceset/vastus_medialis_r
    forcePath = ['/forceset/' forceName];
    
    if contains(forceName, 'knee_exo_device')
        % ΕΞΩΣΚΕΛΕΤΟΣ: ΠΟΛΥ ΑΚΡΙΒΟΣ (1000.0)
        goal.setWeightForControl(forcePath, 1000.0);
        fprintf(' -> Exo Weight set to 1000: %s\n', forceName);
    else
        % ΜΥΕΣ & RESERVES: ΦΘΗΝΟΙ (0.001)
        goal.setWeightForControl(forcePath, 0.001);
    end
end
fprintf('Η διαδικασία ορισμού βαρών ολοκληρώθηκε.\n');

%% 5. ΕΠΙΛΥΣΗ
fprintf('Εκτέλεση MocoInverse (Adult Normal Baseline)...\n');

solver = study.updSolver();
solution = study.solve();

outputFile = fullfile(resultsDir, 'Baseline_Result.sto');
solution.write(outputFile);
fprintf('Αποτελέσματα: %s\n', outputFile);

study.visualize(solution);