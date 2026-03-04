%% RUN_ALL_WEAKNESS_LEVELS_FINAL.m
%  1. Batch Process (10-80%)
%  2. Detailed Reporting (Mechanical Requirements)
%  3. PLUS: Thermal & Electrical Validation (Hidden Logic added)

clc; clear; close all;

%% --- 1. ΡΥΘΜΙΣΕΙΣ (SETTINGS) ---
WEAKNESS_LEVELS = [10, 20, 30, 40, 50, 60, 70, 80]; 
GEAR_RATIO = 50; 
EFFICIENCY = 0.80; 
AMBIENT_TEMP = 25; % Θερμοκρασία Περιβάλλοντος

ROOT = 'C:\OpenSim 4.5\sdk\Models\DropFoot_GaitRehab_FESRobex\Gaithab_FesRobex_project_22.12.25\MATLAB\Open-Loop Model\Moco_Phase4_Adult_Normal';
DB_FILE = 'Maxon_MASTER_Combined_DB.xlsx'; 

GlobalSummary = table();

fprintf('================================================================================\n');
fprintf('   ΜΑΖΙΚΗ ΕΠΙΛΟΓΗ (MECH + THERMAL + ELECTRIC CHECK): %d ΣΕΝΑΡΙΑ\n', length(WEAKNESS_LEVELS));
fprintf('================================================================================\n');

%% --- 2. ΦΟΡΤΩΣΗ ΒΑΣΗΣ (ΜΙΑ ΦΟΡΑ) ---
if ~exist(DB_FILE, 'file'), error('❌ Λείπει το αρχείο %s', DB_FILE); end
opts = detectImportOptions(DB_FILE);
opts.VariableNamingRule = 'preserve';
AllMotors = readtable(DB_FILE, opts);
fprintf('✅ Βάση Δεδομένων: Φορτώθηκαν %d κινητήρες.\n', height(AllMotors));


