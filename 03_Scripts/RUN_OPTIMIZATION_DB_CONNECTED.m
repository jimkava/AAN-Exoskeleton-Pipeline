%% RUN_OPTIMIZATION_DB_CONNECTED.m
%  1. Reads Motors from Supabase (Get)
%  2. Process Weakness Levels (10-80%)
%  3. Uploads Best Motor Selection back to Supabase (Post)

clc; clear; close all;

%% --- 1. ΡΥΘΜΙΣΕΙΣ & ΣΥΝΔΕΣΗ ---
WEAKNESS_LEVELS = [10, 20, 30, 40, 50, 60, 70, 80]; 
GEAR_RATIO = 50; 
EFFICIENCY = 0.80; 
AMBIENT_TEMP = 25; 
ROOT = 'C:\OpenSim 4.5\sdk\Models\DropFoot_GaitRehab_FESRobex\Gaithab_FesRobex_project_22.12.25\MATLAB\Open-Loop Model\Moco_Phase4_Adult_Normal';

fprintf('================================================================================\n');
fprintf('   🚀 ΕΚΚΙΝΗΣΗ: MATLAB <--> SUPABASE CLOUD INTEGRATION\n');
fprintf('================================================================================\n');

% 1. Σύνδεση στη Βάση
conn = connectToSupabase();

% 2. Λήψη Κινητήρων (Αντί για Excel)
fprintf('📥 Λήψη δεδομένων κινητήρων από το Cloud...\n');
AllMotors = getMotorTable(conn);

if isempty(AllMotors)
    error('❌ Δεν βρέθηκαν κινητήρες στη βάση δεδομένων!');
else
    fprintf('✅ Φορτώθηκαν επιτυχώς %d κινητήρες.\n', height(AllMotors));
end

GlobalSummary = table();

