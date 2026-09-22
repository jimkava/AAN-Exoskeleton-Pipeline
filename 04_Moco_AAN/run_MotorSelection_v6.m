% ======================================================================= %
%   PROJECT: FesRobex - Gait2392 Simbody Pipeline
%   SCRIPT:  run_MotorSelection_v6.m
%   FOLDER:  04_Moco_AAN\
%
%   SKOPOS:  Motor selection apo ta apotelesmata tou Adaptive AAN v3,
%            me 6 Hz zero-phase Butterworth filtering ton controls,
%            KAI automati katagrafi ton apotelesmaton sto Supabase.
%
%   ================= ALLAGES ENANTI TOU v5 =================
%   (A) CLOUD WRITE-BACK: to v5 stamatouse se topiko .mat. To v6 grafei
%       ta apotelesmata ston pinaka simulation_results tou Supabase,
%       opos perigrafetai stin Enotita V-C tou paper. I sindesi ginetai
%       me tin idia connectToSupabase() pou xrisimopoieitai idi gia
%       tin anagnosi tis vasis kinitiron.
%
%   (B) IDEMPOTENT INSERT: prin apo kathe INSERT ginetai DELETE ton
%       grammon tou idiou weakness_level. Xoris auto, kathe re-run
%       prosthetei nea grammi kai o pinakas gemizei diplotypa
%       (etsi dimiourgithikan oi 14 grammes tou Iouniou 2026).
%
%   (C) KATAGRAFI TASIS: apothikevontai motor_req_voltage_v kai
%       motor_nom_voltage_v. Xoris auta, to eurima tis Enotitas V-B
%       (oti to ilektriko kritirio einai auto pou desmevei) den mporei
%       na fanei sto dashboard.
%
%   (D) REJECTION TRACE: katagrafetai o elafryteros ypopsifios pou
%       perase to mixaniko KAI to thermiko kritirio alla apetyxe MONO
%       sto ilektriko. Auto tekmirionei ton isxyrismo peri
%       "hierarchical evaluation" (Enotita V-A): to pipeline dokimazei
%       kai aporriptei, den epilegei apeutheias.
%
%   (E) SAFETY MARGIN: ypologizetai kai typonetai me ton typo tis
%       Ex. (14): SM = (T_stall - T_peak) / T_stall * 100.
%
%   PROSOXI: oi stiles motor_req_voltage_v, motor_nom_voltage_v,
%   rejected_motor_pn, rejected_reason, rejected_req_voltage_v,
%   rejected_nom_voltage_v prepei na yparxoun ston pinaka. An oxi:
%
%     ALTER TABLE simulation_results
%       ADD COLUMN IF NOT EXISTS motor_req_voltage_v    double precision,
%       ADD COLUMN IF NOT EXISTS motor_nom_voltage_v    double precision,
%       ADD COLUMN IF NOT EXISTS rejected_motor_pn      text,
%       ADD COLUMN IF NOT EXISTS rejected_reason        text,
%       ADD COLUMN IF NOT EXISTS rejected_req_voltage_v double precision,
%       ADD COLUMN IF NOT EXISTS rejected_nom_voltage_v double precision;
%
%   AUTHOR:  Dimitrios Kavalieros
%   DATE:    September 2026
% ======================================================================= %

clear; clc; close all;

%% ===== 1. PATHS =====
ROOT        = fileparts(fileparts(mfilename('fullpath')));   % repo root (parent of 04_Moco_AAN)
DIR_INPUTS  = fullfile(ROOT, '01_Input_Files');
DIR_MOCO    = fullfile(ROOT, '04_Moco_AAN');
DIR_DB      = fullfile(DIR_MOCO, 'Database Files');
DIR_QUERIES = fullfile(DIR_DB, 'queries');


addpath(DIR_DB); addpath(DIR_QUERIES);
ikFile  = fullfile(DIR_INPUTS, 'subject01_walk1_ik.mot');
DIR_RES = fullfile(DIR_MOCO, 'Results_v3_Adaptive', ...
                   'Results_adaptive_wc1e+04_mesh0.035_it1000');

scen(1).pct = 20; scen(1).sto = fullfile(DIR_RES,'Weakness_20','Result_Adaptive_Weak20.sto');
scen(2).pct = 30; scen(2).sto = fullfile(DIR_RES,'Weakness_30','Result_Adaptive_Weak30.sto');
scen(3).pct = 50; scen(3).sto = fullfile(DIR_RES,'Weakness_50','Result_Adaptive_Weak50.sto');

