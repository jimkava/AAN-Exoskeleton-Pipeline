%% Script: Plot_Reserves_Smooth.m
% Σκοπός: Δημιουργία ΛΕΙΩΝ (Smoothed) Εικόνων 23 και 24 για Reserves
% Χρησιμοποιεί Gaussian Filter για να διώξει τον θόρυβο του CMC.

clear; clc; close all;

% --- ΡΥΘΜΙΣΕΙΣ ---
smoothness = 25; % Όσο πιο μεγάλο, τόσο πιο "καμπύλη" η γραμμή (Δοκίμασε 20-30)

% --- ΕΠΙΛΟΓΗ ΑΡΧΕΙΩΝ ---
fprintf('--- ΒΗΜΑ 1: Επίλεξε το αρχείο Actuation Force για το WEAK 40 ---\n');
[file40, path40] = uigetfile('*.sto', 'Επίλεξε WEAK 40 _Actuation_force.sto');
if file40 == 0, error('Δεν επιλέχθηκε Weak40'); end

fprintf('--- ΒΗΜΑ 2: Επίλεξε το αρχείο Actuation Force για το WEAK 80 ---\n');
[file80, path80] = uigetfile('*.sto', 'Επίλεξε WEAK 80 _Actuation_force.sto');
if file80 == 0, error('Δεν επιλέχθηκε Weak80'); end

% Φόρτωση
import org.opensim.modeling.*
table40 = TimeSeriesTable(fullfile(path40, file40));
table80 = TimeSeriesTable(fullfile(path80, file80));

% Συνάρτηση Επεξεργασίας: Normalization + SMOOTHING
process_data = @(tbl, col) smoothdata(...
    interp1(...
        (0:tbl.getIndependentColumn().size()-1)'/(tbl.getIndependentColumn().size()-1)*100, ...
        tbl.getDependentColumn(col).getAsMat(), ...
        0:1:100, 'pchip'), ...
    'gaussian', smoothness); 

% Ανάκτηση Δεδομένων (Reserve Γόνατος)
try
    res_r_40 = process_data(table40, 'knee_angle_r_reserve');
    res_l_40 = process_data(table40, 'knee_angle_l_reserve');
    res_r_80 = process_data(table80, 'knee_angle_r_reserve');
catch
    error('Δεν βρέθηκαν οι στήλες knee_angle_r_reserve. Έλεγξε τα αρχεία.');
end

x = 0:1:100;

%% --- ΕΙΚΟΝΑ 23: Weak40 (Right vs Left) ---
figure('Name', 'Figure 23: Reserve R vs L (Smooth)', 'Color', 'w', 'Position', [100 100 900 500]);
hold on; grid on;

% Plot
plot(x, res_r_40, 'r', 'LineWidth', 3, 'DisplayName', 'Right Knee (Pathologic)');
plot(x, res_l_40, 'b', 'LineWidth', 3, 'DisplayName', 'Left Knee (Healthy)');
yline(0, '--k', 'HandleVisibility', 'off');

% Μορφοποίηση
title('Εικόνα 23: Reserve Ροπή Γόνατος (Weak 40%) - Smoothed', 'FontSize', 14);
xlabel('Κύκλος Βάδισης (%)', 'FontSize', 12);
ylabel('Ροπή Εξωσκελετού (Nm)', 'FontSize', 12);
legend('Location', 'NorthWest', 'FontSize', 11);
axis([0 100 -30 40]); % Κλειδώνουμε τους άξονες για ομοιομορφία

exportgraphics(gcf, 'Figure_23_Smooth.png', 'Resolution', 300);

%% --- ΕΙΚΟΝΑ 24: Weak40 vs Weak80 Comparison ---
figure('Name', 'Figure 24: Assist-as-Needed (Smooth)', 'Color', 'w', 'Position', [150 150 900 500]);
hold on; grid on;

% Plot
plot(x, res_r_40, 'r', 'LineWidth', 3, 'DisplayName', 'Weak 40% (Mild Assist)');
plot(x, res_r_80, 'b', 'LineWidth', 3, 'DisplayName', 'Weak 80% (High Assist)');
yline(0, '--k', 'HandleVisibility', 'off');

% Μορφοποίηση
title('Εικόνα 24: Σύγκριση Υποβοήθησης (Assist-as-Needed)', 'FontSize', 14);
xlabel('Κύκλος Βάδισης (%)', 'FontSize', 12);
ylabel('Ροπή Εξωσκελετού (Nm)', 'FontSize', 12);
legend('Location', 'NorthWest', 'FontSize', 11);
axis([0 100 -30 40]); 

exportgraphics(gcf, 'Figure_24_Smooth.png', 'Resolution', 300);

fprintf('Έτοιμες! Οι καμπύλες τώρα είναι λείες σαν του τετρακέφαλου.\n');