%% --- 3. LOOP ΓΙΑ ΚΑΘΕ ΠΟΣΟΣΤΟ ΑΔΥΝΑΜΙΑΣ ---
for i = 1:length(WEAKNESS_LEVELS)
    lvl = WEAKNESS_LEVELS(i);
    
    fprintf('\n\n');
    fprintf('################################################################################\n');
    fprintf('   ΣΕΝΑΡΙΟ %d/%d: ΑΣΘΕΝΗΣ ΜΕ %d%%%% ΑΔΥΝΑΜΙΑ ΤΕΤΡΑΚΕΦΑΛΩΝ\n', i, length(WEAKNESS_LEVELS), lvl);
    fprintf('################################################################################\n');
    
    try
        % --- A. PATHS ---
        folderName = sprintf('Weakness_%d', lvl);
        Input_Dir = fullfile(ROOT, '04_Results', 'Adaptive_Curve_Final', folderName);
        Output_Base = fullfile(ROOT, '04_Results', 'Motor_Selection_Reports', folderName);
        Report_Dir  = fullfile(Output_Base, 'Motor_Selection');
        if ~exist(Report_Dir, 'dir'), mkdir(Report_Dir); end
        
        % --- B. LOAD FILES ---
        motName = sprintf('Animation_GUI_%d.mot', lvl);
        motFile = fullfile(Input_Dir, motName);
        stoFile = fullfile(Input_Dir, 'Result.sto');
        
        if ~exist(stoFile, 'file') || ~exist(motFile, 'file')
            fprintf('❌ SKIP: Δεν βρέθηκαν τα αρχεία.\n');
            continue;
        end
        
        data_force = importdata(stoFile);
        data_motion = importdata(motFile);
        Exo_Max_Torque = 100.0;
        
        % --- C. ΥΠΟΛΟΓΙΣΜΟΣ ΑΠΑΙΤΗΣΕΩΝ ---
        idx_torque = find(contains(data_force.colheaders, '/forceset/knee_exo_device'));
        exo_torque_nm = data_force.data(:, idx_torque) * Exo_Max_Torque;
        
        idx_angle = find(contains(data_motion.colheaders, 'knee_angle_r'));
        time = data_force.data(:, 1);
        time_motion = data_motion.data(:, 1);
        angle_deg = data_motion.data(:, idx_angle);
        angle_deg_sync = interp1(time_motion, angle_deg, time, 'linear', 'extrap');
        knee_speed_rpm = gradient(deg2rad(angle_deg_sync), mean(diff(time))) * (60 / (2*pi));
        
        % Requirements (Joint Level)
        Req_Peak_mNm  = max(abs(exo_torque_nm)) * 1000;
        Req_RMS_mNm   = rms(exo_torque_nm) * 1000;
        Req_Speed_RPM = max(abs(knee_speed_rpm));
        
        % Motor Load (Input Level)
        M_RMS   = Req_RMS_mNm / (GEAR_RATIO * EFFICIENCY);
        M_Peak  = Req_Peak_mNm / (GEAR_RATIO * EFFICIENCY);
        M_Speed = Req_Speed_RPM * GEAR_RATIO;
        
        % --- D. ΕΜΦΑΝΙΣΗ ΑΝΑΛΥΣΗΣ (ΔΙΑΤΗΡΗΣΗ ΠΑΛΙΟΥ FORMAT) ---
        fprintf('   ΑΝΑΛΥΣΗ ΑΠΑΙΤΗΣΕΩΝ (Requirements):\n');
        fprintf('   -----------------------------------\n');
        fprintf('   1. Απαιτήσεις Γόνατος (Output):\n');
        fprintf('      - RMS Torque:  %6.2f Nm\n', Req_RMS_mNm/1000);
        fprintf('      - Peak Torque: %6.2f Nm\n', Req_Peak_mNm/1000);
        fprintf('      - Max Speed:   %6.1f rpm\n', Req_Speed_RPM);
        fprintf('\n');
        fprintf('   2. Απαιτήσεις Κινητήρα (Input - Gear 1:%d):\n', GEAR_RATIO);
        fprintf('      - Nom. Torque: %4.0f mNm\n', M_RMS);
        fprintf('      - Stall Torque:%4.0f mNm\n', M_Peak);
        fprintf('      - Speed:       %4.0f rpm\n', M_Speed);
        
        
        % --- E. ΕΠΙΛΟΓΗ ΚΙΝΗΤΗΡΑ (ΜΕ ΠΡΟΣΘΗΚΗ THERMAL/VOLTAGE) ---
        LevelResults = table();
        
        for k = 1:height(AllMotors)
            row = AllMotors(k, :);
            PN = row.('Part Number');
            P_Watt = row.('Power [W]');
            T_Nom = row.('Nom. Torque [mNm]');
            T_Stall = row.('Stall T [mNm]');
            Spd_Max = row.('No-load rpm');
            Weight = row.('Weight [g]') / 1000;
            V_Supply = row.('Nom. V [V]');
            
            % --- ΝΕΟΙ ΥΠΟΛΟΓΙΣΜΟΙ (Χωρίς να χαλάνε το loop) ---
            % Ανάκτηση Ηλεκτρικών Στοιχείων (με ασφάλεια)
            if ismember('R ph-ph [Ω]', row.Properties.VariableNames)
                R = row.('R ph-ph [Ω]'); Kt = row.('Kt [mNm/A]'); Kn = row.('Kn [rpm/V]');
            else, R=0.5; Kt=30; Kn=300; end % Fallback values
            
            % Ανάκτηση Θερμικών Στοιχείων
            Rth = 8.0; 
            if ismember('Rth housing-amb [K/W]', row.Properties.VariableNames)
                Rth = row.('Rth housing-amb [K/W]') + row.('Rth winding-hous [K/W]');
            end
            
            % Υπολογισμοί
            I_RMS = M_RMS / Kt;               % Ρεύμα RMS
            Temp_Rise = (I_RMS^2 * R) * Rth;  % Αύξηση Θερμοκρασίας
            Final_Temp = AMBIENT_TEMP + Temp_Rise;
            
            I_Peak = M_Peak / Kt;             % Ρεύμα Peak
            V_Req = (M_Speed / Kn) + (I_Peak * R); % Απαιτούμενη Τάση
            
            % --- PASS/FAIL LOGIC ---
            ok_mech = (M_RMS < T_Nom) && (M_Peak < T_Stall) && (M_Speed < Spd_Max);
            ok_therm = (Final_Temp < 125);       % Να μην καεί (>125°C)
            ok_volt = (V_Req < V_Supply * 1.15); % Να φτάνει η μπαταρία (+15% tolerance)
            
            if ok_mech && ok_therm && ok_volt
                Status = 'ACCEPTED ✅';
            else
                Status = 'REJECTED ❌';
            end
            
            if contains(Status, 'ACCEPTED')
                entry = table(PN, P_Watt, Weight, T_Nom, T_Stall, V_Supply, Final_Temp, V_Req, {Status}, ...
                    'VariableNames', {'Part_Number', 'Power_W', 'Weight_Kg', 'Nom_mNm', 'Stall_mNm', 'Voltage', 'Temp_C', 'Req_V', 'Result'});
                LevelResults = [LevelResults; entry];
            end
        end
        
        % --- F. ΑΝΑΔΕΙΞΗ ΝΙΚΗΤΗ (ΕΜΠΛΟΥΤΙΣΜΕΝΗ ΕΜΦΑΝΙΣΗ) ---
        Winner_PN = 0; Winner_W = 0; Winner_Kg = 0; Winner_Temp = 0; Winner_Vreq = 0;
        
        if ~isempty(LevelResults)
            [~, idx] = sort(LevelResults.Weight_Kg, 'ascend');
            Winner = LevelResults(idx(1), :);
            
            Winner_PN = Winner.Part_Number;
            Winner_W = Winner.Power_W;
            Winner_Kg = Winner.Weight_Kg;
            Winner_Temp = Winner.Temp_C;
            Winner_Vreq = Winner.Req_V;
            
            fprintf('\n');
            fprintf('   🏆 ΒΕΛΤΙΣΤΗ ΕΠΙΛΟΓΗ ΓΙΑ %d%%:\n', lvl);
            fprintf('      -> Part Number: %d\n', Winner.Part_Number);
            fprintf('      -> Μοντέλο:     Maxon EC Flat %d Watt (%d V)\n', Winner.Power_W, Winner.Voltage);
            fprintf('      -> Βάρος:       %.3f kg\n', Winner.Weight_Kg);
            % ΕΔΩ ΠΡΟΣΘΕΣΑΜΕ ΤΑ ΝΕΑ ΣΤΟΙΧΕΙΑ ΧΩΡΙΣ ΝΑ ΧΑΛΑΣΟΥΜΕ ΤΑ ΠΑΛΙΑ
            fprintf('      -> Θερμοκρασία: %.1f °C (Όριο 125°C) ✅\n', Winner.Temp_C);
            fprintf('      -> Απαίτ. Τάση: %.1f V  (Supply %d V) ✅\n', Winner.Req_V, Winner.Voltage);
            
            % Save Report
            fname = sprintf('Report_Weakness_%d.xlsx', lvl);
            writetable(LevelResults, fullfile(Report_Dir, fname));
        else
            fprintf('\n   ❌ ΚΑΝΕΝΑΣ ΚΙΝΗΤΗΡΑΣ ΔΕΝ ΕΙΝΑΙ ΚΑΤΑΛΛΗΛΟΣ ΓΙΑ %d%%!\n', lvl);
        end
        
        % --- G. GLOBAL SUMMARY ---
        GlobalRow = table(lvl, Req_RMS_mNm/1000, Req_Peak_mNm/1000, Req_Speed_RPM, ...
                          Winner_PN, Winner_W, Winner_Kg, Winner_Temp, Winner_Vreq, ...
            'VariableNames', {'Weakness_Perc', 'Req_RMS_Nm', 'Req_Peak_Nm', 'Req_Speed_RPM', ...
                              'Selected_Motor_PN', 'Motor_Power_W', 'Motor_Weight_Kg', 'Motor_Temp_C', 'Motor_Req_V'});
        GlobalSummary = [GlobalSummary; GlobalRow];
        
    catch ME
        fprintf('❌ ERROR: %s\n', ME.message);
    end