%% ===== 2. CONSTANTS =====
GEAR_RATIO   = 50;
EFFICIENCY   = 0.80;
AMBIENT_TEMP = 25;
RTH          = 8.0;      % C/W
TEMP_LIMIT   = 125;      % Class F
VOLT_MARGIN  = 1.00;
OPTIMAL_F    = 100;

% --- Filtering ---
FC     = 6;      % Hz - idio me RRA/CMC
FORDER = 4;
GC_LO  = 5;      % interior window
GC_HI  = 95;

% --- Cloud ---
DB_TABLE    = 'simulation_results';
RUN_STATUS  = 'OPTIMAL_v6';
PUSH_TO_DB  = true;      % false -> mono topiko .mat, xoris cloud write

%% ===== 3. VASI KINITIRON =====
fprintf('================================================================================\n');
fprintf('   FesRobex | MOTOR SELECTION v6 | Adaptive AAN, %d Hz filtered + Cloud\n', FC);
fprintf('   G = %d | eta = %.2f | T_amb = %d C | Rth = %.1f C/W\n', ...
        GEAR_RATIO, EFFICIENCY, AMBIENT_TEMP, RTH);
fprintf('================================================================================\n\n');

AllMotors = [];
conn      = [];
dbSource  = 'none';

try
    conn = connectToSupabase();
    AllMotors = getMotorTable(conn);
    dbSource  = 'supabase';
    fprintf('Vasi kinitiron: Supabase (%d kinitires)\n\n', height(AllMotors));
catch ME
    fprintf('Supabase apetyxe (%s)\n', ME.message);
    csvFile = fullfile(DIR_DB, 'Maxon_MASTER_Combined_sqlDB.csv');
    assert(exist(csvFile,'file')>0, 'Den vrethike oute to CSV.');
    AllMotors = readtable(csvFile);
    dbSource  = 'local_csv';
    fprintf('Vasi kinitiron: topiko CSV (%d kinitires)\n', height(AllMotors));

    numCols = {'Nom_I_A_','StallI_A_','Kt_mNm_A_','RPh_ph___','Power_W_', ...
               'PartNumber','Nom_V_V_','No_loadRpm','Nom_Torque_mNm_', ...
               'StallT_mNm_','Kn_rpm_V_','Weight_g_'};
    for c = 1:numel(numCols)
        cn = numCols{c};
        if ~ismember(cn, AllMotors.Properties.VariableNames), continue; end
        v = AllMotors.(cn);
        if iscell(v) || isstring(v)
            AllMotors.(cn) = str2double(strrep(string(v), ',', '.'));
        end
    end
    crit = {'Kt_mNm_A_','RPh_ph___','Kn_rpm_V_','StallT_mNm_', ...
            'Nom_Torque_mNm_','No_loadRpm','Nom_V_V_','Weight_g_'};
    bad = false(height(AllMotors),1);
    for c = 1:numel(crit)
        if ismember(crit{c}, AllMotors.Properties.VariableNames)
            bad = bad | isnan(AllMotors.(crit{c}));
        end
    end
    AllMotors(bad,:) = [];
    fprintf('   Egkyroi kinitires: %d\n\n', height(AllMotors));
end
assert(~isempty(AllMotors), 'Kena dedomena kinitiron.');

% To cloud write apaitei zontani JDBC sindesi. An i vasi diavastike apo
% CSV, den yparxei conn kai to push paraleipetai me rito minima.
if PUSH_TO_DB && ~strcmp(dbSource,'supabase')
    warning(['Vasi kinitiron apo CSV -> den yparxei JDBC sindesi. ' ...
             'To cloud write-back paraleipetai.']);
    PUSH_TO_DB = false;
end

%% ===== 4. INIT =====
nS  = numel(scen);
res = zeros(nS, 8);   % [pct peak rms shaftPeak PN power SM temp]
resV = zeros(nS,1);   % V_req nikiti
resS = zeros(nS,1);   % shaft speed (rpm)
resVnom = zeros(nS,1);% V_nom nikiti
winners = cell(nS,1);
rejects = cell(nS,1); % rejection trace ana senario

