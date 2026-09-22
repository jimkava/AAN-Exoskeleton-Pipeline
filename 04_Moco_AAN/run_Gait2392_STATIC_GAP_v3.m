% ======================================================================= %
%   PROJECT: FesRobex - Gait2392 Simbody Pipeline
%   SCRIPT:  run_Gait2392_STATIC_GAP_v3.m
%   FOLDER:  04_Moco_AAN\
%
%   METHOD:  GAP STRATEGY - w_exo = 2000 STATHERO se ola ta epipeda.
%            Xexoristi methodos apo to Adaptive AAN (w_exo(beta)).
%
%   ================= ISTORIKO =================
%   v1 : reserve weights DEN efarmozontan (loop pano sto baseModel anti
%        gia to processed model) -> ta reserves eixan default varos 1.0.
%   v2 : diorthose to bug, alla me w_c = 1e6 to problima egine poly
%        kako-orismeno (10 taxeis megethous eyros varon). ~16 s/iter,
%        >600 iters xoris sygklisi. Mi praktiko.
%   v3 : idio diorthomeno weight assignment + rithmiseis taxititas.
%
%   ================= TI ALLAZEI STO v3 =================
%
%   ASFALEIS (den allazoun ti lysi, mono ton ypologismo):
%     - parallel = 0            -> xrisi olon ton pyrinon
%     - finite difference       -> 'forward' anti 'central' (~2x)
%     - warm start              -> guess apo to proigoumeno senario
%
%   EPIDROUN STI LYSI (prepei na anaferthoun sto paper):
%     - mesh_interval 0.02 -> 0.035
%     - w_c           1e6  -> 1e4
%
%   SIMEIOSI gia to w_c: to 1e6 DEN eixe pote efarmostei stin praxi
%   (v1 bug), ara den einai kathieromeni timi pou xanetai. To 1e4
%   diatirei pliros tin ierarxia w_c >> w_exo >> w_m:
%       w_c / w_exo = 5      (ta reserves paramenoun 5x akrivotera)
%       w_exo / w_m = 2e7    (o fragmos diafaneias amerastos)
%
%   ================= KNEE RESERVE =================
%   To knee_angle_r DEN pairnei reserve: o knee_exo_device prostithetai
%   PRIN ton ModelProcessor, opote to ModOpAddReserves to parakampei.
%   Elegxetai RITA me assert.
%
%   AUTHOR:  Dimitrios Kavalieros, EE & IT MSc. & MEd.
%   DATE:    August 2026
%   MODEL:   Gait2392 Simbody (subject01)
% ======================================================================= %

clear; clc; close all;
import org.opensim.modeling.*;

%% ===== 0. CONFIG =====
EXO_WEIGHT_STATIC = 2000;      % w_exo - STATHERO se ola ta epipeda
W_RESERVE         = 1e4;       % w_c
W_MUSCLE          = 1e-4;      % w_m - OLOI oi myes (Eq. 6)

MESH_INTERVAL     = 0.035;
SOLVER_TOL        = 1e-1;
MAX_ITER          = 1000;
FD_SCHEME         = 'forward';
USE_PARALLEL      = 0;
USE_WARM_START    = false;     % apetyxe se v3 - asymvata states

RUN_TAG = sprintf('paper_wc%.0e_mesh%g_it%d', W_RESERVE, MESH_INTERVAL, MAX_ITER);
fprintf('\n>>> RUN_TAG = %s | 3-class weights (Eq. 6)\n', RUN_TAG);

%% ===== 1. PATHS =====
ROOT         = fileparts(fileparts(mfilename('fullpath')));   % repo root (parent of 04_Moco_AAN)
DIR_INPUTS   = fullfile(ROOT, '01_Input_Files');
DIR_WEAKNESS = fullfile(ROOT, '03_projectGait2392_weakness');
DIR_STATIC   = fullfile(ROOT, '04_Moco_AAN', 'Results_v3_Static');
DIR_PLOTS    = fullfile(DIR_STATIC, 'Plots');

if ~exist(DIR_STATIC,'dir'), mkdir(DIR_STATIC); end
if ~exist(DIR_PLOTS, 'dir'), mkdir(DIR_PLOTS);  end

