%% Script: Plot_Figure_21_CMC.m
% Σκοπός: Δημιουργία της Εικόνας 21 (Vastus Medialis Activation)
% Σύγκριση Normal vs Weak80 (CMC Results)

clear; clc; close all;

% Ρυθμίσεις
muscle_to_plot = 'vas_med_r'; % Ο μυς που θέλουμε
title_str = 'Right Vastus Medialis Activation (CMC)';
rms_window = 15; % Λίγο μεγαλύτερο παράθυρο για να είναι πιο λείες οι γραμμές

% --- ΦΟΡΤΩΣΗ ΑΡΧΕΙΩΝ ---
fprintf('--- ΕΠΙΛΟΓΗ ΑΡΧΕΙΩΝ CMC ---\n');

% 1. NORMAL
fprintf('ΒΗΜΑ 1: Επίλεξε το αρχείο STATES για το NORMAL...\n');
fprintf('path: ...\\Results\\Normal\\subject01_CMC_states.sto\n');
[file1, path1] = uigetfile('*.sto', 'Επίλεξε NORMAL _states.sto');
if file1 == 0, error('Δεν επιλέχθηκε Normal'); end

% 2. WEAK 80
fprintf('ΒΗΜΑ 2: Επίλεξε το αρχείο STATES για το WEAK 80...\n');
fprintf('path: ...\\subject01_walk1_weak80_CMC\\subject01_walk1_weak80_CMC_states.sto\n');
[file2, path2] = uigetfile('*.sto', 'Επίλεξε WEAK80 _states.sto');
if file2 == 0, error('Δεν επιλέχθηκε Weak80'); end

% Φόρτωση
import org.opensim.modeling.*
files = {fullfile(path1, file1), fullfile(path2, file2)};
labels = {'Normal', 'Weak 80%'};
colors = {'b', 'r'}; % Μπλε = Normal, Κόκκινο = Weak
line_styles = {'-', '-'};

% Δημιουργία Γραφήματος
figure('Name', 'Figure 21: Vas Med Comparison', 'Color', 'w', 'Position', [100 100 800 500]);
hold on; grid on;

% --- LOOP ΓΙΑ ΤΑ 2 ΑΡΧΕΙΑ ---
for i = 1:2
    try
        % Ανάγνωση
        table = TimeSeriesTable(files{i});
        
        % Εύρεση στήλης (ψάχνουμε activation του vas_med_r)
        colLabels = table.getColumnLabels();
        targetCol = '';
        for k = 0:colLabels.size()-1
            lbl = char(colLabels.get(k));
            if contains(lbl, muscle_to_plot) && contains(lbl, 'activation')
                targetCol = lbl;
                break;
            end
        end
        
        if isempty(targetCol)
            error('Δεν βρέθηκε ο μυς %s στο αρχείο %d', muscle_to_plot, i);
        end
        
        % Δεδομένα
        timeVec = table.getIndependentColumn();
        dataVec = table.getDependentColumn(targetCol).getAsMat();
        
        % Χρόνος σε MATLAB vector
        t = zeros(timeVec.size(),1);
        for j=0:timeVec.size()-1, t(j+1) = timeVec.get(j); end
        
        % --- Time Normalization (0-100% Gait Cycle) ---
        % Υποθέτουμε ότι το αρχείο είναι ένας κύκλος
        percent_gait = (t - t(1)) / (t(end) - t(1)) * 100;
        
        % Interpolation (0 έως 100 με βήμα 1)
        xq = 0:1:100;
        yq = interp1(percent_gait, dataVec, xq, 'pchip');
        
        % --- Φιλτράρισμα RMS (για να μοιάζει με το κείμενο) ---
        y_smooth = smoothdata(yq, 'movmean', rms_window);
        
        % Plot
        p(i) = plot(xq, y_smooth, 'Color', colors{i}, 'LineWidth', 3, 'LineStyle', line_styles{i});
        
    catch ME
        fprintf('Error file %d: %s\n', i, ME.message);
    end
end

% --- ΜΟΡΦΟΠΟΙΗΣΗ (ΓΙΑ ΝΑ ΔΕΝΕΙ ΜΕ ΤΟ ΚΕΙΜΕΝΟ ΣΟΥ) ---
title('Εικόνα 21: Ενεργοποίηση Vastus Medialis (CMC)', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('Κύκλος Βάδισης (%)', 'FontSize', 12);
ylabel('Ενεργοποίηση (0-1)', 'FontSize', 12);
legend(p, labels, 'Location', 'NorthWest', 'FontSize', 12);
axis([0 100 0 0.8]); % Κόβουμε το ύψος στο 0.8 για να φαίνεται ωραία η διαφορά

% Προσθήκη οριζόντιας γραμμής για να δείξεις το "χαμηλό" επίπεδο του Weak
yline(0.12, '--k', 'Low Threshold (Weak)', 'LabelHorizontalAlignment', 'right');

fprintf('Η Εικόνα 21 είναι έτοιμη!\n');