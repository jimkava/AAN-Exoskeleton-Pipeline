%% RUN_ALL_WEAKNESS_LEVELS_DETAILED.m
%  1. Τρέχει για ΟΛΑ τα ποσοστά (10% - 80%).
%  2. Εμφανίζει ΑΝΑΛΥΤΙΚΑ στοιχεία για κάθε επίπεδο (όπως ζήτησες).
%  3. Φτιάχνει σωστό Συγκεντρωτικό Πίνακα στο τέλος.

clc; clear; close all;

%% --- 1. ΡΥΘΜΙΣΕΙΣ (SETTINGS) ---
WEAKNESS_LEVELS = [10, 20, 30, 40, 50, 60, 70, 80]; 
GEAR_RATIO = 50; 
EFFICIENCY = 0.80; 

ROOT = 'C:\OpenSim 4.5\sdk\Models\DropFoot_GaitRehab_FESRobex\Gaithab_FesRobex_project_22.12.25\MATLAB\Open-Loop Model\Moco_Phase4_Adult_Normal';
DB_FILE = 'Maxon_MASTER_Combined_DB.xlsx'; 

% Πίνακας για το Συγκεντρωτικό Report
GlobalSummary = table();

fprintf('================================================================================\n');
fprintf('   ΜΑΖΙΚΗ ΕΠΙΛΟΓΗ ΚΙΝΗΤΗΡΩΝ (BATCH PROCESS): %d ΣΕΝΑΡΙΑ\n', length(WEAKNESS_LEVELS));
fprintf('================================================================================\n');


%% --- 2. ΦΟΡΤΩΣΗ ΒΑΣΗΣ (ΜΙΑ ΦΟΡΑ) ---
if ~exist(DB_FILE, 'file'), error('❌ Λείπει το αρχείο %s', DB_FILE); end
opts = detectImportOptions(DB_FILE);
opts.VariableNamingRule = 'preserve';
AllMotors = readtable(DB_FILE, opts);
fprintf('✅ Βάση Δεδομένων: Φορτώθηκαν %d κινητήρες έτοιμοι για έλεγχο.\n\n', height(AllMotors));


