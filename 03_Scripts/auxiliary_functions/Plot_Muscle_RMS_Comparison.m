%% Script: Plot_Muscle_RMS_Comparison.m
% Σκοπός: Σύγκριση μυϊκών ενεργοποιήσεων (RMS Filtered) σε % Κύκλου Βάδισης
% για όλα τα επίπεδα αδυναμίας (10% - 80%).

clear; clc; close all;

% --- ΡΥΘΜΙΣΕΙΣ ---
muscles_of_interest = {'vas_med_r', 'vas_lat_r', 'rect_fem_r'}; 
muscle_titles = {'Vastus Medialis', 'Vastus Lateralis', 'Rectus Femoris'};
weakness_levels = 10:10:80; 
rms_window = 10; % Πλάτος παραθύρου για το φίλτρο (smoothing)

% 1. ΕΠΙΛΟΓΗ ΦΑΚΕΛΟΥ
fprintf('Επίλεξε τον φάκελο "Adaptive_Curve_Final"...\n');
baseDir = uigetdir(pwd, 'Select Adaptive_Curve_Final');
if baseDir == 0, error('Δεν επιλέχθηκε φάκελος.'); end

% Προετοιμασία Σχήματος
figure('Name', 'Muscle Activation Comparison', 'Color', 'w', 'Position', [100 100 1200 400]);
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
import org.opensim.modeling.*

% Χρωματική Παλέτα (Από Μπλε σε Κόκκινο)
colors = jet(length(weakness_levels)); 

% 2. LOOP ΓΙΑ ΚΑΘΕ ΜΥ
for m = 1:length(muscles_of_interest)
    target_muscle = muscles_of_interest{m};
    nexttile; hold on; grid on;
    
    % LOOP ΓΙΑ ΚΑΘΕ ΠΟΣΟΣΤΟ ΑΔΥΝΑΜΙΑΣ
    for i = 1:length(weakness_levels)
        w = weakness_levels(i);
        folderName = sprintf('Weakness_%d', w);
        file = fullfile(baseDir, folderName, 'Result.sto');
        
        if ~isfile(file), continue; end
        
        try
            % Φόρτωση Δεδομένων
            table = TimeSeriesTable(file);
            
            % Εύρεση της σωστής στήλης (ψάχνουμε το path που τελειώνει στο όνομα)
            labels = table.getColumnLabels();
            colName = '';
            for k=0:labels.size()-1
                lbl = char(labels.get(k));
                % Ψάχνουμε π.χ. ".../vas_med_r/activation"
                if contains(lbl, target_muscle) && contains(lbl, 'activation')
                    colName = lbl;
                    break;
                end
            end
            
            if isempty(colName)
                warning('Ο μυς %s δεν βρέθηκε στο %d%%', target_muscle, w);
                continue;
            end
            
            % Λήψη Δεδομένων (Time & Activation)
            timeVec = table.getIndependentColumn();
            dataVec = table.getDependentColumn(colName).getAsMat();
            
            % Μετατροπή σε Matlab vectors
            t = zeros(timeVec.size(),1);
            for j=0:timeVec.size()-1, t(j+1) = timeVec.get(j); end
            y = dataVec;
            
            % --- 3. TIME NORMALIZATION (0-100%) ---
            % Κανονικοποιούμε τον χρόνο ώστε 0% = Heel Strike, 100% = Next Heel Strike
            percent_gait = (t - t(1)) / (t(end) - t(1)) * 100;
            
            % Interpolation σε σταθερό grid 101 σημείων (0, 1, ..., 100)
            query_points = 0:1:100;
            y_interp = interp1(percent_gait, y, query_points, 'pchip');
            
            % --- 4. RMS FILTERING (Smoothing) ---
            % Εφαρμόζουμε κινητό RMS (Moving Root Mean Square)
            y_rms = sqrt(movmean(y_interp.^2, rms_window));
            
            % Plot
            plot(query_points, y_rms, 'Color', colors(i,:), 'LineWidth', 2, 'DisplayName', sprintf('%d%%', w));
            
        catch
            continue;
        end
    end
    
    % Μορφοποίηση Διαγράμματος
    title(muscle_titles{m}, 'FontSize', 14);
    xlabel('% Gait Cycle');
    ylabel('Activation (0-1)');
    ylim([0 1]);
    
    % Βάζουμε Legend μόνο στο πρώτο για να μην πιάνει χώρο
    if m == 1
        legend('Location', 'NorthWest', 'FontSize', 8);
    end
end

sgtitle('Quadriceps Activation under Progressive Weakness (Assist-as-Needed)', 'FontSize', 16);
fprintf('Η γραφική παράσταση ολοκληρώθηκε!\n');