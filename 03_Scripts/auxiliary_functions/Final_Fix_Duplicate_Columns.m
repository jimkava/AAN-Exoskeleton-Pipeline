%% Script: Final_Fix_Duplicate_Columns.m
% Σκοπός: Δημιουργεί το Animation αποφεύγοντας τις διπλές στήλες (Duplicates).

clear; clc;

% 1. ΕΠΙΛΟΓΗ ΦΑΚΕΛΩΝ
fprintf('ΒΗΜΑ 1: Επίλεξε τον φάκελο "Adaptive_Curve_Final"...\n');
resultsBaseDir = uigetdir(pwd, 'Select Adaptive_Curve_Final');
if resultsBaseDir == 0, error('Δεν επιλέχθηκε φάκελος.'); end

fprintf('ΒΗΜΑ 2: Επίλεξε το αρχείο "subject01_walk1_ik.mot"...\n');
[kinFile, kinPath] = uigetfile({'*.mot;*.sto'}, 'Select subject01_walk1_ik.mot');
if kinFile == 0, error('Δεν επιλέχθηκε αρχείο κίνησης.'); end
kinematicsFullPath = fullfile(kinPath, kinFile);

fprintf('Φόρτωση Κινηματικής...\n');
import org.opensim.modeling.*

% Φόρτωση Κινηματικής (IK)
kinTable = TimeSeriesTable(kinematicsFullPath);

weakness_percents = 10:10:80; 

for i = 1:length(weakness_percents)
    w = weakness_percents(i);
    folderName = sprintf('Weakness_%d', w);
    forceFile = fullfile(resultsBaseDir, folderName, 'Result.sto');
    outputFile = fullfile(resultsBaseDir, folderName, sprintf('Final_Video_%d.mot', w));
    
    if ~isfile(forceFile)
        fprintf('Skipping %d%% (Δεν βρέθηκε)\n', w);
        continue; 
    end
    
    try
        % Φόρτωση Δυνάμεων
        forceTable = TimeSeriesTable(forceFile);
        
        % 1. Δημιουργία ΝΕΟΥ Πίνακα με βάση την ΚΙΝΗΣΗ (Γωνίες πρώτα)
        finalTable = kinTable.clone();
        
        % 2. Προετοιμασία Χρόνων
        kinTimes = kinTable.getIndependentColumn(); 
        kTimesMat = zeros(kinTimes.size(),1);
        for t=0:kinTimes.size()-1, kTimesMat(t+1) = kinTimes.get(t); end
        
        forceTimes = forceTable.getIndependentColumn();
        fTimesMat = zeros(forceTimes.size(),1);
        for t=0:forceTimes.size()-1, fTimesMat(t+1) = forceTimes.get(t); end
        
        % 3. Προσθήκη Μυών (με έλεγχο για Duplicates)
        oldLabels = forceTable.getColumnLabels();
        
        for c = 0:oldLabels.size()-1
            oldName = char(oldLabels.get(c));
            
            % Καθαρισμός ονόματος
            if contains(oldName, '/activation'), parts = split(oldName, '/'); name = parts{end-1};
            elseif contains(oldName, '/value'), parts = split(oldName, '/'); name = parts{end-1};
            elseif contains(oldName, '/'), parts = split(oldName, '/'); name = parts{end};
            else, name = oldName; end
            
            % --- Ο ΣΩΤΗΡΙΟΣ ΕΛΕΓΧΟΣ ---
            % Αν το όνομα υπάρχει ήδη (είτε από την Κινηματική, είτε από προηγούμενο loop), το αγνοούμε.
            if finalTable.hasColumn(name)
                continue; 
            end
            % --------------------------
            
            % Παίρνουμε τα δεδομένα και κάνουμε Interpolation
            colData = forceTable.getDependentColumn(oldName).getAsMat();
            newData = interp1(fTimesMat, colData, kTimesMat, 'linear', 'extrap');
            
            % Δημιουργία στήλης
            newColVector = Vector(length(newData), 0.0);
            for n=1:length(newData), newColVector.set(n-1, newData(n)); end
            
            % Προσθήκη στο τέλος
            finalTable.appendColumn(name, newColVector);
        end
        
        % Εγγραφή
        STOFileAdapter.write(finalTable, outputFile);
        fprintf('[OK] Final_Video_%d.mot δημιουργήθηκε επιτυχώς.\n', w);
        
    catch ME
        fprintf('[ERROR] %d%%: %s\n', w, ME.message);
    end
end

fprintf('\n--- ΤΕΛΟΣ ---\n');
fprintf('Τώρα δεν υπάρχουν διπλές στήλες. Φόρτωσε το αρχείο στο OpenSim!\n');