end


%% --- 4. EXPORT GLOBAL SUMMARY (ΚΑΘΑΡΟΣ ΠΙΝΑΚΑΣ) ---
fprintf('\n\n');
fprintf('================================================================================\n');
fprintf('   ΣΥΓΚΕΝΤΡΩΤΙΚΟΣ ΠΙΝΑΚΑΣ (GLOBAL SUMMARY)\n');
fprintf('================================================================================\n');

fprintf('%-4s | %-6s | %-6s | %-6s | %-8s | %-4s | %-5s | %-5s | %-5s\n', ...
    'Weak', 'RMS(Nm)', 'Peak', 'Speed', 'PartNum', 'Watt', 'Kg', 'Temp', 'ReqV');
fprintf('------------------------------------------------------------------------------------------\n');

for k = 1:height(GlobalSummary)
    fprintf('%3d%% | %6.2f | %6.2f | %6.1f | %8d | %4d | %.3f | %5.1f | %5.1f\n', ...
        GlobalSummary.Weakness_Perc(k), ...
        GlobalSummary.Req_RMS_Nm(k), ...
        GlobalSummary.Req_Peak_Nm(k), ...
        GlobalSummary.Req_Speed_RPM(k), ...
        GlobalSummary.Selected_Motor_PN(k), ...
        GlobalSummary.Motor_Power_W(k), ...
        GlobalSummary.Motor_Weight_Kg(k), ...
        GlobalSummary.Motor_Temp_C(k), ...
        GlobalSummary.Motor_Req_V(k));
end
fprintf('------------------------------------------------------------------------------------------\n');

% Save
GlobalFile = fullfile(ROOT, '04_Results', 'GLOBAL_MOTOR_SELECTION_SUMMARY.xlsx');
writetable(GlobalSummary, GlobalFile);
fprintf('\n💾 Αποθηκεύτηκε: %s\n', GlobalFile);