%% ===== 5. LOOP =====
for i = 1:nS

    wkPct = scen(i).pct;
    assert(exist(scen(i).sto,'file')>0, 'MISSING: %s', scen(i).sto);

    fprintf('--------------------------------------------------------------------------------\n');
    fprintf('   WEAKNESS %d%%\n', wkPct);
    fprintf('--------------------------------------------------------------------------------\n');

    % --- Torque apo to .sto ---
    d   = importdata(scen(i).sto);
    idx = find(contains(d.colheaders,'knee_exo_device'));
    t   = d.data(:,1);
    tau = abs(d.data(:,idx)) * OPTIMAL_F;

    % --- 6 Hz zero-phase Butterworth ---
    dt = mean(diff(t));  fs = 1/dt;
    tu = (t(1):dt:t(end))';
    tau_u = interp1(t, tau, tu, 'linear');
    [b,a]   = butter(FORDER/2, FC/(fs/2), 'low');
    tau_fil = filtfilt(b, a, tau_u);
    tau_fil(tau_fil < 0) = 0;

    gc = (tu - tu(1))/(tu(end)-tu(1))*100;
    in = gc > GC_LO & gc < GC_HI;
    [pk_int, ipk] = max(tau_fil(in));
    g_in = gc(in);

    Req_Peak_mNm = pk_int      * 1000;
    Req_RMS_mNm  = rms(tau_fil)* 1000;

    fprintf('   Raw peak      : %.4f Nm\n', max(tau));
    fprintf('   Filtered peak : %.4f Nm at %.1f%% GC\n', pk_int, g_in(ipk));
    fprintf('   Filtered RMS  : %.4f Nm\n', Req_RMS_mNm/1000);

    % --- Speed apo to normal IK (IDIO filtro/window me ti ropi) ---
    dm    = importdata(ikFile);
    ia    = find(contains(dm.colheaders,'knee_angle_r'), 1);
    ang   = interp1(dm.data(:,1), dm.data(:,ia), tu, 'pchip','extrap');
    ang_f = filtfilt(b, a, ang);              % idio [b,a] me ti ropi
    spd   = gradient(deg2rad(ang_f), dt) * (60/(2*pi));
    spd_i = abs(spd);  spd_i(~in) = NaN;      % idio interior window
    [Req_Speed_RPM, isp] = max(spd_i);

    fprintf('   Speed: %.2f rpm knee -> %.0f rpm shaft  @ %.1f%% GC\n', ...
            Req_Speed_RPM, Req_Speed_RPM*GEAR_RATIO, gc(isp));

    % --- Mechanical reduction (Eq. 11) ---
    M_RMS   = Req_RMS_mNm  / (GEAR_RATIO * EFFICIENCY);
    M_Peak  = Req_Peak_mNm / (GEAR_RATIO * EFFICIENCY);
    M_Speed = Req_Speed_RPM * GEAR_RATIO;

    fprintf('   Shaft: Peak = %.2f mNm | RMS = %.2f mNm | Speed = %.0f RPM\n', ...
            M_Peak, M_RMS, M_Speed);

    % --- Elegxos kinitiron (ierarxika: mixaniko -> thermiko -> ilektriko) ---
    LevelResults = table();
    Rejected     = table();   % perasan mix.+therm., apetyxan MONO ilektrika

    for k = 1:height(AllMotors)
        row = AllMotors(k,:);
        PN = row.PartNumber; if iscell(PN), PN = str2double(PN); end

        P_Watt  = row.Power_W_;      T_Nom   = row.Nom_Torque_mNm_;
        T_Stall = row.StallT_mNm_;   Spd_Max = row.No_loadRpm;
        V_Sup   = row.Nom_V_V_;      Weight  = row.Weight_g_/1000;
        R       = row.RPh_ph___;     Kt      = row.Kt_mNm_A_;
        Kn      = row.Kn_rpm_V_;
        Fam     = "";
        if ismember('Family', AllMotors.Properties.VariableNames)
            Fam = string(row.Family);
        end

        I_RMS      = M_RMS / Kt;
        Final_Temp = AMBIENT_TEMP + (I_RMS^2 * R) * RTH;
        I_Peak     = M_Peak / Kt;
        V_Req      = (M_Speed / Kn) + (I_Peak * R);

        ok_mech  = (M_RMS < T_Nom) && (M_Peak < T_Stall) && (M_Speed < Spd_Max);
        ok_therm = (Final_Temp < TEMP_LIMIT);
        ok_volt  = (V_Req < V_Sup * VOLT_MARGIN);

        if ok_mech && ok_therm && ok_volt
            entry = table(PN, P_Watt, Weight, T_Nom, T_Stall, Final_Temp, ...
                V_Req, V_Sup, Fam, ...
                'VariableNames', {'Part_Number','Power_W','Weight_Kg', ...
                                  'Nom_mNm','Stall_mNm','Temp_C','Req_V', ...
                                  'Nom_V','Family'});
            LevelResults = [LevelResults; entry]; %#ok<AGROW>

        elseif ok_mech && ok_therm && ~ok_volt
            % Ypopsifios pou kopike APOKLEISTIKA sto ilektriko kritirio.
            entry = table(PN, Weight, Final_Temp, V_Req, V_Sup, ...
                'VariableNames', {'Part_Number','Weight_Kg','Temp_C', ...
                                  'Req_V','Nom_V'});
            Rejected = [Rejected; entry]; %#ok<AGROW>
        end
    end

    if isempty(LevelResults)
        fprintf('   >>> KANENAS KINITIRAS den pliroi ta kritiria.\n\n');
        res(i,:) = [wkPct, pk_int, Req_RMS_mNm/1000, M_Peak, NaN, NaN, NaN, NaN];
        resS(i)  = M_Speed;
        continue;
    end

    % --- Nikitis: o elafryteros pou pliroi OLA ta kritiria ---
    [~, iW]  = sort(LevelResults.Weight_Kg, 'ascend');
    Winner   = LevelResults(iW(1), :);
    SM       = (Winner.Stall_mNm - M_Peak) / Winner.Stall_mNm * 100;   % Eq. (14)

    fprintf('   Ypopsifioi: %d | Aporrifthentes (ilektrika): %d\n', ...
            height(LevelResults), height(Rejected));
    fprintf('   >>> NIKITIS: PN %d | %d W | %.0f g | Stall %.0f mNm\n', ...
            Winner.Part_Number, Winner.Power_W, Winner.Weight_Kg*1000, Winner.Stall_mNm);
    fprintf('       SM = %.2f%% | T_w = %.2f C | V_req = %.2f / %.0f V\n', ...
            SM, Winner.Temp_C, Winner.Req_V, Winner.Nom_V);

    % --- Rejection trace: o elafryteros aporrifthentas ---
    if ~isempty(Rejected)
        [~, iR] = sort(Rejected.Weight_Kg, 'ascend');
        Rej = Rejected(iR(1), :);
        fprintf('       APORRIFTHIKE: PN %d | V_req = %.2f V > V_nom = %.0f V (%.1f%%)\n\n', ...
                Rej.Part_Number, Rej.Req_V, Rej.Nom_V, Rej.Req_V/Rej.Nom_V*100);
        rejects{i} = Rej;
    else
        fprintf('       Kamia aporripsi.\n\n');
        rejects{i} = [];
    end

    res(i,:)   = [wkPct, pk_int, Req_RMS_mNm/1000, M_Peak, ...
                  Winner.Part_Number, Winner.Power_W, SM, Winner.Temp_C];
    resV(i)    = Winner.Req_V;
    resVnom(i) = Winner.Nom_V;
    resS(i)    = M_Speed;
    winners{i} = Winner;
