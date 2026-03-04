%% Script: Plot_Reserves_Exoskeleton.m
% Σκοπός: Δημιουργία Εικόνων 23 και 24 για Reserves (Exoskeleton Torque)

clear; clc; close all;

% --- ΕΠΙΛΟΓΗ ΑΡΧΕΙΩΝ ---
fprintf('--- ΒΗΜΑ 1: Επίλεξε το αρχείο Actuation Force για το WEAK 40 ---\n');
[file40, path40] = uigetfile('*.sto', 'Επίλεξε WEAK 40 _Actuation_force.sto');
if file40 == 0, error('Δεν επιλέχθηκε Weak40'); end

fprintf('--- ΒΗΜΑ 2: Επίλεξε το αρχείο Actuation Force για το WEAK 80 ---\n');
[file80, path80] = uigetfile('*.sto', 'Επίλεξε WEAK 80 _Actuation_force.sto');
if file80 == 0, error('Δεν επιλέχθηκε Weak80'); end

% Φόρτωση Δεδομένων
import org.opensim.modeling.*
table40 = TimeSeriesTable(fullfile(path40, file40));
table80 = TimeSeriesTable(fullfile(path80, file80));

% Συνάρτηση για λήψη δεδομένων (για να μην γράφουμε πολλά)
get_data = @(tbl, col) interp1(...
    (0:tbl.getIndependentColumn().size()-1)'/(tbl.getIndependentColumn().size()-1)*100, ... % Time %
    tbl.getDependentColumn(col).getAsMat(), ... % Data
    0:1:100, 'pchip'); % Interpolation 0-100%

% Ανάκτηση Δεδομένων (ΠΡΟΣΟΧΗ: Τα ονόματα μπορεί να διαφέρουν ελαφρώς, ψάχνουμε reserve)
% Συνήθως είναι: knee_angle_r_reserve / knee_angle_l_reserve
try
    res_r_40 = get_data(table40, 'knee_angle_r_reserve');
    res_l_40 = get_data(table40, 'knee_angle_l_reserve');
    res_r_80 = get_data(table80, 'knee_angle_r_reserve');
catch
    error('Δεν βρέθηκαν οι στήλες knee_angle_r_reserve. Έλεγξε τα αρχεία.');
end

x = 0:1:100; % Άξονας Χ

%% --- ΕΙΚΟΝΑ 23: Weak40 (Right vs Left) ---
figure('Name', 'Figure 23: Reserve R vs L (Weak40)', 'Color', 'w', 'Position', [100 100 800 500]);
hold on; grid on;
plot(x, res_r_40, 'r', 'LineWidth', 3, 'DisplayName', 'Right Knee (Pathologic)');
plot(x, res_l_40, 'b', 'LineWidth', 3, 'DisplayName', 'Left Knee (Healthy)');
yline(0, '--k'); % Γραμμή στο μηδέν

title('Εικόνα 23: Reserve Ροπή Γόνατος (Weak 40%)', 'FontSize', 14);
xlabel('Κύκλος Βάδισης (%)');
ylabel('Ροπή Εξωσκελετού (Nm)');
legend('Location', 'Best');
exportgraphics(gcf, 'Figure_23_Reserve_RvL.png', 'Resolution', 300);

%% --- ΕΙΚΟΝΑ 24: Right Knee (Weak40 vs Weak80) ---
figure('Name', 'Figure 24: Reserve Weak40 vs Weak80', 'Color', 'w', 'Position', [150 150 800 500]);
hold on; grid on;
plot(x, res_r_40, 'r', 'LineWidth', 3, 'DisplayName', 'Weak 40%');
plot(x, res_r_80, 'b', 'LineWidth', 3, 'DisplayName', 'Weak 80%');
yline(0, '--k');

title('Εικόνα 24: Σύγκριση Υποβοήθησης (Assist-as-Needed)', 'FontSize', 14);
xlabel('Κύκλος Βάδισης (%)');
ylabel('Ροπή Εξωσκελετού (Nm)');
legend('Location', 'Best');
exportgraphics(gcf, 'Figure_24_Reserve_Comparison.png', 'Resolution', 300);

fprintf('Έτοιμες οι Εικόνες 23 και 24!\n');