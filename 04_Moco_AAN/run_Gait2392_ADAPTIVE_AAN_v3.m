% ======================================================================= %
%   PROJECT: FesRobex - Gait2392 Simbody Pipeline
%   SCRIPT:  run_Gait2392_ADAPTIVE_AAN_v3.m
%   FOLDER:  04_Moco_AAN\
%
%   METHOD:  ADAPTIVE AAN - w_exo(beta) = 10^(5 - 4*(beta-0.20)/0.30)
%            Weak20 -> 100000 | Weak30 -> 4642 | Weak50 -> 10
%
%   ================= SKOPOS =================
%   Antikathista to run_Gait2392_ADAPTIVE_AAN_v2.m me TAYTOSIMES
%   rithmiseis me to run_Gait2392_STATIC_GAP_v3.m, oste o Pinakas V
%   na einai pragmatiko ablation: i MONI diafora einai to w_exo.
%
%   ================= DIORTHOSEIS ENANTI TOU v2 =================
%
%   (1) RESERVE WEIGHT BUG (v2 gramme 189):
%           forceSet = baseModel.getForceSet();
%       To baseModel DEN periexei ta reserves (prostithentai apo to
%       ModOpAddReserves mesa ston ModelProcessor). Ara oute to 1e8
%       sto knee reserve oute to 1e3 sta ypoloipa efarmostikan pote -
%       ola pirane to Moco default 1.0.
%       Sto STATIC i idia diorthosi allaxe to peak apo 2.37 se 30.4 Nm.
%
%   (2) TYPO (v2 gramme 208): 'rec_fem_r' -> 'rect_fem_r'
%       O orthos miriaios epairne 1.0 anti gia 1e-4.
%
%   (3) 6 KLASEIS -> 3 (Eq. 6 tou paper): OLOI oi myes -> w_m.
%       Sto v2 oi synergistes (glut/gas/sol/tib) eixan 1e4, dld
%       1000x AKRIVOTEROI apo ton exo sto Weak50 (w_exo = 10).
%       Ta 29.88 Nm periexan ypokatastasi synergiston, oxi mono
%       apokrisi stin adynamia ton vasti.
%
%   (4) DEN ypirxe elegxos sygklisis. Ta 0.12/1.21/29.88 grafontan
%       anexartita apo to an o solver synekline. Edo elegxetai me
%       solution.success() kai dilonetai sto telikο table.
%
%   (5) mesh 0.02 -> 0.035 kai max_iter default -> 1000, oste na
%       tairiazoun me to Static v3.
%
%   ================= DEN PERILAMVANETAI =================
%   Supabase / motor selection. Auto to script kanei MONO tin
%   prosomoiosi. To motor selection trexei xexorista afou
%   epalithefthoun oi ropes.
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

%% ===== 0. CONFIG - TAYTOSIMO ME TO STATIC v3 =====
W_RESERVE      = 1e4;       % w_c  - idio me Static v3
W_MUSCLE       = 1e-4;      % w_m  - OLOI oi myes (Eq. 6)

MESH_INTERVAL  = 0.035;     % idio me Static v3
SOLVER_TOL     = 1e-1;      % idio me Static v3
MAX_ITER       = 1000;      % idio me Static v3
FD_SCHEME      = 'forward';
USE_PARALLEL   = 0;

% --- Adaptation law (Eq. 9) - I MONI DIAFORA APO TO STATIC ---
BETA_MIN = 0.20;
BETA_MAX = 0.50;
adaptLaw = @(b) 10^(5 - 4*(b - BETA_MIN)/(BETA_MAX - BETA_MIN));

RUN_TAG = sprintf('adaptive_wc%.0e_mesh%g_it%d', W_RESERVE, MESH_INTERVAL, MAX_ITER);
fprintf('\n>>> RUN_TAG = %s | 3-class weights (Eq. 6)\n', RUN_TAG);

%% ===== 1. PATHS =====
ROOT         = fileparts(fileparts(mfilename('fullpath')));   % repo root (parent of 04_Moco_AAN)
DIR_INPUTS   = fullfile(ROOT, '01_Input_Files');
DIR_WEAKNESS = fullfile(ROOT, '03_projectGait2392_weakness');
DIR_MOCO     = fullfile(ROOT, '04_Moco_AAN');
DIR_OUT      = fullfile(DIR_MOCO, 'Results_v3_Adaptive');
DIR_PLOTS    = fullfile(DIR_OUT, 'Plots');

if ~exist(DIR_OUT,  'dir'), mkdir(DIR_OUT);  end
if ~exist(DIR_PLOTS,'dir'), mkdir(DIR_PLOTS); end

ikFile = fullfile(DIR_INPUTS, 'subject01_walk1_ik.mot');
grfMot = fullfile(DIR_INPUTS, 'subject01_walk1_grf.mot');
grfXml = fullfile(DIR_INPUTS, 'subject01_walk1_grf.xml');

