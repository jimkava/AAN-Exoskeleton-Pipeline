%% Script: Plot_CMC_Force_Newtons.m
% Σκοπός: Σύγκριση ΔΥΝΑΜΗΣ (Newtons) για τον Vastus Medialis
% Normal vs Weak80

clear; clc; close all;

muscle_name = 'vas_med_r'; 

% --- ΦΟΡΤΩΣΗ ΑΡΧΕΙΩΝ ---
fprintf('--- ΕΠΙΛΟΓΗ ΑΡΧΕΙΩΝ ACTUATION FORCE (N) ---\n');

% 1. NORMAL
fprintf('ΒΗΜΑ 1: Επίλεξε το αρχείο FORCE για το NORMAL...\n');
fprintf('Ψάξε για: subject01_CMC_Actuation_force.sto\n');
[file1, path1] = uigetfile('*.sto', 'Επίλεξε NORMAL Force');
if file1 == 0, error('Δεν επιλέχθηκε Normal'); end

% 2. WEAK 80
fprintf('ΒΗΜΑ 2: Επίλεξε το αρχείο FORCE για το WEAK 80...\n');
fprintf('Ψάξε για: subject01_walk1_weak80_CMC_Actuation_force.sto\n');
[file2, path2] = uigetfile('*.sto', 'Επίλεξε WEAK80 Force');
if file2 == 0, error('Δεν επιλέχθηκε Weak80'); end

% Φόρτωση
import org.opensim.modeling.*
files = {fullfile(path1, file1), fullfile(path2, file2)};
labels = {'Normal (N)', 'Weak 80% (N)'};
colors = {'b', 'r'}; 

figure('Name', 'Muscle Force Comparison (N)', 'Color', 'w');
hold on; grid on;

for i = 1:2
    try
        table = TimeSeriesTable(files{i});
        colLabels = table.getColumnLabels();
        targetCol = '';
        
        % Ψάχνουμε το όνομα του μυός (εδώ συνήθως δεν έχει /activation)
        for k = 0:colLabels.size()-1
            lbl = char(colLabels.get(k));
            if strcmp(lbl, muscle_name) || contains(lbl, [muscle_name '/value'])
                targetCol = lbl;
                break;
            end
        end
        
        if isempty(targetCol)
            error('Δεν βρέθηκε ο μυς %s στο αρχείο %d', muscle_name, i);
        end
        
        % Data processing
        timeVec = table.getIndependentColumn();
        dataVec = table.getDependentColumn(targetCol).getAsMat();
        
        t = zeros(timeVec.size(),1);
        for j=0:timeVec.size()-1, t(j+1) = timeVec.get(j); end
        
        % Time Normalization
        percent_gait = (t - t(1)) / (t(end) - t(1)) * 100;
        xq = 0:1:100;
        yq = interp1(percent_gait, dataVec, xq, 'pchip');
        
        % Smoothing
        y_smooth = smoothdata(yq, 'movmean', 10);
        
        plot(xq, y_smooth, 'Color', colors{i}, 'LineWidth', 3);
        
        % Υπολογισμός Max Force για το Report
        fprintf('Max Force for %s: %.2f Newtons\n', labels{i}, max(y_smooth));
        
    catch ME
        fprintf('Error file %d: %s\n', i, ME.message);
    end
end

title('Muscle Force Comparison (Vastus Medialis)', 'FontSize', 14);
xlabel('% Gait Cycle');
ylabel('Force (Newtons)');
legend(labels, 'Location', 'NorthWest');

% Αποθήκευση
exportgraphics(gcf, 'Figure_Force_Newtons.png', 'Resolution', 300);