%% Script: Correct_Order_Animation.m
% Σκοπός: Φτιάχνει το Animation βάζοντας ΠΡΩΤΑ τις Γωνίες (για να μην διαλύεται το μοντέλο)
% και ΜΕΤΑ τους Μύες/Εξωσκελετό (για να φαίνονται τα χρώματα).

clear; clc;

% 1. ΕΠΙΛΟΓΗ ΦΑΚΕΛΩΝ
fprintf('ΒΗΜΑ 1: Επίλεξε τον φάκελο "Adaptive_Curve_Final"...\n');
resultsBaseDir = uigetdir(pwd, 'Select Adaptive_Curve_Final');
if resultsBaseDir == 0, error('Δεν επιλέχθηκε φάκελος.'); end

fprintf('ΒΗΜΑ 2: Επίλεξε το αρχείο "subject01_walk1_ik.mot"...\n');
[kinFile, kinPath] = uigetfile({'*.mot;*.sto'}, 'Select subject01_walk1_ik.mot');
if kinFile == 0, error('Δεν επιλέχθηκε αρχείο κίνησης.'); end
kinematicsFullPath = fullfile(kinPath, kinFile);

fprintf('Φόρτωση...\n');
import org.opensim.modeling.*

% Φόρτωση Κινηματικής (IK)
kinTable = TimeSeriesTable(kinematicsFullPath);

weakness_percents = 10:10:80; 

for i = 1:length(weakness_percents)
    w = weakness_percents(i);
    folderName = sprintf('Weakness_%d', w);
    forceFile = fullfile(resultsBaseDir, folderName, 'Result.sto');
    outputFile = fullfile(resultsBaseDir, folderName, sprintf('Final_Video_%d.mot', w)); % Νέο όνομα
    
    if ~isfile(forceFile), continue; end
    
    try
        % Φόρτωση Δυνάμεων
        forceTable = TimeSeriesTable(forceFile);
        
        % 1. Δημιουργία ΝΕΟΥ Πίνακα βασισμένου στην ΚΙΝΗΣΗ (για να έχει τις γωνίες πρώτες)
        % Κλωνοποιούμε την κινηματική για να έχουμε τη σωστή δομή σκελετού
        finalTable = kinTable.clone();
        
        % 2. Προετοιμασία Δυνάμεων (Resampling)
        % Πρέπει να φέρουμε τις δυνάμεις στον χρόνο της κινηματικής
        kinTimes = kinTable.getIndependentColumn(); % Java vector
        
        % Μετατροπή χρόνων σε Matlab array
        kTimesMat = zeros(kinTimes.size(),1);
        for t=0:kinTimes.size()-1, kTimesMat(t+1) = kinTimes.get(t); end
        
        % Χρόνοι δυνάμεων
        forceTimes = forceTable.getIndependentColumn();
        fTimesMat = zeros(forceTimes.size(),1);
        for t=0:forceTimes.size()-1, fTimesMat(t+1) = forceTimes.get(t); end
        
        % 3. Καθαρισμός και Προσθήκη Δυνάμεων στο ΤΕΛΟΣ του πίνακα
        oldLabels = forceTable.getColumnLabels();
        
        for c = 0:oldLabels.size()-1
            oldName = char(oldLabels.get(c));
            
            % Καθαρισμός ονόματος
            if contains(oldName, '/activation'), parts = split(oldName, '/'); name = parts{end-1};
            elseif contains(oldName, '/value'), parts = split(oldName, '/'); name = parts{end-1};
            elseif contains(oldName, '/'), parts = split(oldName, '/'); name = parts{end};
            else, name = oldName; end
            
            % Παίρνουμε τα δεδομένα της δύναμης
            colData = forceTable.getDependentColumn(oldName).getAsMat();
            
            % Interpolation για να ταιριάξει με τους χρόνους της κίνησης
            newData = interp1(fTimesMat, colData, kTimesMat, 'linear', 'extrap');
            
            % Δημιουργία στήλης OpenSim
            newColVector = Vector(length(newData), 0.0);
            for n=1:length(newData), newColVector.set(n-1, newData(n)); end
            
            % ΠΡΟΣΘΗΚΗ ΣΤΟ ΤΕΛΟΣ (Append)
            % Επειδή το finalTable έχει ήδη τις γωνίες, οι δυνάμεις μπαίνουν μετά.
            % Αυτό είναι το κλειδί!
            finalTable.appendColumn(name, newColVector);
        end
        
        % Εγγραφή
        STOFileAdapter.write(finalTable, outputFile);
        fprintf('[OK] Final_Video_%d.mot\n', w);
        
    catch ME
        fprintf('[ERROR] %d%%: %s\n', w, ME.message);
    end
end

fprintf('\n--- ΕΤΟΙΜΟ ---\n');
fprintf('Φόρτωσε το αρχείο "Final_Video_80.mot". Θα παίζει τέλεια!\n');