ikFile = fullfile(DIR_INPUTS, 'subject01_walk1_ik.mot');
grfMot = fullfile(DIR_INPUTS, 'subject01_walk1_grf.mot');
grfXml = fullfile(DIR_INPUTS, 'subject01_walk1_grf.xml');

weakModels(1).pct = 20; weakModels(1).beta = 0.20;
weakModels(1).osim = fullfile(DIR_WEAKNESS,'subject01_simbody_weak20.osim');
weakModels(2).pct = 30; weakModels(2).beta = 0.30;
weakModels(2).osim = fullfile(DIR_WEAKNESS,'subject01_simbody_weak30.osim');
weakModels(3).pct = 50; weakModels(3).beta = 0.50;
weakModels(3).osim = fullfile(DIR_WEAKNESS,'subject01_simbody_weak50.osim');

resultsDir = fullfile(DIR_STATIC, ['Results_' RUN_TAG]);
if ~exist(resultsDir,'dir'), mkdir(resultsDir); end

%% ===== 2. HEADER =====
fprintf('================================================================================\n');
fprintf('   FesRobex | GAP STRATEGY v3 (fast) | w_exo = %d STATIC\n', EXO_WEIGHT_STATIC);
fprintf('   w_c = %.0e | mesh = %g | max_iter = %d | FD = %s | parallel = %d\n', ...
        W_RESERVE, MESH_INTERVAL, MAX_ITER, FD_SCHEME, USE_PARALLEL);
fprintf('================================================================================\n\n');

for f = {ikFile, grfMot, grfXml}
    assert(exist(f{1},'file')>0, 'MISSING: %s', f{1});
end
for k = 1:numel(weakModels)
    assert(exist(weakModels(k).osim,'file')>0, 'MISSING model: %s', weakModels(k).osim);
end
fprintf('All input files located.\n\n');

%% ===== 3. INIT =====
nLevels        = numel(weakModels);
resultsSummary = zeros(nLevels,5);   % [pct, peak, rms, elapsed_s, converged]
statusList     = cell(nLevels,1);
prevSolution   = [];

