%% RUN_OPTIMIZATION_FINAL_WITH_UPLOAD.m
%  VERSION 9.0: FIX CELL INPUTS & ADD STALL TORQUE
clc; clear; close all;

%% --- 1. ΡΥΘΜΙΣΕΙΣ & ΣΥΝΔΕΣΗ ---
WEAKNESS_LEVELS = [10, 20, 30, 40, 50, 60, 70, 80]; 
GEAR_RATIO = 50; 
EFFICIENCY = 0.80; 
AMBIENT_TEMP = 25; 
ROOT = 'C:\OpenSim 4.5\sdk\Models\DropFoot_GaitRehab_FESRobex\Gaithab_FesRobex_project_22.12.25\MATLAB\Open-Loop Model\Moco_Phase4_Adult_Normal';

fprintf('================================================================================\n');
fprintf('   🚀 ΕΚΚΙΝΗΣΗ: DIGITAL TWIN (MATLAB -> CLOUD -> WEB)\n');
fprintf('================================================================================\n');

try
    conn = connectToSupabase();
    fprintf('✅ Η ΣΥΝΔΕΣΗ ΕΠΙΤΕΥΧΘΗ!\n');
catch ME
    error('❌ Σφάλμα Σύνδεσης: %s', ME.message);
end

% Καθαρισμός Βάσης
fprintf('🧹 Καθαρισμός προηγούμενων αποτελεσμάτων...\n');
exec(conn, 'TRUNCATE TABLE simulation_results'); 

% Λήψη Κινητήρων
fprintf('📥 Λήψη δεδομένων κινητήρων...\n');
curs = exec(conn, 'SELECT * FROM "Maxon_EC_Flat_Motors"'); 
curs = fetch(curs);
AllMotors = cell2table(curs.Data, 'VariableNames', {'Power_W_', 'PartNumber', 'Type', 'Nom_V_V_', 'No_loadRpm', 'No_loadMA', 'Nom_Rpm', 'Nom_Torque_mNm_', 'Nom_I_A_', 'StallT_mNm_', 'StallI_A_', 'Eff____', 'Kt_mNm_A_', 'Kn_rpm_V_', 'RPh_ph___', 'Weight_g_', 'Family'});
fprintf('✅ Φορτώθηκαν επιτυχώς %d κινητήρες.\n', height(AllMotors));