%% --- 2. LOOP ΑΝΑΛΥΣΗΣ ---
for i = 1:length(WEAKNESS_LEVELS)
    lvl = WEAKNESS_LEVELS(i);
    
    fprintf('\n--------------------------------------------------------------------------------\n');
    fprintf('   ΣΕΝΑΡΙΟ %d/%d: ΑΔΥΝΑΜΙΑ %d%%%%\n', i, length(WEAKNESS_LEVELS), lvl);
    
    try
        % --- A. PATHS & DATA LOAD (ΙΔΙΟ ΜΕ ΠΡΙΝ) ---
        folderName = sprintf('Weakness_%d', lvl);
        Input_Dir = fullfile(ROOT, '04_Results', 'Adaptive_Curve_Final', folderName);
        
        motFile = fullfile(Input_Dir, sprintf('Animation_GUI_%d.mot', lvl));
        stoFile = fullfile(Input_Dir, 'Result.sto');
        
        if ~exist(stoFile, 'file') || ~exist(motFile, 'file')
            fprintf('⚠️ SKIP: Δεν βρέθηκαν τα αρχεία sim.\n');
            continue;
        end
        
        % (Φόρτωση δεδομένων Sim - Κώδικας ίδιος με το original)
        data_force = importdata(stoFile);
        data_motion = importdata(motFile);
        idx_torque = find(contains(data_force.colheaders, '/forceset/knee_exo_device'));
        exo_torque_nm = data_force.data(:, idx_torque) * 100.0; % Exo_Max_Torque
        
        idx_angle = find(contains(data_motion.colheaders, 'knee_angle_r'));
        time = data_force.data(:, 1);
        time_motion = data_motion.data(:, 1);
        angle_deg = data_motion.data(:, idx_angle);
        angle_deg_sync = interp1(time_motion, angle_deg, time, 'linear', 'extrap');
        knee_speed_rpm = gradient(deg2rad(angle_deg_sync), mean(diff(time))) * (60 / (2*pi));
        
        % Requirements
        Req_Peak_mNm  = max(abs(exo_torque_nm)) * 1000;
        Req_RMS_mNm   = rms(exo_torque_nm) * 1000;
        Req_Speed_RPM = max(abs(knee_speed_rpm));
        
        % Motor Load Inputs
        M_RMS   = Req_RMS_mNm / (GEAR_RATIO * EFFICIENCY);
        M_Peak  = Req_Peak_mNm / (GEAR_RATIO * EFFICIENCY);
        M_Speed = Req_Speed_RPM * GEAR_RATIO;
        
        % --- B. ΕΠΙΛΟΓΗ ΚΙΝΗΤΗΡΑ (ΠΡΟΣΑΡΜΟΓΗ ΣΤΑ ΟΝΟΜΑΤΑ ΤΗΣ ΒΑΣΗΣ) ---
        LevelResults = table();
        
        for k = 1:height(AllMotors)
            row = AllMotors(k, :);
            
            % **ΠΡΟΣΟΧΗ**: Αντιστοίχιση ονομάτων από το SQL Table (Power_W_ κλπ)
            PN = row.PartNumber; 
            if iscell(PN), PN = str2double(PN); end % Fix αν είναι cell
            
            P_Watt = row.Power_W_;
            T_Nom = row.Nom_Torque_mNm_;
            T_Stall = row.StallT_mNm_;
            Spd_Max = row.No_loadRpm;
            V_Supply = row.Nom_V_V_;
            Weight = row.Weight_g_ / 1000;
            
            % Ηλεκτρικά/Θερμικά (Ασφαλής ανάγνωση)
            R = row.RPh_ph___; 
            Kt = row.Kt_mNm_A_; 
            Kn = row.Kn_rpm_V_;
            
            % Ανάκτηση Rth (επειδή δεν το έχουμε στον πίνακα, βάζουμε default 8.0)
            % Αν το προσθέσεις στη βάση αργότερα, άλλαξέ το εδώ.
            Rth = 8.0; 
            
            % Υπολογισμοί
            I_RMS = M_RMS / Kt;
            Temp_Rise = (I_RMS^2 * R) * Rth;
            Final_Temp = AMBIENT_TEMP + Temp_Rise;
            
            I_Peak = M_Peak / Kt;
            V_Req = (M_Speed / Kn) + (I_Peak * R);
            
            % Criteria
            ok_mech = (M_RMS < T_Nom) && (M_Peak < T_Stall) && (M_Speed < Spd_Max);
            ok_therm = (Final_Temp < 125);
            ok_volt = (V_Req < V_Supply * 1.15);
            
            if ok_mech && ok_therm && ok_volt
                Status = 'ACCEPTED';
            else
                Status = 'REJECTED';
            end
            
            if strcmp(Status, 'ACCEPTED')
                entry = table(PN, P_Watt, Weight, T_Nom, Final_Temp, V_Req, {Status}, ...
                    'VariableNames', {'Part_Number', 'Power_W', 'Weight_Kg', 'Nom_mNm', 'Temp_C', 'Req_V', 'Result'});
                LevelResults = [LevelResults; entry];
            end
        end
        
        % --- C. ΑΝΑΔΕΙΞΗ ΝΙΚΗΤΗ & UPLOAD ---
        if ~isempty(LevelResults)
            [~, idx] = sort(LevelResults.Weight_Kg, 'ascend');
            Winner = LevelResults(idx(1), :);
            
            fprintf('   🏆 ΝΙΚΗΤΗΣ: PN %d | %dW | %.1f°C | %.1fV\n', ...
                Winner.Part_Number, Winner.Power_W, Winner.Temp_C, Winner.Req_V);
            
            % --- 📤 UPLOAD ΣΤΟ SUPABASE ---
            % Φτιάχνουμε το SQL Insert Query
            insertQuery = sprintf([...
                'INSERT INTO "Simulation_Results" ', ...
                '(weakness_level, req_rms_nm, req_peak_nm, selected_motor_pn, ', ...
                'motor_power_w, motor_safety_temp_c, motor_req_voltage, status) ', ...
                'VALUES (%d, %.2f, %.2f, ''%d'', %d, %.2f, %.2f, ''OPTIMAL'')'], ...
                lvl, Req_RMS_mNm/1000, Req_Peak_mNm/1000, Winner.Part_Number, ...
                Winner.Power_W, Winner.Temp_C, Winner.Req_V);
            
            % Εκτέλεση Upload
            try
                exec(conn, insertQuery);
                fprintf('   ☁️  Upload στη βάση: ΕΠΙΤΥΧΙΑ ✅\n');
            catch SQL_ERR
                fprintf('   ⚠️ Upload Failed: %s\n', SQL_ERR.message);
            end
            
        else
            fprintf('   ❌ Κανένας κινητήρας δεν πληροί τα κριτήρια.\n');
            % Καταγραφή αποτυχίας στη βάση
             insertQuery = sprintf([...
                'INSERT INTO "Simulation_Results" (weakness_level, status) VALUES (%d, ''NO_SOLUTION'')'], lvl);
             exec(conn, insertQuery);
        end
        
    catch ME
        fprintf('❌ Σφάλμα στο Level %d: %s\n', lvl, ME.message);
    end
end

fprintf('\n✅ Η διαδικασία ολοκληρώθηκε.\n');