%% ===== 4. MAIN LOOP =====
for i = 1:nLevels

    wkPct = weakModels(i).pct;
    beta  = weakModels(i).beta;
    strWk = sprintf('%d', wkPct);
    runDir = fullfile(resultsDir, ['Weakness_' strWk]);
    if ~exist(runDir,'dir'), mkdir(runDir); end

    fprintf('--------------------------------------------------------------------------------\n');
    fprintf('   SCENARIO %d/%d: WEAKNESS %d%%  |  beta = %.2f  |  w_exo = %d (static)\n', ...
            i, nLevels, wkPct, beta, EXO_WEIGHT_STATIC);
    fprintf('--------------------------------------------------------------------------------\n');
    tStart = tic;

    % --- MODEL ---
    baseModel = Model(weakModels(i).osim);
    baseModel.initSystem();
    DeGrooteFregly2016Muscle.replaceMuscles(baseModel);
    baseModel.initSystem();

    % --- EXO (PRIN ton ModelProcessor -> to knee reserve parakamptetai) ---
    exo = CoordinateActuator();
    exo.setName('knee_exo_device');
    exo.setCoordinate(baseModel.getCoordinateSet().get('knee_angle_r'));
    exo.setOptimalForce(100);
    exo.setMinControl(-2.0);
    exo.setMaxControl(2.0);
    baseModel.addForce(exo);

    % --- GRF ---
    extLoads = ExternalLoads(grfXml,true);
    extLoads.setDataFileName(grfMot);
    tempGrfXml = fullfile(runDir,'GRF.xml');
    extLoads.print(tempGrfXml);

    % --- MODEL PROCESSOR ---
    modelProc = ModelProcessor(baseModel);
    modelProc.append(ModOpAddExternalLoads(tempGrfXml));
    modelProc.append(ModOpIgnoreTendonCompliance());
    modelProc.append(ModOpIgnorePassiveFiberForcesDGF());
    modelProc.append(ModOpAddReserves(100));

    % >>> to processed montelo PERIEXEI ta reserves (to baseModel OXI) <<<
    procModel = modelProc.process();
    procModel.initSystem();

    % --- MOCO INVERSE ---
    inverse = MocoInverse();
    inverse.setModel(modelProc);
    inverse.setKinematics(TableProcessor(ikFile));
    inverse.set_initial_time(0.53);
    inverse.set_final_time(1.99);
    inverse.set_mesh_interval(MESH_INTERVAL);
    inverse.set_convergence_tolerance(SOLVER_TOL);
    inverse.set_constraint_tolerance(SOLVER_TOL);

    study   = inverse.initialize();
    problem = study.updProblem();

   % ================= SPEED SETTINGS =================
    solver = MocoCasADiSolver.safeDownCast(study.updSolver());
    solver.set_parallel(USE_PARALLEL);
    solver.set_optim_finite_difference_scheme(FD_SCHEME);
    solver.set_optim_max_iterations(MAX_ITER);
    solver.set_optim_hessian_approximation('limited-memory');

    if USE_WARM_START && ~isempty(prevSolution)
        try
            solver.setGuess(prevSolution);
            fprintf('   Warm start: guess from previous scenario\n');
        catch ME
            fprintf('   Warm start skipped (%s)\n', ME.message);
        end
    end

    % --- GOAL ---
    debugFile = fullfile(runDir,'Debug.omoco');
    study.print(debugFile);
    tok = regexp(fileread(debugFile),'MocoControlGoal name="([^"]+)"','tokens');
    if isempty(tok), goalName = 'excitation_effort'; else, goalName = tok{1}{1}; end
    goal = MocoControlGoal.safeDownCast(problem.updGoal(goalName));

    % ================= WEIGHTS (processed forceset) =================
    fs = procModel.getForceSet();
    nExo = 0; nReserve = 0; nTarget = 0; nOther = 0;
    kneeReserveFound = false;

    for f = 0:fs.getSize()-1
        force = fs.get(f);
        fname = char(force.getName());
        fpath = ['/forceset/' fname];

        if contains(fname,'knee_exo_device')
            goal.setWeightForControl(fpath, EXO_WEIGHT_STATIC);
            nExo = nExo + 1;

        elseif contains(lower(fname),'reserve')
            goal.setWeightForControl(fpath, W_RESERVE);
            nReserve = nReserve + 1;
            if contains(fname,'knee_angle_r'), kneeReserveFound = true; end

        else
            % OLOI oi myes -> w_m (typ-based, oxi onomatologia)
            mus = Muscle.safeDownCast(force);
            if ~isempty(mus)
                goal.setWeightForControl(fpath, W_MUSCLE);
                nTarget = nTarget + 1;
            else
                nOther = nOther + 1;
            end
        end
    end

    fprintf('   Weights on PROCESSED model: exo=%d | reserves=%d | target=%d | other=%d\n', ...
            nExo, nReserve, nTarget, nOther);

    assert(nExo == 1, 'Expected 1 exo actuator, found %d.', nExo);
    assert(nReserve > 0, 'NO RESERVES FOUND -> w_c not applied. Check Debug.omoco.');
    assert(~kneeReserveFound, 'Reserve found at knee_angle_r - should be skipped.');

    % --- SOLVE ---
    fprintf('   Solving...\n');
    solution = study.solve();
    elapsed  = toc(tStart);

    isOk = solution.success();
    if isOk
        statusList{i} = 'CONVERGED';
    else
        statusList{i} = 'NOT CONVERGED';
        solution.unseal();      % <<< aparaitito gia na grafei to .sto
        warning('Weak%d: solver did NOT converge (max_iter). Apotelesma me epifylaxi.', wkPct);
    end

    stoFile = fullfile(runDir, ['Result_Static_Weak' strWk '.sto']);
    solution.write(stoFile);
    prevSolution = solution;

    % --- TORQUE ---
    d   = importdata(stoFile);
    idx = find(contains(d.colheaders,'knee_exo_device'));
    tq  = d.data(:,idx) * 100.0;          % OptimalForce = 100
    t   = d.data(:,1);

    dm    = importdata(ikFile);
    ia    = find(contains(dm.colheaders,'knee_angle_r'));
    ang   = interp1(dm.data(:,1), dm.data(:,ia), t, 'linear','extrap');
    spd   = gradient(deg2rad(ang), mean(diff(t))) * (60/(2*pi));

    peakNm = max(abs(tq));
    rmsNm  = rms(tq);

    fprintf('   >>> Peak: %.4f Nm | RMS: %.4f Nm | Speed: %.1f RPM\n', ...
            peakNm, rmsNm, max(abs(spd)));
    fprintf('   >>> Status: %s | Time: %.1f min\n\n', statusList{i}, elapsed/60);

    resultsSummary(i,:) = [wkPct, peakNm, rmsNm, elapsed, double(isOk)];

    figure('Color','w','Visible','off');
    plot(t, tq, 'b-','LineWidth',1.6); grid on;
    xlabel('Time (s)'); ylabel('Exo Torque (Nm)');
    title(sprintf('Gap v3 | Weak%d%% | Peak = %.2f Nm | RMS = %.2f Nm', ...
                  wkPct, peakNm, rmsNm));
    saveas(gcf, fullfile(DIR_PLOTS, sprintf('GapV3_%s_Weak%d.pdf', RUN_TAG, wkPct)));
    close all;
