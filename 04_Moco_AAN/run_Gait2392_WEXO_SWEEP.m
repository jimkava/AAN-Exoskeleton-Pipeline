% ======================================================================= %
%   PROJECT: FesRobex - Gait2392 Simbody Pipeline
%   SCRIPT:  run_Gait2392_WEXO_SWEEP.m
%   FOLDER:  04_Moco_AAN\
%
%   SKOPOS: Na tekmiriosei ton isxyrismo tou paragrafou III-B:
%           "No single fixed value of w_exo can satisfy both requirements"
%           (diafaneia sto Weak20 KAI eparkeia sto Weak50).
%
%           Trexei tin STATIC arxitektoniki (STATHERO w_exo) me 4 times
%           [2000, 200, 20, 2] gia Weak20 kai Weak50. Deixnei oti kamia
%           STATHERI timi den petyxainei taftoxrona:
%             - megalo w_exo -> diafaneia PANTOU (kai sto Weak50 = kako)
%             - mikro w_exo  -> voitheia sto Weak50 ALLA early-activation
%                               sto Weak20 (xanetai i diafaneia)
%
%   ================= TAYTOSIMO ME TO ADAPTIVE v3 =================
%   OLES oi rithmiseis idies me to run_Gait2392_ADAPTIVE_AAN_v3.m:
%     - 3-class weights (oloi oi myes w_m=1e-4, reserves w_c=1e4)
%     - mesh=0.035, tol=1e-1, max_iter=1000, FD=forward
%     - knee_exo_device: CoordinateActuator, OptF=100, ctrl [-2,2]
%     - reserve weight loop panw sto PROCESSED montelo (bug fix)
%   I MONI diafora: to w_exo einai STATHERO (sweep), OXI adaptive(beta).
%
%   ================= POST-PROCESSING =================
%   Idio me to FesRobex_FilterCheck.m:
%     tau = abs(control)*OptF -> interp uniform -> 6Hz 4th-order
%     zero-phase Butterworth (filtfilt) -> clip<0 -> peak/RMS sto
%     ESOTERIKO parathyro 5-95% GC. Ara ta apotelesmata einai amesa
%     sygkrisima me ta 0.03/0.23/4.57 tou Pinaka V.
%
%   AUTHOR:  Dimitrios Kavalieros, EE & IT MSc. & MEd.
%   DATE:    August 2026
%   MODEL:   Gait2392 Simbody (subject01)
% ======================================================================= %

clear; clc; close all;
import org.opensim.modeling.*;

%% ===== 0. CONFIG - TAYTOSIMO ME TO ADAPTIVE v3 =====
W_RESERVE      = 1e4;       % w_c
W_MUSCLE       = 1e-4;      % w_m (oloi oi myes, Eq. 6)

MESH_INTERVAL  = 0.035;
SOLVER_TOL     = 1e-1;
MAX_ITER       = 1000;
FD_SCHEME      = 'forward';
USE_PARALLEL   = 0;

OPTF           = 100;       % knee_exo_device OptimalForce

% --- SWEEP: statheres times w_exo ---
WEXO_SWEEP = [2000, 200, 20, 2];

% --- Post-processing (idio me FilterCheck) ---
FC        = 6;             % Hz
FILT_ORD  = 4;             % 4th-order (butter(2,..) x2 logo filtfilt)
GC_LO     = 5;            % interior window %GC
GC_HI     = 95;

% --- Senaria: MONO Weak20 kai Weak50 (ta akra) ---
% (Weak30 den xreiazetai gia to sweep - to epixeirima einai sta akra)
sweepScenarios(1).pct = 20; sweepScenarios(1).osim_tag = 'weak20';
sweepScenarios(2).pct = 50; sweepScenarios(2).osim_tag = 'weak50';

RUN_TAG = sprintf('sweep_mesh%g_it%d', MESH_INTERVAL, MAX_ITER);
fprintf('\n>>> W_EXO SWEEP | RUN_TAG = %s\n', RUN_TAG);
fprintf('>>> Sweep values: [%s]\n', num2str(WEXO_SWEEP));
fprintf('>>> Scenarios: Weak20 (transparency test) + Weak50 (sufficiency test)\n\n');

%% ===== 1. PATHS =====
ROOT         = fileparts(fileparts(mfilename('fullpath')));   % repo root (parent of 04_Moco_AAN)
DIR_INPUTS   = fullfile(ROOT, '01_Input_Files');
DIR_WEAKNESS = fullfile(ROOT, '03_projectGait2392_weakness');
DIR_MOCO     = fullfile(ROOT, '04_Moco_AAN');
DIR_OUT      = fullfile(DIR_MOCO, 'Results_WexoSweep');
DIR_PLOTS    = fullfile(DIR_OUT, 'Plots');

if ~exist(DIR_OUT,  'dir'), mkdir(DIR_OUT);  end
if ~exist(DIR_PLOTS,'dir'), mkdir(DIR_PLOTS); end

