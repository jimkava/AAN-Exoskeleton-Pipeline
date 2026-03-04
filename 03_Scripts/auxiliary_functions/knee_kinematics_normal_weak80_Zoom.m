%% knee_kinematics_zoom_stance.m
% Δημιουργία Zoomed γραφήματος για τη φάση Loading Response (0.71s - 0.87s)

%% 1. Φόρτωση Δεδομένων
file_normal = 'C:\OpenSim 4.5\sdk\Models\DropFoot_GaitRehab_FESRobex\Gaithab_FesRobex_project_22.12.25\DATA_OPENSIM\ADULTS-NORMAL_WALKING\02_InverseKinematics\Results\Normal\subject01_IK_normal.mot';
file_weak80 = 'C:\OpenSim 4.5\sdk\Models\DropFoot_GaitRehab_FESRobex\Gaithab_FesRobex_project_22.12.25\DATA_OPENSIM\ADULTS-NORMAL_WALKING\05_CMC\CMC_weakQuad\subject01_walk1_weak80_CMC\subject01_walk1_weak80_CMC_Kinematics_q.sto';

data_norm_struct = importdata(file_normal);
data_weak_struct = importdata(file_weak80);

% Εύρεση στηλών
idx_t_n = find(strcmpi(data_norm_struct.colheaders, 'time'), 1);
idx_k_n = find(contains(data_norm_struct.colheaders, 'knee_angle_r'), 1);
idx_t_w = find(strcmpi(data_weak_struct.colheaders, 'time'), 1);
idx_k_w = find(contains(data_weak_struct.colheaders, 'knee_angle_r'), 1);

time_norm = data_norm_struct.data(:, idx_t_n);
knee_norm = data_norm_struct.data(:, idx_k_n);
time_weak = data_weak_struct.data(:, idx_t_w);
knee_weak = data_weak_struct.data(:, idx_k_w);

%% 2. Δημιουργία Figure
fig = figure('Units', 'centimeters', 'Position', [2, 2, 24, 18], 'Color', 'w');
ax = axes('Parent', fig);
hold(ax, 'on');

% Σχεδίαση γραμμών
p1 = plot(ax, time_norm, knee_norm, 'r', 'LineWidth', 3.0, 'DisplayName', 'Normal');
p2 = plot(ax, time_weak, knee_weak, 'b', 'LineWidth', 3.0, 'DisplayName', 'Weak 80%');

%% 3. Ρυθμίσεις Αξόνων (Μέγεθος 36 & ZOOM)
fSize = 36;

set(ax, 'Color', 'w', ...
        'XColor', 'k', 'YColor', 'k', ...
        'FontName', 'Times New Roman', 'FontSize', fSize, ...
        'Box', 'on', 'LineWidth', 1.5, ...
        'XGrid', 'on', 'YGrid', 'on', ...
        'GridColor', [0.8 0.8 0.8], 'GridAlpha', 0.5);

xlabel(ax, 'Time (s)', 'FontSize', fSize, 'Color', 'k', 'FontWeight', 'bold');
ylabel(ax, 'Knee Angle (deg)', 'FontSize', fSize, 'Color', 'k', 'FontWeight', 'bold');

% --- ΕΔΩ ΓΙΝΕΤΑΙ ΤΟ ΖΟΥΜ ---
% Κλειδώνουμε τον άξονα X από 0.71 έως 0.87
xlim(ax, [0.71 0.87]); 
% Κλειδώνουμε τον άξονα Y για να ταιριάζει απόλυτα στις καμπύλες αυτού του χρόνου
ylim(ax, [-26 -16]); 

%% 4. Διόρθωση Legend
lgd = legend(ax, [p1, p2]);
set(lgd, 'Location', 'northeast', ... % Πάνω δεξιά γωνία
         'FontSize', 28, ...
         'FontName', 'Times New Roman', ...
         'TextColor', 'k', ...
         'EdgeColor', 'k', ...
         'Color', 'w');

%% 5. Εξαγωγή σε PDF
exportgraphics(fig, 'knee_kinematics_zoom_stance.pdf', 'ContentType', 'vector');