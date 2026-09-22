% ======================================================================= %
%   PROJECT: FesRobex - Gait2392 Simbody Pipeline
%   SCRIPT:  run_Gait2392_CMC_WithExo_v5.m
%
%   ΣΤΟΧΟΣ: Weak models (20/30/50%) να βαδίζουν σαν Normal
%
%   ΑΡΧΙΤΕΚΤΟΝΙΚΗ:
%   -----------------------------------------------------------------------
%   STEP 0: Δημιουργία model_with_exo.osim
%           - Φόρτωση subject01_simbody_weakXX.osim
%           - Προσθήκη knee_exo_device (CoordinateActuator, unlimited)
%           - Αφαίρεση knee reserve (ή set σε ±0)
%           → CMC θα χρησιμοποιήσει ΜΟΝΟ exo για το knee
%
%   STEP 1: CMC run με Normal IK target
%           - desired_kinematics: subject01_walk1_ik.mot (Normal!)
%           - model: model_with_exo.osim
%           → CMC βρίσκει αυτόματα το exo torque που χρειάζεται
%
%   STEP 2: FD run με CMC controls
%           - Τρέχει FD με τα CMC controls (muscles + exo)
%           → Weak model βαδίζει σαν Normal!
%
%   STEP 3: Σύγκριση Normal vs Weak+Exo kinematics
%   -----------------------------------------------------------------------
%
%   ΚΛΕΙΔΙ: Το CMC βρίσκει το ΣΩΣΤΟ exo torque γιατί:
%   1. Target = Normal IK → αναγκάζει Normal kinematics
%   2. Knee reserve = ±0 → CMC ΥΠΟΧΡΕΩΝΕΤΑΙ να χρησιμοποιήσει exo
%   3. Exo = unlimited → CMC έχει ελευθερία να δώσει ό,τι χρειαστεί
%
%   AUTHOR:  Dimitrios Kavalieros, EE & IT MSc. & MEd.
%   DATE:    June 2026
% ======================================================================= %

clear; clc; close all;
import org.opensim.modeling.*;

%% ===== 1. PATHS =====
ROOT         = fileparts(fileparts(mfilename('fullpath')));   % repo root (parent of 04_Moco_AAN)
DIR_INPUTS   = fullfile(ROOT, '01_Input_Files');
DIR_WEAKNESS = fullfile(ROOT, '03_projectGait2392_weakness');
DIR_MOCO     = fullfile(ROOT, '04_Moco_AAN');
DIR_PLOTS    = fullfile(ROOT, '05_Plots');

% Normal IK — TARGET για όλα τα σενάρια
ikFile_normal = fullfile(DIR_INPUTS, 'subject01_walk1_ik.mot');
grfFile       = fullfile(DIR_INPUTS, 'subject01_walk1_grf.mot');
grfXml        = fullfile(DIR_INPUTS, 'subject01_walk1_grf.xml');
rraKin        = fullfile(DIR_INPUTS, 'subject01_walk1_RRA_Kinematics_q.sto');

% CMC input files (ίδια για όλα)
cmcActuators = fullfile(DIR_INPUTS, 'gait2392_CMC_Actuators.xml');
cmcTasks     = fullfile(DIR_INPUTS, 'gait2392_CMC_Tasks.xml');

% ===== ΣΕΝΑΡΙΑ =====
% Κάθε σενάριο έχει το δικό του constraints file (knee reserve απενεργοποιημένο)
scenarios(1).pct         = 20;
scenarios(1).label       = 'Weak20';
scenarios(1).osim        = fullfile(DIR_WEAKNESS, 'subject01_simbody_weak20.osim');
scenarios(1).fd_xml      = fullfile(DIR_INPUTS, 'Setup_Forward_weak20_newik.xml');
scenarios(1).constraints = fullfile(DIR_INPUTS, ...
    'gait2392_CMC_ControlConstraints_noknee_ZERO_weak20.xml');

scenarios(2).pct         = 30;
scenarios(2).label       = 'Weak30';
scenarios(2).osim        = fullfile(DIR_WEAKNESS, 'subject01_simbody_weak30.osim');
scenarios(2).fd_xml      = fullfile(DIR_INPUTS, 'Setup_Forward_weak30_newik.xml');
scenarios(2).constraints = fullfile(DIR_INPUTS, ...
    'gait2392_CMC_ControlConstraints_noknee_ZERO_weak30.xml');