%% --- 3. LOOP ΓΙΑ ΚΑΘΕ ΠΟΣΟΣΤΟ ΑΔΥΝΑΜΙΑΣ ---
for i = 1:length(WEAKNESS_LEVELS)
    lvl = WEAKNESS_LEVELS(i);
    
    % Τίτλος Σεναρίου για την οθόνη
    fprintf('\n\n'); % Κενές γραμμές για διαχωρισμό
    fprintf('################################################################################\n');
    fprintf('   ΣΕΝΑΡΙΟ %d/%d: ΑΣΘΕΝΗΣ ΜΕ %d%% ΑΔΥΝΑΜΙΑ ΤΕΤΡΑΚΕΦΑΛΩΝ\n', i, length(WEAKNESS_LEVELS), lvl);
    fprintf('################################################################################\n');
    
    try
        % --- A. PATHS ---
        folderName = sprintf('Weakness_%d', lvl);
        Input_Dir = fullfile(ROOT, '04_Results', 'Adaptive_Curve_Final', folderName);
        
        % Output Folder
        Output_Base = fullfile(ROOT, '04_Results', 'Motor_Selection_Reports', folderName);
        Report_Dir  = fullfile(Output_Base, 'Motor_Selection');
        if ~exist(Report_Dir, 'dir'), mkdir(Report_Dir); end
        
        % --- B. ΦΟΡΤΩΣΗ ΑΡΧΕΙΩΝ ---
        motName = sprintf('Animation_GUI_%d.mot', lvl);
        motFile = fullfile(Input_Dir, motName);
        stoFile = fullfile(Input_Dir, 'Result.sto');
        
        if ~exist(stoFile, 'file') || ~exist(motFile, 'file')
            fprintf('❌ SKIP: Δεν βρέθηκαν τα αρχεία για Weakness %d%%\n', lvl);
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
        
        % Απαιτήσεις Joint
        Req_Peak_mNm  = max(abs(exo_torque_nm)) * 1000;
        Req_RMS_mNm   = rms(exo_torque_nm) * 1000;
        Req_Speed_RPM = max(abs(knee_speed_rpm));
        
        % Απαιτήσεις Μοτέρ
        Load_RMS   = Req_RMS_mNm / (GEAR_RATIO * EFFICIENCY);
        Load_Peak  = Req_Peak_mNm / (GEAR_RATIO * EFFICIENCY);
        Load_Speed = Req_Speed_RPM * GEAR_RATIO;
        
        % --- D. ΑΝΑΛΥΤΙΚΗ ΕΚΤΥΠΩΣΗ ΑΠΑΙΤΗΣΕΩΝ (ΟΠΩΣ ΤΟ ΗΘΕΛΕΣ) ---
        fprintf('   ΑΝΑΛΥΣΗ ΑΠΑΙΤΗΣΕΩΝ (Requirements):\n');
        fprintf('   -----------------------------------\n');
        fprintf('   1. Απαιτήσεις Γόνατος (Output):\n');
        fprintf('      - RMS Torque:  %6.2f Nm\n', Req_RMS_mNm/1000);
        fprintf('      - Peak Torque: %6.2f Nm\n', Req_Peak_mNm/1000);
        fprintf('      - Max Speed:   %6.1f rpm\n', Req_Speed_RPM);
        fprintf('\n');
        fprintf('   2. Απαιτήσεις Κινητήρα (Input - Gear 1:%d):\n', GEAR_RATIO);
        fprintf('      - Nom. Torque: %4.0f mNm\n', Load_RMS);
        fprintf('      - Stall Torque:%4.0f mNm\n', Load_Peak);
        fprintf('      - Speed:       %4.0f rpm\n', Load_Speed);
        
        
        % --- E. ΕΠΙΛΟΓΗ ΚΙΝΗΤΗΡΑ ---
        LevelResults = table();
        
        for k = 1:height(AllMotors)
            row = AllMotors(k, :);
            PN = row.('Part Number');
            P_Watt = row.('Power [W]');
            T_Nom = row.('Nom. Torque [mNm]');
            T_Stall = row.('Stall T [mNm]');
            Spd_Max = row.('No-load rpm');
            Weight = row.('Weight [g]') / 1000;
            V_Nom = row.('Nom. V [V]');
            
            % Logic
            if (Load_RMS < T_Nom) && (Load_Peak < T_Stall) && (Load_Speed < Spd_Max)
                Status = 'ACCEPTED ✅';
            else
                Status = 'REJECTED ❌';
            end
            
            if contains(Status, 'ACCEPTED')
                entry = table(PN, P_Watt, Weight, T_Nom, T_Stall, V_Nom, {Status}, ...
                    'VariableNames', {'Part_Number', 'Power_W', 'Weight_Kg', 'Nom_mNm', 'Stall_mNm', 'Voltage', 'Result'});
                LevelResults = [LevelResults; entry];
            end
        end
        
        % --- F. ΑΝΑΛΥΤΙΚΗ ΑΝΑΔΕΙΞΗ ΝΙΚΗΤΗ ---
        Winner_PN = 0; Winner_W = 0; Winner_Kg = 0;
        
        if ~isempty(LevelResults)
            % Ταξινόμηση βάσει βάρους
            [~, idx] = sort(LevelResults.Weight_Kg, 'ascend');
            Winner = LevelResults(idx(1), :);
            
            Winner_PN = Winner.Part_Number;
            Winner_W = Winner.Power_W;
            Winner_Kg = Winner.Weight_Kg;
            
            fprintf('\n');
            fprintf('   🏆 ΒΕΛΤΙΣΤΗ ΕΠΙΛΟΓΗ ΓΙΑ %d%%:\n', lvl);
            fprintf('      -> Part Number: %d\n', Winner.Part_Number);
            fprintf('      -> Μοντέλο:     Maxon EC Flat %d Watt (%d V)\n', Winner.Power_W, Winner.Voltage);
            fprintf('      -> Βάρος:       %.3f kg\n', Winner.Weight_Kg);
            fprintf('      -> Status:      Καλύπτει όλες τις απαιτήσεις.\n');
            
            % Save Individual Report
            fname = sprintf('Report_Weakness_%d.xlsx', lvl);
            writetable(LevelResults, fullfile(Report_Dir, fname));
        else
            fprintf('\n   ❌ ΚΑΝΕΝΑΣ ΚΙΝΗΤΗΡΑΣ ΔΕΝ ΕΙΝΑΙ ΚΑΤΑΛΛΗΛΟΣ ΓΙΑ %d%%!\n', lvl);
        end
        
        % --- G. ΠΡΟΣΘΗΚΗ ΣΤΟ GLOBAL SUMMARY ---
        GlobalRow = table(lvl, Req_RMS_mNm/1000, Req_Peak_mNm/1000, Req_Speed_RPM, ...
                          Winner_PN, Winner_W, Winner_Kg, ...
            'VariableNames', {'Weakness_Perc', 'Req_RMS_Nm', 'Req_Peak_Nm', 'Req_Speed_RPM', ...
                              'Selected_Motor_PN', 'Motor_Power_W', 'Motor_Weight_Kg'});
        GlobalSummary = [GlobalSummary; GlobalRow];
        
    catch ME
        fprintf('❌ ERROR: %s\n', ME.message);
    end
end


%% --- 4. ΕΞΑΓΩΓΗ ΣΥΓΚΕΝΤΡΩΤΙΚΟΥ REPORT (ΚΑΘΑΡΗ ΜΟΡΦΗ) ---
fprintf('\n\n');
fprintf('================================================================================\n');
fprintf('   ΣΥΓΚΕΝΤΡΩΤΙΚΟΣ ΠΙΝΑΚΑΣ (GLOBAL SUMMARY)\n');
fprintf('================================================================================\n');

% Εκτύπωση στην οθόνη με σωστή μορφοποίηση (όχι scientific notation)
fprintf('%-10s | %-12s | %-12s | %-10s | %-15s | %-8s | %-10s\n', ...
    'Weakness', 'RMS Req(Nm)', 'Peak Req(Nm)', 'Speed(rpm)', 'Part Number', 'Power(W)', 'Weight(kg)');
fprintf('--------------------------------------------------------------------------------------------------\n');

for k = 1:height(GlobalSummary)
    fprintf('   %3d%%    |    %6.2f    |    %6.2f    |   %5.1f    |    %8d     |   %3d    |   %.3f\n', ...
        GlobalSummary.Weakness_Perc(k), ...
        GlobalSummary.Req_RMS_Nm(k), ...
        GlobalSummary.Req_Peak_Nm(k), ...
        GlobalSummary.Req_Speed_RPM(k), ...
        GlobalSummary.Selected_Motor_PN(k), ... % Εδώ το %d διασφαλίζει ότι θα φανεί ολόκληρο
        GlobalSummary.Motor_Power_W(k), ...
        GlobalSummary.Motor_Weight_Kg(k));
end
fprintf('--------------------------------------------------------------------------------------------------\n');


% Αποθήκευση στο κεντρικό φάκελο Results
GlobalFile = fullfile(ROOT, '04_Results', 'GLOBAL_MOTOR_SELECTION_SUMMARY.xlsx');
writetable(GlobalSummary, GlobalFile);

fprintf('\n💾 Το Αρχείο Excel αποθηκεύτηκε επιτυχώς:\n%s\n', GlobalFile);