ikFile = fullfile(DIR_INPUTS, 'subject01_walk1_ik.mot');
grfMot = fullfile(DIR_INPUTS, 'subject01_walk1_grf.mot');
grfXml = fullfile(DIR_INPUTS, 'subject01_walk1_grf.xml');

for s = 1:numel(sweepScenarios)
    sweepScenarios(s).osim = fullfile(DIR_WEAKNESS, ...
        sprintf('subject01_simbody_%s.osim', sweepScenarios(s).osim_tag));
end

% --- Assertions ---
for f = {ikFile, grfMot, grfXml}
    assert(exist(f{1},'file')>0, 'MISSING: %s', f{1});
end
for s = 1:numel(sweepScenarios)
    assert(exist(sweepScenarios(s).osim,'file')>0, ...
        'MISSING model: %s', sweepScenarios(s).osim);
end
fprintf('All input files located.\n\n');

%% ===== 2. RESULTS TABLE =====
% rows = (scenario x wexo), cols = [pct, wexo, rawPeak, filtPeak, filtRMS,
%                                    peakGC, converged, elapsed_s]
nS = numel(sweepScenarios);
nW = numel(WEXO_SWEEP);
R  = nan(nS*nW, 8);
statusList = cell(nS*nW,1);
row = 0;

%% ===== 3. MAIN NESTED LOOP =====
totalTic = tic;
for s = 1:nS
    pct   = sweepScenarios(s).pct;
    osimF = sweepScenarios(s).osim;
    strWk = sprintf('%d', pct);

    for w = 1:nW
        exoWeight = WEXO_SWEEP(w);
        row = row + 1;

        runDir = fullfile(DIR_OUT, sprintf('Weak%d_wexo%d', pct, exoWeight));
        if ~exist(runDir,'dir'), mkdir(runDir); end

        fprintf('================================================================\n');
        fprintf('  RUN %d/%d | Weak%d%% | w_exo = %d (FIXED)\n', ...
                row, nS*nW, pct, exoWeight);
        fprintf('================================================================\n');
        tStart = tic;

        % --- MODEL ---
        baseModel = Model(osimF);
        baseModel.initSystem();
        DeGrooteFregly2016Muscle.replaceMuscles(baseModel);
        baseModel.initSystem();

        % --- EXO (PRIN ton ModelProcessor) ---
        exo = CoordinateActuator();
        exo.setName('knee_exo_device');
        exo.setCoordinate(baseModel.getCoordinateSet().get('knee_angle_r'));
        exo.setOptimalForce(OPTF);
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

        % --- WEIGHTS (3-class, processed forceset) ---
        fs = procModel.getForceSet();
        nExo=0; nReserve=0; nTarget=0; nOther=0; kneeReserveFound=false;
        for f = 0:fs.getSize()-1
            force = fs.get(f);
            fname = char(force.getName());
            fpath = ['/forceset/' fname];
            if contains(fname,'knee_exo_device')
                goal.setWeightForControl(fpath, exoWeight);   % FIXED sweep value
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
        assert(nExo == 1, 'Expected 1 exo actuator, found %d.', nExo);
        assert(nReserve > 0, 'NO RESERVES FOUND.');
        assert(~kneeReserveFound, 'Reserve found at knee_angle_r.');

        % --- SOLVE ---
        fprintf('   Solving (w_exo=%d)...\n', exoWeight);
        solution = study.solve();
        elapsed  = toc(tStart);

        isOk = solution.success();
        if isOk
            statusList{row} = 'CONVERGED';
        else
            statusList{row} = 'NOT CONVERGED';
            solution.unseal();
            warning('Weak%d w_exo=%d: NOT converged.', pct, exoWeight);
        end

        stoFile = fullfile(runDir, sprintf('Result_Weak%d_wexo%d.sto', pct, exoWeight));
        solution.write(stoFile);

        % --- POST-PROCESSING (idio me FilterCheck + interior window) ---
        [rawPk, filtPk, filtRMS, pkGC] = ...
            filter_interior_peak(stoFile, OPTF, FC, FILT_ORD, GC_LO, GC_HI);

        fprintf('   >>> raw peak = %.4f | filt interior peak = %.4f Nm at GC=%.1f%% | filt RMS = %.4f\n', ...
                rawPk, filtPk, pkGC, filtRMS);
        fprintf('   >>> Status: %s | Time: %.1f min\n\n', statusList{row}, elapsed/60);

        R(row,:) = [pct, exoWeight, rawPk, filtPk, filtRMS, pkGC, double(isOk), elapsed];
    end
end

%% ===== 4. SUMMARY TABLE =====
fprintf('================================================================================\n');
fprintf('   W_EXO SWEEP RESULTS (filtered interior peaks, comparable to Table V)\n');
fprintf('================================================================================\n');
fprintf('   %-8s %-8s %-12s %-14s %-12s %-8s %-14s\n', ...
        'Weak','w_exo','Raw Pk(Nm)','FiltPk(Nm)','RMS(Nm)','pkGC','Status');
fprintf('   ----------------------------------------------------------------------------\n');
for r = 1:size(R,1)
    fprintf('   %-8d %-8d %-12.4f %-14.4f %-12.4f %-8.1f %-14s\n', ...
        R(r,1), R(r,2), R(r,3), R(r,4), R(r,5), R(r,6), statusList{r});