scenarios(3).pct         = 50;
scenarios(3).label       = 'Weak50';
scenarios(3).osim        = fullfile(DIR_WEAKNESS, 'subject01_simbody_weak50.osim');
scenarios(3).fd_xml      = fullfile(DIR_INPUTS, 'Setup_Forward_weak50_newik.xml');
scenarios(3).constraints = fullfile(DIR_INPUTS, ...
    'gait2392_CMC_ControlConstraints_noknee_ZERO_weak50.xml');

% Time window
T_START = 0.56;
T_END   = 1.99;

DIR_RESULTS = fullfile(DIR_MOCO, 'Results_v5_CMC_Exo');
if ~exist(DIR_RESULTS, 'dir'), mkdir(DIR_RESULTS); end

%% ===== 2. HEADER =====
fprintf('================================================================================\n');
fprintf('   FesRobex | v5 - CMC with Exo Actuator\n');
fprintf('   ΣΤΟΧΟΣ: Weak models βαδίζουν σαν Normal\n');
fprintf('   Target: Normal IK (subject01_walk1_ik.mot)\n');
fprintf('================================================================================\n\n');

% Φόρτωση Normal IK
[time_normal, q_normal] = load_knee_angle(ikFile_normal);
fprintf('Normal IK: [%.2f, %.2f] deg\n\n', min(q_normal), max(q_normal));

%% ===== 3. ΚΥΡΙΟ LOOP =====
summary = struct();