weakModels(1).pct = 20; weakModels(1).beta = 0.20;
weakModels(1).osim = fullfile(DIR_WEAKNESS,'subject01_simbody_weak20.osim');
weakModels(2).pct = 30; weakModels(2).beta = 0.30;
weakModels(2).osim = fullfile(DIR_WEAKNESS,'subject01_simbody_weak30.osim');
weakModels(3).pct = 50; weakModels(3).beta = 0.50;
weakModels(3).osim = fullfile(DIR_WEAKNESS,'subject01_simbody_weak50.osim');

resultsDir = fullfile(DIR_OUT, ['Results_' RUN_TAG]);
if ~exist(resultsDir,'dir'), mkdir(resultsDir); end

%% ===== 2. HEADER =====
fprintf('================================================================================\n');
fprintf('   FesRobex | ADAPTIVE AAN v3 | w_exo(beta) = 10^(5 - 4*(b-0.20)/0.30)\n');
fprintf('   w_c = %.0e | mesh = %g | max_iter = %d | FD = %s\n', ...
        W_RESERVE, MESH_INTERVAL, MAX_ITER, FD_SCHEME);
fprintf('   Settings IDENTICAL to Static Gap v3 - only w_exo differs.\n');
fprintf('================================================================================\n\n');

fprintf('   Adaptation law preview:\n');
for k = 1:3
    fprintf('     Weak%2d%%  beta = %.2f  ->  w_exo = %.0f\n', ...
            weakModels(k).pct, weakModels(k).beta, adaptLaw(weakModels(k).beta));
end
fprintf('\n');

for f = {ikFile, grfMot, grfXml}
    assert(exist(f{1},'file')>0, 'MISSING: %s', f{1});
end
for k = 1:numel(weakModels)
    assert(exist(weakModels(k).osim,'file')>0, 'MISSING model: %s', weakModels(k).osim);
end
fprintf('All input files located.\n\n');

%% ===== 3. INIT =====
nLevels        = numel(weakModels);
resultsSummary = zeros(nLevels,6);   % [pct, peak, rms, exoWeight, elapsed_s, converged]
statusList     = cell(nLevels,1);

%% ===== 4. MAIN LOOP =====
for i = 1:nLevels

    wkPct = weakModels(i).pct;
    beta  = weakModels(i).beta;
    strWk = sprintf('%d', wkPct);
    runDir = fullfile(resultsDir, ['Weakness_' strWk]);
    if ~exist(runDir,'dir'), mkdir(runDir); end

    % --- ADAPTIVE WEIGHT (Eq. 9) ---
    exoWeight = adaptLaw(beta);

    fprintf('--------------------------------------------------------------------------------\n');
    fprintf('   SCENARIO %d/%d: WEAKNESS %d%%  |  beta = %.2f  |  w_exo = %.0f (adaptive)\n', ...
            i, nLevels, wkPct, beta, exoWeight);
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

    % >>> BUG FIX: to processed montelo PERIEXEI ta reserves <<<
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

    % --- GOAL ---
    debugFile = fullfile(runDir,'Debug.omoco');
    study.print(debugFile);
    tok = regexp(fileread(debugFile),'MocoControlGoal name="([^"]+)"','tokens');
    if isempty(tok), goalName = 'excitation_effort'; else, goalName = tok{1}{1}; end
    goal = MocoControlGoal.safeDownCast(problem.updGoal(goalName));

    % ================= WEIGHTS (processed forceset, 3 klaseis) =========
    fs = procModel.getForceSet();
    nExo = 0; nReserve = 0; nTarget = 0; nOther = 0;
    kneeReserveFound = false;

    for f = 0:fs.getSize()-1
        force = fs.get(f);
        fname = char(force.getName());
        fpath = ['/forceset/' fname];

        if contains(fname,'knee_exo_device')
            goal.setWeightForControl(fpath, exoWeight);      % ADAPTIVE
            nExo = nExo + 1;

        elseif contains(lower(fname),'reserve')
            goal.setWeightForControl(fpath, W_RESERVE);
            nReserve = nReserve + 1;
            if contains(fname,'knee_angle_r'), kneeReserveFound = true; end

        else
            mus = Muscle.safeDownCast(force);
            if ~isempty(mus)
                goal.setWeightForControl(fpath, W_MUSCLE);
                nTarget = nTarget + 1;
            else
                nOther = nOther + 1;
            end
        end
    end

    fprintf('   Weights on PROCESSED model: exo=%d (w=%.0f) | reserves=%d | muscles=%d | other=%d\n', ...
            nExo, exoWeight, nReserve, nTarget, nOther);

    assert(nExo == 1, 'Expected 1 exo actuator, found %d.', nExo);
    assert(nReserve > 0, 'NO RESERVES FOUND -> w_c not applied.');
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
        solution.unseal();
        warning('Weak%d: solver did NOT converge. Apotelesma me epifylaxi.', wkPct);
    end

    stoFile = fullfile(runDir, ['Result_Adaptive_Weak' strWk '.sto']);
    solution.write(stoFile);

    % --- TORQUE ---
    d   = importdata(stoFile);
    idx = find(contains(d.colheaders,'knee_exo_device'));
    tq  = d.data(:,idx) * 100.0;          % OptimalForce = 100
    t   = d.data(:,1);

    dm  = importdata(ikFile);
    ia  = find(contains(dm.colheaders,'knee_angle_r'));
    ang = interp1(dm.data(:,1), dm.data(:,ia), t, 'linear','extrap');
    spd = gradient(deg2rad(ang), mean(diff(t))) * (60/(2*pi));

    peakNm = max(abs(tq));
    rmsNm  = rms(tq);

    fprintf('   >>> Peak: %.4f Nm | RMS: %.4f Nm | Speed: %.1f RPM\n', ...
            peakNm, rmsNm, max(abs(spd)));
    fprintf('   >>> Status: %s | Time: %.1f min\n\n', statusList{i}, elapsed/60);

    resultsSummary(i,:) = [wkPct, peakNm, rmsNm, exoWeight, elapsed, double(isOk)];

    figure('Color','w','Visible','off');
    plot(t, tq, 'r-','LineWidth',1.6); grid on;
    xlabel('Time (s)'); ylabel('Exo Torque (Nm)');
    title(sprintf('Adaptive AAN v3 | Weak%d%% | w_{exo}=%.0f | Peak = %.2f Nm', ...
                  wkPct, exoWeight, peakNm));
    saveas(gcf, fullfile(DIR_PLOTS, sprintf('AdaptiveV3_Weak%d.pdf', wkPct)));
    close all;