end

%% ===== 6. TABLE VII =====
fprintf('================================================================================\n');
fprintf('   TABLE VII - MOTOR SELECTION (Adaptive AAN, %d Hz filtered)\n', FC);
fprintf('================================================================================\n');
fprintf('   %-26s %-12s %-12s %-12s\n','Parameter','Weak20','Weak30','Weak50');
fprintf('   ------------------------------------------------------------------\n');
fprintf('   %-26s %-12.3f %-12.3f %-12.3f\n','Peak Knee Torque (Nm)',  res(1,2), res(2,2), res(3,2));
fprintf('   %-26s %-12.3f %-12.3f %-12.3f\n','RMS Knee Torque (Nm)',   res(1,3), res(2,3), res(3,3));
fprintf('   %-26s %-12.2f %-12.2f %-12.2f\n','Motor Shaft Peak (mNm)', res(1,4), res(2,4), res(3,4));
fprintf('   %-26s %-12d %-12d %-12d\n',      'Selected Motor (PN)',    res(1,5), res(2,5), res(3,5));
fprintf('   %-26s %-12d %-12d %-12d\n',      'Motor Power (W)',        res(1,6), res(2,6), res(3,6));
fprintf('   %-26s %-12.0f %-12.0f %-12.0f\n','Nominal Voltage (V)',    resVnom(1), resVnom(2), resVnom(3));
fprintf('   %-26s %-12.2f %-12.2f %-12.2f\n','Required Voltage (V)',   resV(1), resV(2), resV(3));
fprintf('   %-26s %-12.2f %-12.2f %-12.2f\n','Peak Temp (C)',          res(1,8), res(2,8), res(3,8));
fprintf('   %-26s %-12.2f %-12.2f %-12.2f\n','Safety Margin (%)',      res(1,7), res(2,7), res(3,7));
fprintf('   %-26s %-12.0f %-12.0f %-12.0f\n','Motor Shaft Speed (rpm)',resS(1), resS(2), resS(3));
fprintf('   ------------------------------------------------------------------\n');
fprintf('   Hardware rating (peak x 1.17): %.2f Nm\n', res(3,2)*1.17);
fprintf('================================================================================\n');