for s = 1:length(scenarios)
    sc  = scenarios(s);
    pct = sc.pct;
    lbl = sc.label;
    runDir = fullfile(DIR_RESULTS, lbl);
    if ~exist(runDir, 'dir'), mkdir(runDir); end

    fprintf('================================================================================\n');
    fprintf('   ΣΕΝΑΡΙΟ: %s (%d%%)\n', lbl, pct);
    fprintf('================================================================================\n');

    % ----------------------------------------------------------------- %
    % STEP 0: Δημιουργία model με exo και χωρίς knee reserve
    % ----------------------------------------------------------------- %
    fprintf('\n[STEP 0] Δημιουργία model με exo (χωρίς knee reserve)...\n');
    osim_exo = create_model_with_exo(sc.osim, runDir);

    % ----------------------------------------------------------------- %
    % STEP 1: CMC με Normal IK target
    % ----------------------------------------------------------------- %
    fprintf('\n[STEP 1] CMC run με Normal IK target...\n');
    cmc_dir = fullfile(runDir, 'CMC_with_exo');
    if ~exist(cmc_dir, 'dir'), mkdir(cmc_dir); end

    % Δημιουργία CMC setup XML
    cmc_xml = create_cmc_xml(osim_exo, cmc_dir, ikFile_normal, ...
        grfXml, grfFile, cmcActuators, cmcTasks, sc.constraints, ...
        rraKin, ROOT, T_START, T_END);

    % Εκτέλεση CMC
    run_tool(cmc_xml, ROOT);

    % Έλεγξε αν παρήχθησαν controls
    d_ctl = dir(fullfile(cmc_dir, '*controls.xml'));
    if isempty(d_ctl)
        d_ctl = dir(fullfile(cmc_dir, '*controls.sto'));
    end
    if isempty(d_ctl)
        fprintf('   ⚠️  CMC controls not found — checking...\n');
        dir(cmc_dir)
        error('CMC failed for %s', lbl);
    end
    cmc_controls = fullfile(cmc_dir, d_ctl(1).name);
    fprintf('   CMC controls: %s\n', d_ctl(1).name);

    % Φόρτωση CMC exo torque (από Actuation_force.sto)
    d_act = dir(fullfile(cmc_dir, '*Actuation_force.sto'));
    if ~isempty(d_act)
        [time_exo, exo_nm] = load_exo_torque(fullfile(cmc_dir, d_act(1).name));
        fprintf('   CMC exo peak = %.4f Nm\n', max(abs(exo_nm)));
    end

    % ----------------------------------------------------------------- %
    % STEP 2: FD με CMC controls (muscles + exo)
    % ----------------------------------------------------------------- %
    fprintf('\n[STEP 2] FD με CMC+Exo controls...\n');

    % CMC states για initial conditions
    d_sts = dir(fullfile(cmc_dir, '*states.sto'));
    if isempty(d_sts)
        error('CMC states not found in %s', cmc_dir);
    end
    cmc_states = fullfile(cmc_dir, d_sts(1).name);

    fd_dir = fullfile(runDir, 'FD_with_exo');
    if ~exist(fd_dir, 'dir'), mkdir(fd_dir); end

    % Δημιουργία FD XML — χρησιμοποιεί CMC controls + exo model
    fd_xml = create_fd_xml(sc.fd_xml, fd_dir, cmc_controls, ...
        cmc_states, osim_exo, ROOT, DIR_INPUTS);
    run_tool(fd_xml, ROOT);

    % ----------------------------------------------------------------- %
    % STEP 3: Φόρτωση αποτελεσμάτων και σύγκριση
    % ----------------------------------------------------------------- %
    fprintf('\n[STEP 3] Σύγκριση Normal vs Weak+Exo...\n');

    % FD kinematics
    d_kin = dir(fullfile(fd_dir, '*Kinematics_q.sto'));
    if isempty(d_kin)
        error('FD Kinematics not found in %s', fd_dir);
    end
    [time_fd, q_fd] = load_knee_angle(fullfile(fd_dir, d_kin(1).name));

    % Common time grid
    t_common   = linspace(T_START, T_END, 1000)';
    q_normal_i = interp1(time_normal, q_normal, t_common, 'linear', 'extrap');
    q_fd_i     = interp1(time_fd, q_fd, t_common, 'linear', 'extrap');

    e         = q_normal_i - q_fd_i;
    rmse      = rms(e);
    peak_err  = max(abs(e));
    fprintf('   RMSE vs Normal = %.4f deg\n', rmse);
    fprintf('   Peak error     = %.4f deg\n', peak_err);

    summary(s).label    = lbl;
    summary(s).pct      = pct;
    summary(s).rmse     = rmse;
    summary(s).peak_err = peak_err;
    if exist('exo_nm','var')
        summary(s).exo_peak = max(abs(exo_nm));
    else
        summary(s).exo_peak = NaN;
    end

    % Plot
    figure('Name',['v5-' lbl],'Color','w','Position',[50 50 1200 800]);

    subplot(2,2,[1,2]);
    plot(t_common, q_normal_i, 'k-',  'LineWidth',2.5,'DisplayName','Normal Gait');
    hold on;
    plot(t_common, q_fd_i,     'r-',  'LineWidth',2,'DisplayName', ...
        sprintf('%s + Exo (RMSE=%.2f°)',lbl,rmse));
    xlabel('Time (s)'); ylabel('Knee Angle (deg)');
    title(sprintf('%s + CMC Exo vs Normal Gait', lbl));
    legend('Location','best'); grid on;

    subplot(2,2,3);
    plot(t_common, e, 'r-', 'LineWidth',1.5);
    yline(0,'k--'); yline(2,'b:'); yline(-2,'b:');
    xlabel('Time (s)'); ylabel('Error (deg)');
    title(sprintf('Error vs Normal | RMSE=%.3f° Peak=%.3f°',rmse,peak_err));
    grid on;

    subplot(2,2,4);
    if exist('time_exo','var') && exist('exo_nm','var')
        exo_i = interp1(time_exo, exo_nm, t_common, 'linear', 'extrap');
        plot(t_common, exo_i, 'g-', 'LineWidth',2);
        yline(0,'k:');
        xlabel('Time (s)'); ylabel('Exo Torque (Nm)');
        title(sprintf('CMC Exo Torque | Peak=%.2f Nm',max(abs(exo_nm))));
        grid on;
    end

    sgtitle(sprintf('FesRobex v5 | %s | CMC+Exo → Normal Gait', lbl), ...
        'FontSize',13,'FontWeight','bold');
    saveas(gcf, fullfile(DIR_PLOTS, ['v5_CMCExo_' lbl '.pdf']));
    fprintf('   Plot: v5_CMCExo_%s.pdf\n', lbl);
    close all; fprintf('\n');
end

%% ===== 4. SUMMARY =====
fprintf('================================================================================\n');
fprintf('   ΑΠΟΤΕΛΕΣΜΑΤΑ v5 — CMC with Exo\n');
fprintf('================================================================================\n');
fprintf('%-10s %-14s %-14s %-14s\n','Scenario','RMSE vs Norm','Peak Err','Exo Peak(Nm)');
fprintf('%s\n',repmat('-',1,54));
for s = 1:length(summary)
    fprintf('%-10s %-14.4f %-14.4f %-14.4f\n', ...
        summary(s).label, summary(s).rmse, ...
        summary(s).peak_err, summary(s).exo_peak);