end

%% ===== 5. RESULTS =====
fprintf('================================================================================\n');
fprintf('   GAP STRATEGY v3 - Table V, Static column\n');
fprintf('   w_c=%.0e | mesh=%g | max_iter=%d | w_exo=%d\n', ...
        W_RESERVE, MESH_INTERVAL, MAX_ITER, EXO_WEIGHT_STATIC);
fprintf('================================================================================\n');
fprintf('   %-10s %-14s %-14s %-12s %-16s\n', ...
        'Weakness','Peak (Nm)','RMS (Nm)','Time (min)','Status');
fprintf('   ------------------------------------------------------------------\n');
for i = 1:nLevels
    fprintf('   %-10s %-14.4f %-14.4f %-12.1f %-16s\n', ...
        sprintf('%d%%',resultsSummary(i,1)), resultsSummary(i,2), ...
        resultsSummary(i,3), resultsSummary(i,4)/60, statusList{i});
end
fprintf('   ------------------------------------------------------------------\n');

pk = resultsSummary(:,2);
if issorted(pk) && pk(1) < pk(end)
    fprintf('   TREND (peak): ASCENDING  20%% < 30%% < 50%%\n');
elseif issorted(flipud(pk)) && pk(1) > pk(end)
    fprintf('   TREND (peak): DESCENDING 20%% > 30%% > 50%%\n');
else
    fprintf('   TREND (peak): NON-MONOTONIC\n');
end

rm = resultsSummary(:,3);
if issorted(rm) && rm(1) < rm(end)
    fprintf('   TREND (RMS) : ASCENDING\n');
elseif issorted(flipud(rm)) && rm(1) > rm(end)
    fprintf('   TREND (RMS) : DESCENDING\n');
else
    fprintf('   TREND (RMS) : NON-MONOTONIC\n');
end

fprintf('   Total runtime: %.1f min\n', sum(resultsSummary(:,4))/60);
if any(resultsSummary(:,5)==0)
    fprintf('   WARNING: kapoia senaria DEN synklinan - dilose to sto paper.\n');
end
fprintf('================================================================================\n');

%% ===== 6. PLOT =====
figure('Name','FesRobex - Gap Strategy v3','Color','w','Position',[100 100 700 450]);
b = bar(categorical({'20%','30%','50%'}), [resultsSummary(:,2), resultsSummary(:,3)]);
b(1).FaceColor = [0.55 0.55 0.55];
b(2).FaceColor = [0.25 0.45 0.75];
ylabel('Assistive Torque (Nm)'); xlabel('Weakness Level');
title(sprintf('Gap Strategy (w_{exo} = %d, static)', EXO_WEIGHT_STATIC));
legend({'Peak','RMS'},'Location','northwest'); grid on;
saveas(gcf, fullfile(DIR_PLOTS, sprintf('GapV3_%s_Summary.pdf', RUN_TAG)));

%% ===== 7. SAVE =====
save(fullfile(resultsDir, ['GapV3_Summary_' RUN_TAG '.mat']), ...
     'resultsSummary','statusList','EXO_WEIGHT_STATIC','W_RESERVE', ...
     'MESH_INTERVAL','MAX_ITER','FD_SCHEME');

fprintf('\n   Results: %s\n', resultsDir);
fprintf('   Plots:   %s\n', DIR_PLOTS);
fprintf('================================================================================\n');