%% ===== 7. CLOUD WRITE-BACK =====
if PUSH_TO_DB
    fprintf('\n   --- Supabase write-back (%s) ---\n', DB_TABLE);
    stamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

    for i = 1:nS
        if isnan(res(i,5))
            fprintf('   Weakness %d%%: kamia lysi -> paraleipetai.\n', res(i,1));
            continue;
        end

        W   = winners{i};
        Rej = rejects{i};

        % --- IDEMPOTENCY: kathara ton palion grammon tou idiou epipedou ---
        % Xoris auto, kathe re-run afinei nea grammi kai ta charts
        % deixnoun diplotypa (vl. istoriko Iouniou 2026).
        delQ = sprintf('DELETE FROM %s WHERE weakness_level = %d;', ...
                       DB_TABLE, res(i,1));
        try
            exec(conn, delQ);
        catch ME
            warning('   DELETE apetyxe gia %d%%: %s', res(i,1), ME.message);
        end

        % --- Rejection trace ---
        if isempty(Rej)
            rejPN   = '''—''';
            rejWhy  = '''No candidate rejected''';
            rejReqV = 'NULL';
            rejNomV = 'NULL';
        else
            rejPN   = sprintf('''%d''', Rej.Part_Number);
            rejWhy  = '''Electrical: V_req exceeds nominal winding voltage''';
            rejReqV = sprintf('%.4f', Rej.Req_V);
            rejNomV = sprintf('%.4f', Rej.Nom_V);
        end

        fam = 'Maxon EC 45 flat';
        if ismember('Family', W.Properties.VariableNames) && strlength(W.Family) > 0
            fam = char(W.Family);
        end

        insQ = sprintf([ ...
            'INSERT INTO %s (' ...
            'weakness_level, selected_motor_pn, motor_family, motor_power_w, ' ...
            'required_torque_mnm, motor_rms_torque_mnm, motor_speed_rpm, ' ...
            'motor_torque_mnm, motor_stall_torque_mnm, motor_safety_temp_c, ' ...
            'motor_req_voltage_v, motor_nom_voltage_v, ' ...
            'rejected_motor_pn, rejected_reason, ' ...
            'rejected_req_voltage_v, rejected_nom_voltage_v, ' ...
            'status, timestamp) VALUES (' ...
            '%d, ''%d'', ''%s'', %d, ' ...
            '%.4f, %.4f, %.4f, ' ...
            '%.4f, %.4f, %.4f, ' ...
            '%.4f, %.4f, ' ...
            '%s, %s, %s, %s, ' ...
            '''%s'', ''%s'');'], ...
            DB_TABLE, ...
            res(i,1), W.Part_Number, fam, W.Power_W, ...
            res(i,4), res(i,3)*1000/(GEAR_RATIO*EFFICIENCY), resS(i), ...
            W.Nom_mNm, W.Stall_mNm, res(i,8), ...
            resV(i), resVnom(i), ...
            rejPN, rejWhy, rejReqV, rejNomV, ...
            RUN_STATUS, stamp);

        try
            exec(conn, insQ);
            fprintf('   Weakness %2d%%: INSERT OK (PN %d, SM %.2f%%)\n', ...
                    res(i,1), W.Part_Number, res(i,7));
        catch ME
            warning('   INSERT apetyxe gia %d%%: %s', res(i,1), ME.message);
        end
    end

    % --- Epalitheusi: diavazoume piso o,ti grapsame ---
    try
        chk = fetch(conn, sprintf([ ...
            'SELECT weakness_level, selected_motor_pn, required_torque_mnm, ' ...
            'motor_stall_torque_mnm, motor_req_voltage_v, motor_nom_voltage_v, ' ...
            'rejected_motor_pn FROM %s ORDER BY weakness_level;'], DB_TABLE));
        fprintf('\n   --- Epalitheusi apo ti vasi ---\n');
        disp(chk);
    catch ME
        warning('   Epalitheusi apetyxe: %s', ME.message);
    end

else
    fprintf('\n   Cloud write-back: OFF\n');
end

%% ===== 8. SAVE =====
save(fullfile(DIR_RES,'MotorSelection_v6.mat'), 'res','resV','resVnom','resS', ...
     'winners','rejects','GEAR_RATIO','EFFICIENCY','AMBIENT_TEMP','RTH', ...
     'FC','FORDER','dbSource');
fprintf('\n   Saved: %s\n', fullfile(DIR_RES,'MotorSelection_v6.mat'));