end

save(fullfile(DIR_RESULTS,'Summary_v5.mat'),'summary');
fprintf('\nPIPELINE v5 ΟΛΟΚΛΗΡΩΘΗΚΕ\nResults: %s\n', DIR_RESULTS);

%% ======================================================================
%  ΒΟΗΘΗΤΙΚΕΣ ΣΥΝΑΡΤΗΣΕΙΣ
%  ======================================================================

function osim_out = create_model_with_exo(osim_file, results_dir)
% Προσθέτει knee_exo_device και αφαιρεί knee reserve
    import org.opensim.modeling.*;

    model = Model(osim_file);
    model.initSystem();

    % Πρόσθεσε exo actuator (unlimited range)
    forceSet = model.getForceSet();
    already_exists = false;
    for f = 0:forceSet.getSize()-1
        if strcmp(char(forceSet.get(f).getName()), 'knee_exo_device')
            already_exists = true; break;
        end
    end
    if ~already_exists
        exo = CoordinateActuator();
        exo.setName('knee_exo_device');
        exo.setCoordinate(model.getCoordinateSet().get('knee_angle_r'));
        exo.setOptimalForce(200);   % Μεγάλο OptimalForce για ελευθερία
        exo.setMinControl(-10.0);   % Unlimited range
        exo.setMaxControl(10.0);
        model.addForce(exo);
        fprintf('   knee_exo_device added (OptF=200, ctrl [-10,10]).\n');
    end

    model.initSystem();
    osim_out = fullfile(results_dir, 'model_with_exo.osim');
    model.print(osim_out);
    fprintf('   Model saved: %s\n', osim_out);
end

function xml_out = create_cmc_xml(osim_file, results_dir, ik_file, ...
    grf_xml, grf_mot, actuators, tasks, constraints, rra_kin, ...
    root_dir, t_start, t_end)
