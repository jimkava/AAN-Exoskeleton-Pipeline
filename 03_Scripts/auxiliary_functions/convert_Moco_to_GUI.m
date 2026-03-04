%% Script: convert_Moco_to_GUI_Named.m
% Σκοπός: Μετατρέπει τα αποτελέσματα σε .mot με ΞΕΧΩΡΙΣΤΑ ονόματα (π.χ. _10, _20).

clear; clc;

% 1. ΕΠΙΛΟΓΗ ΦΑΚΕΛΟΥ
fprintf('Επίλεξε τον φάκελο "Adaptive_Curve_Final"...\n');
resultsBaseDir = uigetdir(pwd, 'Select Adaptive_Curve_Final');

if resultsBaseDir == 0
    error('Δεν επιλέχθηκε φάκελος.');
end

weakness_percents = 10:10:80; 

% Φόρτωση βιβλιοθηκών OpenSim
import org.opensim.modeling.*

counter = 0;

% 2. LOOP ΓΙΑ ΚΑΘΕ ΠΟΣΟΣΤΟ
for i = 1:length(weakness_percents)
    w = weakness_percents(i);
    folderName = sprintf('Weakness_%d', w);
    
    inputFile = fullfile(resultsBaseDir, folderName, 'Result.sto');
    
    % --- ΕΔΩ ΕΙΝΑΙ Η ΑΛΛΑΓΗ ---
    % Το νέο όνομα περιέχει το νούμερο (π.χ. Animation_GUI_80.mot)
    newFileName = sprintf('Animation_GUI_%d.mot', w);
    outputFile = fullfile(resultsBaseDir, folderName, newFileName);
    
    if ~isfile(inputFile)
        fprintf('Skipping %s (Δεν βρέθηκε το Result.sto)\n', folderName);
        continue;
    end
    
    try
        % Φόρτωση
        table = TimeSeriesTable(inputFile);
        
        % Καθαρισμός Ονομάτων (Labels)
        oldLabels = table.getColumnLabels(); 
        newLabels = StdVectorString();
        
        for k = 0:oldLabels.size()-1
            oldName = char(oldLabels.get(k));
            
            % Λογική καθαρισμού: Κρατάμε το τελευταίο κομμάτι του path
            if contains(oldName, '/')
                parts = split(oldName, '/');
                cleanName = parts{end}; 
                
                % Αν είναι 'value', παίρνουμε το προηγούμενο (π.χ. knee_angle_r)
                if strcmp(cleanName, 'value')
                    cleanName = parts{end-1};
                elseif strcmp(cleanName, 'speed')
                    cleanName = [parts{end-1} '_u']; % Ταχύτητες
                end
            else
                cleanName = oldName;
            end
            
            newLabels.add(cleanName);
        end
        
        table.setColumnLabels(newLabels);
        
        % Εγγραφή
        STOFileAdapter.write(table, outputFile);
        
        fprintf('[OK] Δημιουργήθηκε: %s\n', newFileName);
        counter = counter + 1;
        
    catch ME
        fprintf('[ERROR] Σφάλμα στο %d%%: %s\n', w, ME.message);
    end
end

fprintf('\n--- ΟΛΟΚΛΗΡΩΘΗΚΕ ---\n');
fprintf('Δημιουργήθηκαν %d αρχεία.\n', counter);
fprintf('Τώρα μπορείς να τα φορτώσεις στο OpenSim και να τα ξεχωρίζεις!\n');