end

%% ===== 5. RESULTS =====
fprintf('================================================================================\n');
fprintf('   ADAPTIVE AAN v3 - Table V, Adaptive column\n');
fprintf('   w_c=%.0e | mesh=%g | max_iter=%d\n', W_RESERVE, MESH_INTERVAL, MAX_ITER);
fprintf('================================================================================\n');
fprintf('   %-10s %-12s %-14s %-14s %-12s %-16s\n', ...
        'Weakness','w_exo','Peak (Nm)','RMS (Nm)','Time (min)','Status');
fprintf('   --------------------------------------------------------------------------\n');
for i = 1:nLevels
    fprintf('   %-10s %-12.0f %-14.4f %-14.4f %-12.1f %-16s\n', ...
        sprintf('%d%%',resultsSummary(i,1)), resultsSummary(i,4), ...
        resultsSummary(i,2), resultsSummary(i,3), ...
        resultsSummary(i,5)/60, statusList{i});
end
fprintf('   --------------------------------------------------------------------------\n');

pk = resultsSummary(:,2);
if issorted(pk) && pk(1) < pk(end)
    fprintf('   TREND (peak): ASCENDING  20%% < 30%% < 50%%\n');
elseif issorted(flipud(pk)) && pk(1) > pk(end)
    fprintf('   TREND (peak): DESCENDING\n');
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

fprintf('\n   v2 reference (me to reserve bug): 0.1162 / 1.2094 / 29.8834 Nm\n');
fprintf('   Total runtime: %.1f min\n', sum(resultsSummary(:,5))/60);
if any(resultsSummary(:,6)==0)
    fprintf('   WARNING: kapoia senaria DEN synklinan.\n');
end
fprintf('================================================================================\n');

%% ===== 6. PLOT =====
lbl = arrayfun(@(x) sprintf('%d%%',x), resultsSummary(:,1), 'UniformOutput', false);
figure('Name','FesRobex - Adaptive AAN v3','Color','w','Position',[100 100 700 450]);
b = bar(categorical(lbl), [resultsSummary(:,2), resultsSummary(:,3)]);
b(1).FaceColor = [0.80 0.15 0.15];
b(2).FaceColor = [0.95 0.60 0.30];
ylabel('Assistive Torque (Nm)'); xlabel('Weakness Level');
title('Adaptive AAN (w_{exo}(\beta))');
legend({'Peak','RMS'},'Location','northwest'); grid on;
saveas(gcf, fullfile(DIR_PLOTS,'AdaptiveV3_Summary.pdf'));

%% ===== 7. SAVE =====
save(fullfile(resultsDir, ['AdaptiveV3_Summary_' RUN_TAG '.mat']), ...
     'resultsSummary','statusList','W_RESERVE','W_MUSCLE', ...
     'MESH_INTERVAL','MAX_ITER','FD_SCHEME');

fprintf('\n   Results: %s\n', resultsDir);
fprintf('   Plots:   %s\n', DIR_PLOTS);
fprintf('================================================================================\n');