end
fprintf('   ----------------------------------------------------------------------------\n');

%% ===== 5. INTERPRETATION =====
fprintf('\n   ==== ELEGXOS ISXYRISMOU III-B ====\n');
fprintf('   Gia kathe statheri timi w_exo, elegxoume:\n');
fprintf('     - Weak20 filt peak: prepei na einai MIKRO (diafaneia, ~<0.1 Nm)\n');
fprintf('     - Weak50 filt peak: prepei na einai MEGALO (eparkeia, ~>4 Nm)\n\n');
for w = 1:nW
    exoWeight = WEXO_SWEEP(w);
    i20 = find(R(:,1)==20 & R(:,2)==exoWeight, 1);
    i50 = find(R(:,1)==50 & R(:,2)==exoWeight, 1);
    p20 = R(i20,4); p50 = R(i50,4);
    transp = p20 < 0.10;      % diafaneia sto Weak20
    suffic = p50 > 4.0;       % eparkeia sto Weak50
    if transp && suffic
        verdict = '*** SATISFIES BOTH -> III-B claim FALSE! ***';
    elseif transp && ~suffic
        verdict = 'transparent but INSUFFICIENT (no help @Weak50)';
    elseif ~transp && suffic
        verdict = 'sufficient but NOT transparent (early activation @Weak20)';
    else
        verdict = 'neither';
    end
    fprintf('   w_exo=%5d : Weak20=%.3f Weak50=%.3f -> %s\n', ...
            exoWeight, p20, p50, verdict);
end
fprintf('\n   Total runtime: %.1f min\n', toc(totalTic)/60);
fprintf('================================================================================\n');

%% ===== 6. PLOT =====
fig = figure('Color','w','Position',[100 100 800 500]);
p20 = arrayfun(@(x) R(find(R(:,1)==20 & R(:,2)==x,1),4), WEXO_SWEEP);
p50 = arrayfun(@(x) R(find(R(:,1)==50 & R(:,2)==x,1),4), WEXO_SWEEP);
semilogx(WEXO_SWEEP, p20, 'o-','LineWidth',2,'MarkerFaceColor','auto','DisplayName','Weak20 (transparency)');
hold on;
semilogx(WEXO_SWEEP, p50, 's-','LineWidth',2,'MarkerFaceColor','auto','DisplayName','Weak50 (sufficiency)');
yline(0.10,'--','transparency threshold','Color',[0.4 0.4 0.4]);
yline(4.0, ':','sufficiency threshold','Color',[0.4 0.4 0.4]);
xlabel('Fixed w_{exo}'); ylabel('Filtered interior peak u_{exo} (Nm)');
title('w_{exo} sweep: no single fixed value satisfies both requirements');
legend('Location','best'); grid on;
set(gca,'XDir','reverse');  % megalo w_exo aristera (diafaneia), mikro dexia
saveas(fig, fullfile(DIR_PLOTS,'WexoSweep_Summary.pdf'));
fprintf('   Plot saved: WexoSweep_Summary.pdf\n');

%% ===== 7. SAVE =====
save(fullfile(DIR_OUT, ['WexoSweep_' RUN_TAG '.mat']), ...
     'R','statusList','WEXO_SWEEP','sweepScenarios', ...
     'W_RESERVE','W_MUSCLE','MESH_INTERVAL','MAX_ITER','FC','GC_LO','GC_HI');
fprintf('   Results saved: %s\n', DIR_OUT);
fprintf('================================================================================\n');

%% ======================================================================
%  POST-PROCESSING FUNCTION (idio me FesRobex_FilterCheck.m + interior)
%  ======================================================================
function [rawPk, filtPk, filtRMS, pkGC] = ...
         filter_interior_peak(stoFile, OPTF, FC, ORDER, GC_LO, GC_HI)
    d   = importdata(stoFile);
    idx = find(contains(d.colheaders,'knee_exo_device'),1);
    t   = d.data(:,1);
    tau = abs(d.data(:,idx)) * OPTF;      % abs PRIN to filtro (opos FilterCheck)

    rawPk = max(tau);

    % --- Omoiomorfo grid gia to filtro ---
    dt  = mean(diff(t));
    fs  = 1/dt;
    tu  = (t(1):dt:t(end))';
    tau_u = interp1(t, tau, tu, 'linear');

    % --- 6Hz zero-phase Butterworth ---
    [b,a]   = butter(ORDER/2, FC/(fs/2), 'low');
    tau_fil = filtfilt(b, a, tau_u);
    tau_fil(tau_fil < 0) = 0;

    gc = (tu - tu(1))/(tu(end)-tu(1))*100;

    % --- ESOTERIKO parathyro 5-95% ---
    m = (gc >= GC_LO) & (gc <= GC_HI);
    [filtPk, iP] = max(tau_fil(m));
    gcm = gc(m);
    pkGC = gcm(iP);
    filtRMS = rms(tau_fil(m));
end
