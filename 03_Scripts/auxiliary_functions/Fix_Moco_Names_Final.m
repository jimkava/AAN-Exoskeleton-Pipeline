%% Script: Fix_Moco_Names_Final.m
% Σκοπός: Διορθώνει τα ονόματα (headers) ώστε να μην βγαίνουν ως "activation" ή "value".

clear; clc;

% 1. ΕΠΙΛΟΓΗ ΦΑΚΕΛΟΥ
fprintf('Επίλεξε τον φάκελο "Adaptive_Curve_Final"...\n');
resultsBaseDir = uigetdir(pwd, 'Select Adaptive_Curve_Final');

if resultsBaseDir == 0
    error('Δεν επιλέχθηκε φάκελος.');
end

weakness_percents = 10:10:80; 
import org.opensim.modeling.*

counter = 0;

% 2. LOOP ΓΙΑ ΚΑΘΕ ΠΟΣΟΣΤΟ
for i = 1:length(weakness_percents)
    w = weakness_percents(i);
    folderName = sprintf('Weakness_%d', w);
    
    inputFile = fullfile(resultsBaseDir, folderName, 'Result.sto');
    newFileName = sprintf('Animation_GUI_%d.mot', w);
    outputFile = fullfile(resultsBaseDir, folderName, newFileName);
    
    if ~isfile(inputFile)
        fprintf('Skipping %s (Δεν βρέθηκε)\n', folderName);
        continue;
    end
    
    try
        % Φόρτωση πίνακα
        table = TimeSeriesTable(inputFile);
        oldLabels = table.getColumnLabels(); 
        newLabels = StdVectorString();
        
        % --- Η ΚΡΙΣΙΜΗ ΔΙΟΡΘΩΣΗ ---
        for k = 0:oldLabels.size()-1
            oldName = char(oldLabels.get(k));
            
            % Περίπτωση 1: ΚΙΝΗΣΗ (Coordinates)
            % Π.χ. /jointset/walker_knee_r/knee_angle_r/value -> knee_angle_r
            if contains(oldName, '/value')
                parts = split(oldName, '/');
                cleanName = parts{end-1}; % Παίρνουμε το προ-τελευταίο!
                
            % Περίπτωση 2: ΤΑΧΥΤΗΤΑ (Speeds)
            % Π.χ. .../knee_angle_r/speed -> knee_angle_r_u
            elseif contains(oldName, '/speed')
                parts = split(oldName, '/');
                cleanName = [parts{end-1} '_u'];
                
            % Περίπτωση 3: ΜΥΕΣ (Activations)
            % Π.χ. /forceset/vas_med_r/activation -> vas_med_r
            elseif contains(oldName, '/activation')
                parts = split(oldName, '/');
                cleanName = parts{end-1}; % Παίρνουμε το όνομα του μυός!
                
            % Περίπτωση 4: ΕΞΩΣΚΕΛΕΤΟΣ / Controls
            % Αν δεν έχει κατάληξη, παίρνουμε το τελευταίο κομμάτι του path
            elseif contains(oldName, '/')
                parts = split(oldName, '/');
                cleanName = parts{end};
            else
                cleanName = oldName;
            end
            
            newLabels.add(cleanName);
        end
        % ---------------------------
        
        table.setColumnLabels(newLabels);
        STOFileAdapter.write(table, outputFile);
        
        fprintf('[OK] %s: Διορθώθηκαν τα ονόματα.\n', newFileName);
        counter = counter + 1;
        
    catch ME
        fprintf('[ERROR] %d%%: %s\n', w, ME.message);
    end
end

fprintf('\n--- ΟΛΟΚΛΗΡΩΘΗΚΕ ---\n');
fprintf('Τώρα τα αρχεία Animation_GUI_xx.mot θα έχουν σωστά ονόματα (π.χ. knee_angle_r).\n');