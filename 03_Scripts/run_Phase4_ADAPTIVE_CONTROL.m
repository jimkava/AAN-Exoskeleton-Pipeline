% ----------------------------------------------------------------------- %
%   PROJECT: DropFoot_GaitRehab_FESRobex
%   SCRIPT:  run_Phase4_ADAPTIVE_CONTROL.m
%   ΣΤΟΧΟΣ:  ΕΓΓΥΗΜΕΝΗ ΚΑΜΠΥΛΗ ASSIST-AS-NEEDED
%            (Adaptive Weight Strategy: High cost at low weakness, Low cost at high weakness)
% ----------------------------------------------------------------------- %

clear; clc; close all;
import org.opensim.modeling.*;

%% 1. ΡΥΘΜΙΣΕΙΣ
ROOT = 'C:\OpenSim 4.5\sdk\Models\DropFoot_GaitRehab_FESRobex\Gaithab_FesRobex_project_22.12.25\MATLAB\Open-Loop Model\Moco_Phase4_Adult_Normal';
inputsDir  = fullfile(ROOT, '01_Inputs');
modelDir   = fullfile(ROOT, '02_Model_Base');
resultsDir = fullfile(ROOT, '04_Results', 'Adaptive_Curve_Final'); 

if ~exist(resultsDir, 'dir'), mkdir(resultsDir); end

modelFile = fullfile(modelDir, 'subject01_NORMAL.osim');
ikFile    = fullfile(inputsDir, 'subject01_walk1_ik.mot');
grfMot    = fullfile(inputsDir, 'subject01_walk1_grf.mot');
grfXml    = fullfile(inputsDir, 'subject01_walk1_grf.xml');

% Τρέχουμε όλο το φάσμα
weaknessLevels = 0.10 : 0.10 : 0.80; 

%% 2. MODEL
origModel = Model(modelFile);
origModel.initSystem();
DeGrooteFregly2016Muscle.replaceMuscles(origModel);
origModel.initSystem();
dgfModelFile = fullfile(resultsDir, 'Base_DGF.osim');
origModel.print(dgfModelFile);

resultsSummary = zeros(length(weaknessLevels), 2); 

