%% Script: Temporal Analysis for Gait2392 (Auto-Scaling & Debug)
% Αυτό το script διαβάζει τα controls και τα μετατρέπει σε ροπές.

clear; clc; close all;

% 1. ΕΠΙΛΟΓΗ ΦΑΚΕΛΟΥ
fprintf('----------------------------------------------------------\n');
fprintf('ΒΗΜΑ 1: Θα ανοίξει παράθυρο. Επίλεξε τον φάκελο "Adaptive_Curve_Final"\n');
fprintf('----------------------------------------------------------\n');
pause(1); % Μικρή παύση για να προλάβεις να διαβάσεις

resultsBaseDir = uigetdir(pwd, 'Επίλεξε τον φάκελο Adaptive_Curve_Final');

if resultsBaseDir == 0
    error('Δεν επιλέχθηκε φάκελος. Το πρόγραμμα τερματίζεται.');
end

fprintf('Επιλέξατε: %s\n', resultsBaseDir);

weakness_percents = 10:10:80; 
colors = jet(length(weakness_percents)); 
data_store = struct();
files_found = 0;

% 2. ΦΟΡΤΩΣΗ ΚΑΙ ΕΛΕΓΧΟΣ ΔΕΔΟΜΕΝΩΝ
fprintf('\nΒΗΜΑ 2: Φόρτωση αρχείων...\n');

for i = 1:length(weakness_percents)
    w = weakness_percents(i);
    folderName = sprintf('Weakness_%d', w);
    filePath = fullfile(resultsBaseDir, folderName, 'Result.sto');
    
    if ~isfile(filePath)
        fprintf('  [x] Το αρχείο λείπει: %s\n', folderName);
        continue;
    end
    
    % Φόρτωση
    try
        simData = importdata(filePath);
        if isstruct(simData)
            headers = simData.textdata(end,:); 
            data = simData.data;
        else
            % Fallback για απλή ανάγνωση
            fid = fopen(filePath);
            for k=1:20, line=fgetl(fid); if contains(line, 'time'), headers=split(line); break; end; end
            fclose(fid);
            data = simData; 
        end
    catch
        fprintf('  [!] Σφάλμα ανάγνωσης στο %s\n', folderName);
        continue;
    end
    
    files_found = files_found + 1;
    
    % Χρόνος
    time_col = find(contains(headers, 'time'), 1);
    data_store(i).time = data(:, time_col);
    
    % Εύρεση στήλης Exo (Συνήθως 186)
    idx_exo = find(contains(headers, 'knee_exo_device'), 1);
    if isempty(idx_exo), idx_exo = 186; end % Fallback
    
    if idx_exo > size(data, 2)
        idx_exo = size(data, 2); % Safety fallback
    end
    
    % Αποθήκευση RAW δεδομένων
    raw_sig = data(:, idx_exo);
    data_store(i).exo_raw = raw_sig;
    data_store(i).label = sprintf('%d%%', w);
    fprintf('  [v] Φορτώθηκε Weakness %d%% (Max Raw Value: %.2f)\n', w, max(abs(raw_sig)));
end

if files_found == 0
    error('Δεν βρέθηκαν αρχεία Result.sto! Έλεγξε τον φάκελο που επέλεξες.');
end

% 3. ΥΠΟΛΟΓΙΣΜΟΣ SCALING FACTOR (ΚΛΕΙΔΙ ΓΙΑ ΣΩΣΤΑ ΓΡΑΦΗΜΑΤΑ)
% Ξέρουμε από την καμπύλη σου ότι στο 80% η ροπή είναι ~40 Nm.
% Αν το raw value είναι ~1.0, πρέπει να πολλαπλασιάσουμε με 40.
idx_80 = length(data_store);
if isempty(data_store(idx_80).exo_raw)
    % Αν λείπει το 80%, βρίσκουμε το τελευταίο διαθέσιμο
    valid_idx = find(~cellfun(@isempty, {data_store.exo_raw}));
    idx_ref = valid_idx(end);