% Δημιουργεί CMC setup XML με:
% - Normal IK target
% - model με exo
% - knee_exo_device ελεύθερο να χρησιμοποιηθεί

    xml_out = fullfile(results_dir, 'Setup_CMC_with_exo.xml');

    % Χτίσε το XML από scratch
    content = sprintf([...
        '<?xml version="1.0" encoding="UTF-8" ?>\n'...
        '<OpenSimDocument Version="40000">\n'...
        '\t<CMCTool name="cmc_with_exo">\n'...
        '\t\t<model_file>%s</model_file>\n'...
        '\t\t<replace_force_set>false</replace_force_set>\n'...
        '\t\t<force_set_files>%s</force_set_files>\n'...
        '\t\t<results_directory>%s</results_directory>\n'...
        '\t\t<output_precision>8</output_precision>\n'...
        '\t\t<initial_time>%.6f</initial_time>\n'...
        '\t\t<final_time>%.6f</final_time>\n'...
        '\t\t<solve_for_equilibrium_for_auxiliary_states>true</solve_for_equilibrium_for_auxiliary_states>\n'...
        '\t\t<maximum_number_of_integrator_steps>20000</maximum_number_of_integrator_steps>\n'...
        '\t\t<maximum_integrator_step_size>1</maximum_integrator_step_size>\n'...
        '\t\t<minimum_integrator_step_size>1e-08</minimum_integrator_step_size>\n'...
        '\t\t<integrator_error_tolerance>1e-05</integrator_error_tolerance>\n'...
        '\t\t<external_loads_file>%s</external_loads_file>\n'...
        '\t\t<desired_kinematics_file>%s</desired_kinematics_file>\n'...
        '\t\t<task_set_file>%s</task_set_file>\n'...
        '\t\t<constraints_file>%s</constraints_file>\n'...
        '\t\t<rra_solution_file></rra_solution_file>\n'...
        '\t\t<low_pass_filter_frequency>6</low_pass_filter_frequency>\n'...
        '\t\t<divide_by_muscle_optimal_force>false</divide_by_muscle_optimal_force>\n'...
        '\t\t<actuator_set_configs/>\n'...
        '\t\t<cmc_time_window>0.01</cmc_time_window>\n'...
        '\t\t<cmc_target_dt>0.001</cmc_target_dt>\n'...
        '\t\t<use_fast_optimization_target>false</use_fast_optimization_target>\n'...
        '\t\t<optimizer_derivative_dx>1e-04</optimizer_derivative_dx>\n'...
        '\t\t<optimizer_convergence_criterion>1e-06</optimizer_convergence_criterion>\n'...
        '\t\t<optimizer_max_iterations>1000</optimizer_max_iterations>\n'...
        '\t\t<optimizer_print_level>0</optimizer_print_level>\n'...
        '\t\t<use_verbose_printing>false</use_verbose_printing>\n'...
        '\t</CMCTool>\n'...
        '</OpenSimDocument>\n'], ...
        strrep(osim_file,'\','/'), ...
        strrep(actuators,'\','/'), ...
        strrep(results_dir,'\','/'), ...
        t_start, t_end, ...
        strrep(grf_xml,'\','/'), ...
        strrep(ik_file,'\','/'), ...
        strrep(tasks,'\','/'), ...
        strrep(constraints,'\','/'));

    fid = fopen(xml_out,'w');
    fprintf(fid,'%s',content);
    fclose(fid);
    fprintf('   CMC XML: %s\n', xml_out);
end

function xml_out = create_fd_xml(xml_template, results_dir, controls_file, ...
    states_file, osim_file, root_dir, dir_inputs)
% Δημιουργεί Forward Tool XML

    xml_out = fullfile(results_dir,'Setup_Forward_v5.xml');
    txt = fileread(xml_template);

    txt=regexprep(txt,'<model_file>[^<]*</model_file>', ...
        ['<model_file>' strrep(osim_file,'\','/') '</model_file>']);
    txt=regexprep(txt,'<results_directory>[^<]*</results_directory>', ...
        ['<results_directory>' strrep(results_dir,'\','/') '</results_directory>']);
    txt=regexprep(txt,'<controls_file>[^<]*</controls_file>', ...
        ['<controls_file>' strrep(controls_file,'\','/') '</controls_file>']);
    txt=regexprep(txt,'<states_file>[^<]*</states_file>', ...
        ['<states_file>' strrep(states_file,'\','/') '</states_file>']);
    grf=fullfile(dir_inputs,'subject01_walk1_grf.xml');
    txt=regexprep(txt,'<external_loads_file>[^<]*</external_loads_file>', ...
        ['<external_loads_file>' strrep(grf,'\','/') '</external_loads_file>']);
    act=fullfile(dir_inputs,'gait2392_CMC_Actuators.xml');
    txt=regexprep(txt,'<force_set_files>[^<]*</force_set_files>', ...
        ['<force_set_files>' strrep(act,'\','/') '</force_set_files>']);

    fid=fopen(xml_out,'w'); fprintf(fid,'%s',txt); fclose(fid);
    fprintf('   FD XML: %s\n', xml_out);
end

function run_tool(xml_file, root_dir)
    cmd=sprintf('cd /d "%s" && "C:\\OpenSim 4.5\\bin\\opensim-cmd.exe" run-tool "%s"',...
        root_dir, xml_file);
    fprintf('   Running...\n');
    [status,output]=system(cmd);
    if status~=0
        fprintf('   WARNING:\n%s\n',output);
        error('Tool failed: %s',xml_file);
    else
        fprintf('   Completed OK.\n');
    end
end

function [time, angle_deg] = load_knee_angle(filepath)
    data=importdata(filepath);
    if ~isstruct(data), error('Cannot load: %s',filepath); end
    time_idx=find(strcmpi(data.colheaders,'time'),1);
    knee_idx=find(contains(lower(data.colheaders),'knee_angle_r') & ...
                 ~contains(lower(data.colheaders),'speed'),1);
    time=data.data(:,time_idx);
    angle_deg=data.data(:,knee_idx);
end

function [time, exo_nm] = load_exo_torque(actuation_file)
% Φορτώνει knee_exo_device torque από Actuation_force.sto
    data=importdata(actuation_file);
    if ~isstruct(data), error('Cannot load: %s',actuation_file); end
    time_idx=find(strcmpi(data.colheaders,'time'),1);
    exo_idx =find(contains(lower(data.colheaders),'knee_exo_device'),1);
    if isempty(exo_idx)
        warning('knee_exo_device not found in actuation file');
        time=[]; exo_nm=[]; return;
    end
    time  =data.data(:,time_idx);
    exo_nm=data.data(:,exo_idx);
end
