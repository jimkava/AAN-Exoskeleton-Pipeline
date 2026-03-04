% ----------------------------------------------------------------------- %
%   PROJECT: DropFoot_GaitRehab_FESRobex
%   SCRIPT:  run_Phase4_PlotResults.m
%   ΣΚΟΠΟΣ:  Συγκέντρωση αποτελεσμάτων και δημιουργία καμπύλης "Assist-as-Needed"
% ----------------------------------------------------------------------- %

clear; clc; close all;
import org.opensim.modeling.*;

%% 1. ΟΡΙΣΜΟΣ PATHS
ROOT = 'C:\OpenSim 4.5\sdk\Models\DropFoot_GaitRehab_FESRobex\Gaithab_FesRobex_project_22.12.25\MATLAB\Open-Loop Model\Moco_Phase4_Adult_Normal';
resultsDir = fullfile(ROOT, '04_Results');

% Ποσοστά αδυναμίας που τρέξαμε (0 = Baseline, 10-80 = Loop)
weaknessLevels = [0, 10, 20, 30, 40, 50, 60, 70, 80];
maxTorques = zeros(size(weaknessLevels)); % Εδώ θα αποθηκεύσουμε τις μέγιστες ροπές

fprintf('--- ΣΥΓΚΕΝΤΡΩΣΗ ΑΠΟΤΕΛΕΣΜΑΤΩΝ ---\n');

%% 2. LOOP ΑΝΑΓΝΩΣΗΣ ΑΡΧΕΙΩΝ
for i = 1:length(weaknessLevels)
    wk = weaknessLevels(i);
    
    % Βρίσκουμε το σωστό φάκελο και αρχείο
    if wk == 0
        folderName = 'Baseline_0_Weakness';
        fileName = 'Baseline_Result.sto';
    else
        folderName = sprintf('Weakness_%d', wk);
        fileName = sprintf('Result_Weakness_%d.sto', wk);
    end
    
    fullFilePath = fullfile(resultsDir, folderName, fileName);
    
    % Έλεγχος αν υπάρχει το αρχείο
    if ~exist(fullFilePath, 'file')
        fprintf('⚠️  WARNING: Δεν βρέθηκε το αρχείο για %d%% αδυναμία (%s)\n', wk, fileName);
        maxTorques(i) = NaN; % Βάζουμε NaN για να μην χαλάσει το γράφημα
        continue;
    end
    
    % Φόρτωση του πίνακα αποτελεσμάτων
    try
        data = TimeSeriesTable(fullFilePath);
        labels = data.getColumnLabels();
        
        % Ψάχνουμε τη στήλη του Εξωσκελετού (γιατί το όνομα μπορεί να διαφέρει λίγο)
        exoColName = '';
        for j = 0:labels.size()-1
            name = char(labels.get(j));
            if contains(name, 'knee_exo_device')
                exoColName = name;
                break;
            end
        end
        
        if isempty(exoColName)
            fprintf('❌ Error: Δεν βρέθηκε στήλη εξωσκελετού στο %d%%\n', wk);
            maxTorques(i) = NaN;
        else
            % Παίρνουμε τα δεδομένα (Control Signal)
            exoControl = data.getDependentColumn(exoColName).getAsMat();
            
            % Μετατροπή σε Ροπή (Control * OptimalForce 100)
            % Παίρνουμε την ΑΠΟΛΥΤΗ ΜΕΓΙΣΤΗ τιμή (γιατί μπορεί να είναι αρνητική)
            maxTorque = max(abs(exoControl)) * 100; 
            
            maxTorques(i) = maxTorque;
            fprintf('✅ %d%% Weakness -> Max Torque: %.2f Nm\n', wk, maxTorque);
        end
        
    catch ME
        fprintf('❌ Error reading file for %d%%: %s\n', wk, ME.message);
        maxTorques(i) = NaN;
    end
end

%% 3. ΔΗΜΙΟΥΡΓΙΑ ΓΡΑΦΗΜΑΤΟΣ (DEMAND ANALYSIS)
figure('Name', 'Assist-as-Needed Curve', 'Color', 'w', 'Position', [100 100 800 600]);

% Plot με γραμμή και τελείες
plot(weaknessLevels, maxTorques, '-o', ...
    'LineWidth', 3, ...
    'MarkerSize', 8, ...
    'MarkerFaceColor', 'r', ...
    'Color', 'b');

grid on;
title('Assist-as-Needed: Απαίτηση Εξωσκελετού ανάλογα με την Αδυναμία', 'FontSize', 14);
xlabel('Ποσοστό Μυϊκής Αδυναμίας (%)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Αναγκαία Ροπή Εξωσκελετού (Nm)', 'FontSize', 12, 'FontWeight', 'bold');

% Όρια αξόνων για να φαίνεται ωραίο
xlim([0 90]);
ylim([0 max(maxTorques)*1.2]); % Λίγο αέρα από πάνω

% Προσθήκη ετικετών στις τιμές
for i = 1:length(weaknessLevels)
    if ~isnan(maxTorques(i))
        text(weaknessLevels(i), maxTorques(i) + 1, sprintf('%.1f Nm', maxTorques(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 10);
    end
end

fprintf('\nΓράφημα δημιουργήθηκε! Ελέγξτε το Figure.\n');