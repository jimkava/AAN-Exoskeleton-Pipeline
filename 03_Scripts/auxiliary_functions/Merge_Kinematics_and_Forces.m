%% Script: Merge_Kinematics_and_Forces.m
% Σκοπός: Ενώνει την Κίνηση (IK) με τις Δυνάμεις (Moco) για πλήρες Animation.

clear; clc;

% 1. ΕΠΙΛΟΓΗ ΦΑΚΕΛΟΥ ΑΠΟΤΕΛΕΣΜΑΤΩΝ (Adaptive_Curve_Final)
fprintf('ΒΗΜΑ 1: Επίλεξε τον φάκελο "Adaptive_Curve_Final"...\n');
resultsBaseDir = uigetdir(pwd, 'Select Adaptive_Curve_Final');
if resultsBaseDir == 0, error('Δεν επιλέχθηκε φάκελος.'); end

% 2. ΕΠΙΛΟΓΗ ΑΡΧΕΙΟΥ ΚΙΝΗΣΗΣ (subject01_walk1_ik.mot)
fprintf('ΒΗΜΑ 2: Επίλεξε το αρχείο "subject01_walk1_ik.mot"...\n');
[kinFile, kinPath] = uigetfile({'*.mot;*.sto'}, 'Select subject01_walk1_ik.mot');
if kinFile == 0, error('Δεν επιλέχθηκε αρχείο κίνησης.'); end
kinematicsFullPath = fullfile(kinPath, kinFile);

fprintf('Φόρτωση Κινηματικής... ');
import org.opensim.modeling.*

% Φόρτωση Κινηματικής (IK)
try
    kinTable = TimeSeriesTable(kinematicsFullPath);
    fprintf('[OK]\n');
catch
    error('Αδυναμία ανάγνωσης του αρχείου κίνησης.');
end

weakness_percents = 10:10:80; 

% 3. LOOP ΓΙΑ ΚΑΘΕ ΠΟΣΟΣΤΟ
fprintf('\nΈναρξη Συγχώνευσης...\n');

for i = 1:length(weakness_percents)
    w = weakness_percents(i);
    folderName = sprintf('Weakness_%d', w);
    
    % Αρχείο Δυνάμεων (Moco Result)
    forceFile = fullfile(resultsBaseDir, folderName, 'Result.sto');
    
    % Τελικό Αρχείο εξόδου
    outputFile = fullfile(resultsBaseDir, folderName, sprintf('Full_Animation_%d.mot', w));
    
    if ~isfile(forceFile)
        fprintf('Skipping %s (Δεν βρέθηκε Result.sto)\n', folderName);
        continue;
    end
    
    try
        % Φόρτωση Δυνάμεων
        forceTable = TimeSeriesTable(forceFile);
        
        % --- ΚΑΘΑΡΙΣΜΟΣ ΟΝΟΜΑΤΩΝ ΔΥΝΑΜΕΩΝ ---
        oldLabels = forceTable.getColumnLabels();
        newLabels = StdVectorString();
        for k = 0:oldLabels.size()-1
            oldName = char(oldLabels.get(k));
            % Λογική καθαρισμού
            if contains(oldName, '/activation'), parts = split(oldName, '/'); name = parts{end-1};
            elseif contains(oldName, '/value'), parts = split(oldName, '/'); name = parts{end-1};
            elseif contains(oldName, '/'), parts = split(oldName, '/'); name = parts{end};
            else, name = oldName; end
            newLabels.add(name);
        end
        forceTable.setColumnLabels(newLabels);
        
        % --- ΣΥΓΧΩΝΕΥΣΗ (INTERPOLATION) ---
        % Πρέπει να προσαρμόσουμε την κίνηση (IK) στους χρόνους του Moco Result
        
        % Χρόνοι του Moco Result (Στόχος)
        mocoTimesVec = forceTable.getIndependentColumn(); 
        numMocoPoints = mocoTimesVec.size();
        mocoTimes = zeros(numMocoPoints, 1);
        for t=1:numMocoPoints, mocoTimes(t) = mocoTimesVec.get(t-1); end
        
        % Χρόνοι του IK (Πηγή)
        kinTimesVec = kinTable.getIndependentColumn();
        numKinPoints = kinTimesVec.size();
        kinTimes = zeros(numKinPoints, 1);
        for t=1:numKinPoints, kinTimes(t) = kinTimesVec.get(t-1); end
        
        % Για κάθε στήλη της κίνησης (Angles), κάνουμε interpolate και την κολλάμε στο Table
        kinLabels = kinTable.getColumnLabels();
        for c = 0:kinLabels.size()-1
            colName = char(kinLabels.get(c));
            
            % Λήψη δεδομένων στήλης
            colDataVec = kinTable.getDependentColumn(colName).getAsMat(); % Java -> Matlab
            
            % Interpolation (Resampling)
            % Προσαρμογή των γωνιών στον χρόνο του Moco
            newData = interp1(kinTimes, colDataVec, mocoTimes, 'linear', 'extrap');
            
            % Μετατροπή πίσω σε OpenSim Vector και προσθήκη
            newColVector = Vector(length(newData), 0.0);
            for n=1:length(newData), newColVector.set(n-1, newData(n)); end
            
            forceTable.appendColumn(colName, newColVector);
        end
        
        % Εγγραφή Τελικού Αρχείου
        STOFileAdapter.write(forceTable, outputFile);
        
        fprintf('[OK] %d%% -> Full_Animation_%d.mot\n', w, w);
        
    catch ME
        fprintf('[ERROR] %d%%: %s\n', w, ME.message);
    end
end

fprintf('\n--- ΟΛΟΚΛΗΡΩΘΗΚΕ ---\n');
fprintf('Τώρα φόρτωσε τα αρχεία "Full_Animation_XX.mot" στο OpenSim!\n');