%% Script: Compare_CMC_Normal_vs_Weak80.m
% Σκοπός: Σύγκριση CMC αποτελεσμάτων (Normal vs Weak80) για τον Vastus Medialis.
% ΠΡΟΣΟΧΗ: Επιλέγουμε τα αρχεία "_states.sto" ή "_controls.sto" (ΟΧΙ Kinematics!)

clear; clc; close all;

% Ρυθμίσεις Φίλτρου
rms_window = 10; 
muscle_name_search = 'vas_med_r'; % Ο μυς που ψάχνουμε

% --- 1. ΦΟΡΤΩΣΗ NORMAL ---
fprintf('ΒΗΜΑ 1: Επίλεξε το αρχείο STATES για το NORMAL...\n');
fprintf('(Συνήθως: ...\\Results\\Normal\\subject01_CMC_states.sto)\n');
[file1, path1] = uigetfile('*.sto', 'Επίλεξε NORMAL _states.sto');
if file1 == 0, error('Δεν επιλέχθηκε αρχείο Normal'); end

% --- 2. ΦΟΡΤΩΣΗ WEAK 80 ---
fprintf('ΒΗΜΑ 2: Επίλεξε το αρχείο STATES για το WEAK 80...\n');
fprintf('(Συνήθως: ...\\CMC_weakQuad\\...\\subject01_walk1_weak80_CMC_states.sto)\n');
[file2, path2] = uigetfile('*.sto', 'Επίλεξε WEAK80 _states.sto');
if file2 == 0, error('Δεν επιλέχθηκε αρχείο Weak80'); end

% Φόρτωση βιβλιοθηκών OpenSim
import org.opensim.modeling.*

% Λίστα αρχείων για Loop
files = {fullfile(path1, file1), fullfile(path2, file2)};
labels_plot = {'Normal', 'Weak 80% (CMC)'};
colors = {'b', 'r'}; % Μπλε για Normal, Κόκκινο για Weak

figure('Name', 'CMC Comparison: Vastus Medialis', 'Color', 'w');
hold on; grid on;

for i = 1:2
    try
        % Ανάγνωση αρχείου
        table = TimeSeriesTable(files{i});
        
        % Εύρεση στήλης μυός
        colLabels = table.getColumnLabels();
        targetCol = '';
        
        for k = 0:colLabels.size()-1
            lbl = char(colLabels.get(k));
            % Ψάχνουμε κάτι που να έχει "vas_med_r" ΚΑΙ "activation"
            if contains(lbl, muscle_name_search) && contains(lbl, 'activation')
                targetCol = lbl;
                break;
            end
        end
        
        if isempty(targetCol)
            error('Δεν βρέθηκε activation για τον μυ %s στο αρχείο %d', muscle_name_search, i);
        end
        
        % Λήψη Δεδομένων
        timeVec = table.getIndependentColumn();
        dataVec = table.getDependentColumn(targetCol).getAsMat();
        
        % Μετατροπή χρόνου σε MATLAB vector
        t = zeros(timeVec.size(),1);
        for j=0:timeVec.size()-1, t(j+1) = timeVec.get(j); end
        
        % --- Time Normalization (0-100%) ---
        percent_gait = (t - t(1)) / (t(end) - t(1)) * 100;
        
        % Interpolation για ομαλότητα
        xq = 0:0.5:100;
        yq = interp1(percent_gait, dataVec, xq, 'pchip');
        
        % --- RMS Filtering ---
        y_rms = sqrt(movmean(yq.^2, rms_window));
        
        % Plot
        plot(xq, y_rms, 'Color', colors{i}, 'LineWidth', 2.5, 'DisplayName', labels_plot{i});
        
    catch ME
        fprintf('Σφάλμα στο αρχείο %d: %s\n', i, ME.message);
    end
end

% Μορφοποίηση
title('Ενεργοποίηση Vastus Medialis (CMC)', 'FontSize', 14);
xlabel('% Gait Cycle');
ylabel('Activation (0-1)');
legend('Location', 'Best');
ylim([0 1]);