%% --- 2. LOOP ΑΝΑΛΥΣΗΣ ---
for i = 1:length(WEAKNESS_LEVELS)
    lvl = WEAKNESS_LEVELS(i);
    fprintf('\n--- ΣΕΝΑΡΙΟ %d/%d: ΑΔΥΝΑΜΙΑ %d%% ---\n', i, length(WEAKNESS_LEVELS), lvl);
    
    try
        % --- A. ΦΟΡΤΩΣΗ ΔΕΔΟΜΕΝΩΝ ---
        folderName = sprintf('Weakness_%d', lvl);
        Input_Dir = fullfile(ROOT, '04_Results', 'Adaptive_Curve_Final', folderName);
        stoFile = fullfile(Input_Dir, 'Result.sto');
        data_force = importdata(stoFile);
        sto_data = data_force.data; sto_cols = data_force.colheaders;
        idx_torque = find(contains(sto_cols, 'knee_exo_device') | contains(sto_cols, 'knee_actuator'));
        exo_torque_nm = sto_data(:, idx_torque(1)) * 100.0; 
        M_RMS = rms(exo_torque_nm) * 1000 / (GEAR_RATIO * EFFICIENCY);
        
        % --- B. ΕΠΙΛΟΓΗ ΚΙΝΗΤΗΡΑ ---
        Candidates = table();
        for k = 1:height(AllMotors)
            row = AllMotors(k, :);
            
            % ΠΡΟΣΕΚΤΙΚΗ ΜΕΤΑΤΡΟΠΗ ΑΠΟ CELL ΣΕ DOUBLE
            PN = row.PartNumber; if iscell(PN), PN = str2double(string(PN{1})); end
            T_Nom = row.Nom_Torque_mNm_; if iscell(T_Nom), T_Nom = cell2mat(T_Nom); end
            R = row.RPh_ph___; if iscell(R), R = cell2mat(R); end
            Kt = row.Kt_mNm_A_; if iscell(Kt), Kt = cell2mat(Kt); end
            P_Check = row.Power_W_; if iscell(P_Check), P_Check = cell2mat(P_Check); end
            
            Rth = 8.0; if P_Check >= 80, Rth = 3.0; end
            Temp_F = AMBIENT_TEMP + ((M_RMS/Kt)^2 * R * Rth);
            
            Stat = "REJECTED"; if M_RMS <= T_Nom && Temp_F <= 125, Stat = "ACCEPTED"; end
            Candidates = [Candidates; table(PN, T_Nom, M_RMS, Temp_F, row.Weight_g_, string(Stat), 'VariableNames', {'PN', 'T_Nom', 'M_RMS_Req', 'Temp_Final', 'Weight_g', 'Status'})];
        end
        
        % --- C. ΝΙΚΗΤΗΣ & ΛΗΨΗ STALL TORQUE ---
        Accepted = Candidates(Candidates.Status == "ACCEPTED", :);
        if isempty(Accepted)
            Winner_PN = "NONE"; Winner_Temp = 0; Winner_Power = 0; 
            Winner_Torque = 0; Winner_Stall = 0; Winner_Speed = 0; Winner_Family = "NONE";
            Status_Final = "CRITICAL";
        else
            Accepted = sortrows(Accepted, 'Weight_g', 'ascend');
            W_PN_val = Accepted.PN(1);
            Winner_PN = string(W_PN_val);
            Winner_Temp = Accepted.Temp_Final(1);
            
            idx = find(AllMotors.PartNumber == W_PN_val);
            
            % Μετατροπή των χαρακτηριστικών σε double για τη βάση
            Winner_Power = AllMotors.Power_W_(idx(1)); if iscell(Winner_Power), Winner_Power = cell2mat(Winner_Power); end
            Winner_Torque = AllMotors.Nom_Torque_mNm_(idx(1)); if iscell(Winner_Torque), Winner_Torque = cell2mat(Winner_Torque); end
            Winner_Stall = AllMotors.StallT_mNm_(idx(1)); if iscell(Winner_Stall), Winner_Stall = cell2mat(Winner_Stall); end
            Winner_Speed = AllMotors.No_loadRpm(idx(1)); if iscell(Winner_Speed), Winner_Speed = cell2mat(Winner_Speed); end
            Winner_Family = AllMotors.Family(idx(1)); if iscell(Winner_Family), Winner_Family = char(Winner_Family{1}); end
            
            Status_Final = "OPTIMAL";
        end
        fprintf('🏆 ΝΙΚΗΤΗΣ: PN %s (Stall Torque: %.1f mNm)\n', Winner_PN, Winner_Stall);

        % --- D. UPLOAD ---
        uID = datestr(now, 'HHMMSS'); 
        fName = sprintf('Report_L%d_%s.xlsx', lvl, uID);
        writetable(Candidates, fName);
        publicLink = upload_file_to_supabase(fName, fName);
        
       % --- E. DATABASE UPDATE (Προσθήκη Required Torque) ---
        ts = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
        
        % 1. Προσθήκη στο table (για sqlwrite)
        db_table = table(lvl, {char(Winner_PN)}, Winner_Power, Winner_Torque, Winner_Stall, M_RMS, Winner_Speed, {char(Winner_Family)}, Winner_Temp, {char(Status_Final)}, {char(publicLink)}, {ts}, ...
            'VariableNames', {'weakness_level', 'selected_motor_pn', 'motor_power_w', 'motor_torque_mnm', 'motor_stall_torque_mnm', 'required_torque_mnm', 'motor_speed_rpm', 'motor_family', 'motor_safety_temp_c', 'status', 'Download_Excel_Report', 'timestamp'});
        
        try
            sqlwrite(conn, 'simulation_results', db_table); 
            fprintf('✅ Database Updated with Required Torque!\n');
        catch
            % 2. Προσθήκη στην Direct SQL (αν αποτύχει η sqlwrite)
            fprintf('💡 Switching to Direct SQL for Full Update...\n');
            sql_query = sprintf(['INSERT INTO simulation_results ' ...
                '(weakness_level, selected_motor_pn, motor_power_w, motor_torque_mnm, motor_stall_torque_mnm, required_torque_mnm, motor_speed_rpm, motor_family, motor_safety_temp_c, status, "Download_Excel_Report", timestamp) ' ...
                'VALUES (%d, ''%s'', %.2f, %.2f, %.2f, %.2f, %.2f, ''%s'', %.2f, ''%s'', ''%s'', ''%s'')'], ...
                lvl, char(Winner_PN), Winner_Power, Winner_Torque, Winner_Stall, M_RMS, Winner_Speed, char(Winner_Family), Winner_Temp, char(Status_Final), char(publicLink), ts);
            exec(conn, sql_query);
            fprintf('✅ Database Updated (Direct SQL - Including Required Torque)!\n');
        end
        
    catch ME
        fprintf('❌ ΣΦΑΛΜΑ στο Loop %d: %s\n', lvl, ME.message);
    end
end
fprintf('\n🎉 ΤΕΛΟΣ! ΟΛΑ ΤΑ ΠΕΔΙΑ ΕΙΝΑΙ ΓΕΜΑΤΑ.\n');