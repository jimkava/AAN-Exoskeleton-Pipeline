% ----------------------------------------------------------------------- %
%   PROJECT: DropFoot_GaitRehab_FESRobex
%   PHASE 4: Adult Normal - WEAKNESS LOOP (10% - 80%)
%   SCRIPT:  run_Phase4_Loop.m
% ----------------------------------------------------------------------- %

clear; clc; close all;
import org.opensim.modeling.*;

%% 1. ΡΥΘΜΙΣΕΙΣ PATHS
ROOT = 'C:\OpenSim 4.5\sdk\Models\DropFoot_GaitRehab_FESRobex\Gaithab_FesRobex_project_22.12.25\MATLAB\Open-Loop Model\Moco_Phase4_Adult_Normal';

inputsDir  = fullfile(ROOT, '01_Inputs');
modelDir   = fullfile(ROOT, '02_Model_Base');
resultsDir = fullfile(ROOT, '04_Results'); 

modelFile = fullfile(modelDir, 'subject01_NORMAL.osim');
ikFile    = fullfile(inputsDir, 'subject01_walk1_ik.mot');
grfMot    = fullfile(inputsDir, 'subject01_walk1_grf.mot');
grfXml    = fullfile(inputsDir, 'subject01_walk1_grf.xml');

% ΠΟΣΟΣΤΑ ΑΔΥΝΑΜΙΑΣ (Από 10% έως 80%)
weaknessLevels = 0.10 : 0.10 : 0.80; 

%% 2. ΕΝΑΡΞΗ LOOP
for i = 1:length(weaknessLevels)
    
    wkPct = weaknessLevels(i);         
    strength = 1.0 - wkPct;            
    strWeakness = sprintf('%d', round(wkPct * 100)); % "10", "20"...
    
    % Δημιουργία υπο-φακέλου
    runDir = fullfile(resultsDir, ['Weakness_' strWeakness]);
    if ~exist(runDir, 'dir'), mkdir(runDir); end
    
    fprintf('\n===================================================\n');
    fprintf('STARTING SIMULATION: %s%% WEAKNESS (Strength: %.2f)\n', strWeakness, strength);
    fprintf('===================================================\n');

    %% 3. ΠΡΟΕΤΟΙΜΑΣΙΑ ΜΟΝΤΕΛΟΥ (With Weakness)
    baseModel = Model(modelFile);
    baseModel.initSystem();
    
    % --- ΕΦΑΡΜΟΓΗ ΑΔΥΝΑΜΙΑΣ (VASTUS ONLY) ---
    muscles = baseModel.updMuscles();
    for m = 0:muscles.getSize()-1
        musc = muscles.get(m);
        mName = char(musc.getName());
        
        % Μειώνουμε τη δύναμη στους Vastus
        if contains(mName, 'vastus')
            oldFmax = musc.getMaxIsometricForce();
            newFmax = oldFmax * strength;
            musc.setMaxIsometricForce(newFmax);
        end
    end
    
    % Προσθήκη Εξωσκελετού
    exo = CoordinateActuator();
    exo.setName('knee_exo_device');
    exo.setCoordinate(baseModel.getCoordinateSet().get('knee_angle_r'));
    exo.setOptimalForce(100); 
    exo.setMinControl(-2.0); exo.setMaxControl(2.0);    
    baseModel.addForce(exo);
    
    % GRF Setup
    extLoads = ExternalLoads(grfXml, true);
    extLoads.setDataFileName(grfMot);
    tempGrfXml = fullfile(runDir, 'GRF_Setup.xml');
    extLoads.print(tempGrfXml);
    
    % Model Processor
    modelProc = ModelProcessor(baseModel);
    modelProc.append(ModOpAddExternalLoads(tempGrfXml));
    modelProc.append(ModOpIgnoreTendonCompliance());
    modelProc.append(ModOpReplaceMusclesWithDeGrooteFregly2016());
    modelProc.append(ModOpIgnorePassiveFiberForcesDGF());
    modelProc.append(ModOpAddReserves(100));
    
    %% 4. MOCO INVERSE SETUP
    inverse = MocoInverse();
    inverse.setModel(modelProc);
    inverse.setKinematics(TableProcessor(ikFile));
    inverse.set_initial_time(0.4);
    inverse.set_final_time(1.75);
    inverse.set_mesh_interval(0.02);
    inverse.set_convergence_tolerance(1e-3);
    inverse.set_constraint_tolerance(1e-3);
    
    %% 5. GOAL & WEIGHTS (Η μέθοδος που δούλεψε)
    study = inverse.initialize();
    problem = study.updProblem();
    
    % Εύρεση ονόματος Goal από το αρχείο (Safe Method)
    debugFile = fullfile(runDir, 'Debug_Goal.omoco');
    study.print(debugFile);
    txt = fileread(debugFile);
    tokens = regexp(txt, 'MocoControlGoal name="([^"]+)"', 'tokens');
    if isempty(tokens), goalName='excitation_effort'; else, goalName=tokens{1}{1}; end
    
    goal = MocoControlGoal.safeDownCast(problem.updGoal(goalName));
    
    % Ρύθμιση Βαρών: Assist-as-Needed
    forceSet = baseModel.getForceSet();
    for f = 0:forceSet.getSize()-1
        fname = char(forceSet.get(f).getName());
        path = ['/forceset/' fname];
        
        if contains(fname, 'knee_exo_device')
            % Ο Εξωσκελετός ΠΑΡΑΜΕΝΕΙ ΑΚΡΙΒΟΣ (1000).
            % Θα ενεργοποιηθεί ΜΟΝΟ αν οι μύες (που τους κόψαμε δύναμη) δεν αντέχουν.
            goal.setWeightForControl(path, 1000.0);
        else
            goal.setWeightForControl(path, 0.001);
        end
    end
    
    %% 6. SOLVE & SAVE
    fprintf('   -> Solving...\n');
    solver = study.updSolver();
    solution = study.solve();
    
    outFile = fullfile(runDir, ['Result_Weakness_' strWeakness '.sto']);
    solution.write(outFile);
    fprintf('   -> SAVED: %s\n', outFile);
    
    % Έχουμε κλείσει το Visualize για να μην κρασάρει
    close all; 
end

fprintf('\nALL SIMULATIONS FINISHED!\n');