else
    idx_ref = idx_80;
end

max_raw_val = max(abs(data_store(idx_ref).exo_raw));
TARGET_MAX_TORQUE = 40.0; % Nm (από το προηγούμενο γράφημά σου)

if max_raw_val < 5 % Αν οι τιμές είναι μικρές (π.χ. 0-1), θέλουν scaling
    SCALING_FACTOR = TARGET_MAX_TORQUE / max_raw_val;
    fprintf('\nINFO: Τα δεδομένα φαίνονται να είναι Controls (0-1). Εφαρμογή Scaling x%.1f\n', SCALING_FACTOR);
else
    SCALING_FACTOR = 1; % Είναι ήδη ροπές
    fprintf('\nINFO: Τα δεδομένα είναι ήδη σε Nm.\n');
end

% 4. ΔΗΜΙΟΥΡΓΙΑ ΓΡΑΦΗΜΑΤΩΝ
fprintf('\nΒΗΜΑ 3: Δημιουργία Διαγραμμάτων...\n');

% Κατασκευή Καμπύλης Demand (από το 80% scaled)
ref_signal = abs(data_store(idx_ref).exo_raw) * SCALING_FACTOR;
demand_curve = movmean(ref_signal, 20); % Smooth
demand_curve = demand_curve * 1.1; % Margin
time_vec = data_store(idx_ref).time;

% --- FIGURE 1: DEMAND vs CAPACITY ---
figure('Name', 'Bio_Capacity_vs_Demand', 'Color', 'w', 'Position', [100 100 900 500]);
hold on; grid on;

area(time_vec, demand_curve, 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'k', 'LineWidth', 2, 'DisplayName', 'Total Demand');

for i = 1:length(weakness_percents)
    if isempty(data_store(i).exo_raw), continue; end
    
    % Επεξεργασία σήματος
    raw = abs(data_store(i).exo_raw);
    torque = raw * SCALING_FACTOR;
    torque = movmean(torque, 20); % Εξομάλυνση
    
    % Συγχρονισμός χρόνου (αν διαφέρει λίγο)
    if length(torque) ~= length(demand_curve)
        torque = interp1(data_store(i).time, torque, time_vec, 'linear', 'extrap');
    end
    
    % Bio = Demand - Exo
    bio = demand_curve - torque;
    bio(bio < 0) = 0;
    
    plot(time_vec, bio, 'Color', colors(i,:), 'LineWidth', 2, ...
        'DisplayName', sprintf('Bio (%d%%)', weakness_percents(i)));
end

title('Demand vs Bio Capacity (Stance & Swing)', 'FontSize', 12);
xlabel('Time (s)'); ylabel('Torque (Nm)');
xlim([time_vec(1) time_vec(end)]);
legend('Location', 'bestoutside');

% --- FIGURE 2: EXO ASSISTANCE ---
figure('Name', 'Exo_Assistance', 'Color', 'w', 'Position', [150 150 900 500]);
hold on; grid on;

for i = 1:length(weakness_percents)
    if isempty(data_store(i).exo_raw), continue; end
    
    raw = abs(data_store(i).exo_raw);
    torque = raw * SCALING_FACTOR;
    torque = movmean(torque, 20);
    
    lw = 1.5;
    if weakness_percents(i) == 80, c = 'r'; lw = 3; else, c = colors(i,:); end
    
    plot(data_store(i).time, torque, 'Color', c, 'LineWidth', lw, ...
        'DisplayName', sprintf('Exo (%d%%)', weakness_percents(i)));
end

title('Exoskeleton Assistance Profile', 'FontSize', 12);
xlabel('Time (s)'); ylabel('Torque (Nm)');
xlim([time_vec(1) time_vec(end)]);
legend('Location', 'bestoutside');

fprintf('Ολοκληρώθηκε! Ελέγξτε τις εικόνες.\n');