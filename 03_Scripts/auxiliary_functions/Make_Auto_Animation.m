%% Script: Make_Auto_Animation.m
% Σκοπός: Δημιουργεί Animation που αναγνωρίζεται ΑΥΤΟΜΑΤΑ από το OpenSim 4.x
% Κρατάει τα πλήρη paths (/forceset/.../activation) για να μην χρειάζεται "Associate".

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
kinTimes = kinTable.getIndependentColumn(); 
kTimesMat = zeros(kinTimes.size(),1);
for t=0:kinTimes.size()-1, kTimesMat(t+1) = kinTimes.get(t); end

weakness_percents = 10:10:80; 

for i = 1:length(weakness_percents)
    w = weakness_percents(i);
    folderName = sprintf('Weakness_%d', w);
    forceFile = fullfile(resultsBaseDir, folderName, 'Result.sto');
    outputFile = fullfile(resultsBaseDir, folderName, sprintf('Auto_Video_%d.mot', w));
    
    if ~isfile(forceFile), continue; end
    
    try
        % Φόρτωση Δυνάμεων
        forceTable = TimeSeriesTable(forceFile);
        forceTimes = forceTable.getIndependentColumn();
        fTimesMat = zeros(forceTimes.size(),1);
        for t=0:forceTimes.size()-1, fTimesMat(t+1) = forceTimes.get(t); end
        
        % 1. Ξεκινάμε με τον πίνακα της Κίνησης (Γωνίες)
        finalTable = kinTable.clone();
        
        % 2. Προσθέτουμε ΜΟΝΟ τα Activations (με το πλήρες όνομα!)
        oldLabels = forceTable.getColumnLabels();
        
        for c = 0:oldLabels.size()-1
            colName = char(oldLabels.get(c));
            
            % Κρατάμε μόνο στήλες που τελειώνουν σε '/activation'
            % Έτσι γλιτώνουμε τα controls/duplicates και το OpenSim βλέπει το σωστό path.
            if endsWith(colName, '/activation')
                
                % Παίρνουμε τα δεδομένα
                colData = forceTable.getDependentColumn(colName).getAsMat();
                
                % Interpolation
                newData = interp1(fTimesMat, colData, kTimesMat, 'linear', 'extrap');
                
                % Δημιουργία στήλης
                newColVector = Vector(length(newData), 0.0);
                for n=1:length(newData), newColVector.set(n-1, newData(n)); end
                
                % Προσθήκη στο τέλος (με το ΠΛΗΡΕΣ όνομα)
                finalTable.appendColumn(colName, newColVector);
            end
        end
        
        % Εγγραφή
        STOFileAdapter.write(finalTable, outputFile);
        fprintf('[OK] Auto_Video_%d.mot -> Έτοιμο για OpenSim!\n', w);
        
    catch ME
        fprintf('[ERROR] %d%%: %s\n', w, ME.message);
    end
end

fprintf('\n--- ΕΤΟΙΜΟ ---\n');
fprintf('Φόρτωσε το "Auto_Video_80.mot". Τώρα θα παίζει τέλεια!\n');