%% 3. MAIN LOOP
for i = 1:length(weaknessLevels)
    
    wkPct = weaknessLevels(i);         
    strength = 1.0 - wkPct;            
    strWeakness = sprintf('%d', round(wkPct * 100));
    
    runDir = fullfile(resultsDir, ['Weakness_' strWeakness]);
    if ~exist(runDir, 'dir'), mkdir(runDir); end
    
    % --- ADAPTIVE WEIGHT CALCULATION ---
    % Στο 10% -> Weight = 100.000 (Πολύ Ακριβό -> 0 Nm)
    % Στο 80% -> Weight = 10 (Πολύ Φθηνό -> Max Nm)
    % Logarithmic interpolation για ομαλή καμπύλη
    exoWeight = 10^(5 - (wkPct - 0.1)/(0.7) * 4); 
    
    % Αν θες πιο απλό (Linear):
    % exoWeight = 100000 - (wkPct-0.1)*(100000-100)/0.7; 
    
    fprintf('\n=== ADAPTIVE SIM: %s%% WEAKNESS (Exo Weight: %.1f) ===\n', strWeakness, exoWeight);

    baseModel = Model(dgfModelFile); 
    baseModel.initSystem();
    
    % Weakness (FULL QUAD)
    muscles = baseModel.updMuscles();
    for m = 0:muscles.getSize()-1
        musc = muscles.get(m);
        mName = char(musc.getName());
        if (contains(mName, 'vas_med_r') || contains(mName, 'vas_int_r') || ...
            contains(mName, 'vas_lat_r') || contains(mName, 'rec_fem_r'))
            oldFmax = musc.getMaxIsometricForce();
            musc.setMaxIsometricForce(oldFmax * strength);
        end
    end
    
    % Exo
    exo = CoordinateActuator();
    exo.setName('knee_exo_device');
    exo.setCoordinate(baseModel.getCoordinateSet().get('knee_angle_r'));
    exo.setOptimalForce(100); 
    exo.setMinControl(-2.0); exo.setMaxControl(2.0);    
    baseModel.addForce(exo);
    
    % Loads
    extLoads = ExternalLoads(grfXml, true);
    extLoads.setDataFileName(grfMot);
    tempGrfXml = fullfile(runDir, 'GRF.xml');
    extLoads.print(tempGrfXml);
    
    modelProc = ModelProcessor(baseModel);
    modelProc.append(ModOpAddExternalLoads(tempGrfXml));
    modelProc.append(ModOpIgnoreTendonCompliance());
    modelProc.append(ModOpIgnorePassiveFiberForcesDGF());
    modelProc.append(ModOpAddReserves(100));
    
    % Moco
    inverse = MocoInverse();
    inverse.setModel(modelProc);
    inverse.setKinematics(TableProcessor(ikFile));
    inverse.set_initial_time(0.4);
    inverse.set_final_time(1.75);
    inverse.set_mesh_interval(0.05);          
    inverse.set_convergence_tolerance(1e-2);
    inverse.set_constraint_tolerance(1e-2);
    
    % --- WEIGHTS ---
    study = inverse.initialize();
    problem = study.updProblem();
    
    debugFile = fullfile(runDir, 'Debug.omoco');
    study.print(debugFile);
    txt = fileread(debugFile);
    tokens = regexp(txt, 'MocoControlGoal name="([^"]+)"', 'tokens');
    if isempty(tokens), goalName='excitation_effort'; else, goalName=tokens{1}{1}; end
    goal = MocoControlGoal.safeDownCast(problem.updGoal(goalName));
    
    forceSet = baseModel.getForceSet();
    for f = 0:forceSet.getSize()-1
        fname = char(forceSet.get(f).getName());
        path = ['/forceset/' fname];
        
        if contains(fname, 'knee_exo_device')
            % ΤΟ ΠΡΟΣΑΡΜΟΣΤΙΚΟ ΒΑΡΟΣ
            goal.setWeightForControl(path, exoWeight);    
            
        elseif contains(fname, 'reserve')
            goal.setWeightForControl(path, 1000000.0);  
            
        elseif contains(fname, '_r') 
            if contains(fname, 'vas_') || contains(fname, 'rec_fem')
                % Quads: Cheap
                goal.setWeightForControl(path, 0.0001); 
            elseif contains(fname, 'glute') || contains(fname, 'gas') || contains(fname, 'sol')
                % Compensators: Expensive (αλλά όχι forbidden, για να λύνει)
                goal.setWeightForControl(path, 10000.0); 
            else
                goal.setWeightForControl(path, 1.0);
            end
        else
            goal.setWeightForControl(path, 0.001);
        end
    end
    
    fprintf('   -> Solving...\n');
    solver = study.updSolver();
    solution = study.solve();
    
    outFile = fullfile(runDir, 'Result.sto');
    solution.write(outFile);
    
    data = TimeSeriesTable(outFile);
    labels = data.getColumnLabels();
    exoCol = '';
    for k=0:labels.size()-1
        if contains(char(labels.get(k)), 'knee_exo_device'), exoCol=char(labels.get(k)); break; end
    end
    
    currentMaxTorque = 0;
    if ~isempty(exoCol)
        vals = data.getDependentColumn(exoCol).getAsMat();
        currentMaxTorque = max(abs(vals)) * 100;
    end
    
    fprintf('   -> ✅ Result (%s%%): %.2f Nm\n', strWeakness, currentMaxTorque);
    resultsSummary(i, :) = [wkPct * 100, currentMaxTorque];
    
    close all; 
end

%% PLOT
figure('Name', 'Adaptive Assist-as-Needed', 'Color', 'w');
plot([0; resultsSummary(:,1)], [0; resultsSummary(:,2)], '-o', 'LineWidth', 3, 'Color', 'r');
grid on; xlabel('Weakness %'); ylabel('Exo Torque (Nm)');
title('Assist-as-Needed (Adaptive Control)');

save(fullfile(resultsDir, 'AdaptiveData.mat'), 'resultsSummary');