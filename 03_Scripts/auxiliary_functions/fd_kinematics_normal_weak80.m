%% fd_kinematics_normal_weak80.m
% Διορθωμένο για Μαύρα Γράμματα στο Legend, Λευκό Φόντο και δεδομένα Forward Dynamics

%% 1. Φόρτωση Δεδομένων
file_normal = 'C:\OpenSim 4.5\sdk\Models\DropFoot_GaitRehab_FESRobex\Gaithab_FesRobex_project_22.12.25\DATA_OPENSIM\ADULTS-NORMAL_WALKING\06_ForwardDynamics\Results\Normal\subject01_walk1_fwd_Kinematics_q.sto';
file_weak80 = 'C:\OpenSim 4.5\sdk\Models\DropFoot_GaitRehab_FESRobex\Gaithab_FesRobex_project_22.12.25\DATA_OPENSIM\ADULTS-NORMAL_WALKING\06_ForwardDynamics\FD_WEAK\WEAK80\subject01_walk1_weak80_FD_Kinematics_q.sto';

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
p1 = plot(ax, time_norm, knee_norm, 'r', 'LineWidth', 2.5, 'DisplayName', 'Normal');
p2 = plot(ax, time_weak, knee_weak, 'b', 'LineWidth', 2.5, 'DisplayName', 'Weak 80%');

%% 3. Ρυθμίσεις Αξόνων (Μέγεθος 36)
fSize = 36;
set(ax, 'Color', 'w', ...
        'XColor', 'k', 'YColor', 'k', ...
        'FontName', 'Times New Roman', 'FontSize', fSize, ...
        'Box', 'on', 'LineWidth', 1.5, ... % 'Box on' για να φαίνονται οι άξονες καθαρά
        'XGrid', 'on', 'YGrid', 'on', ...
        'GridColor', [0.8 0.8 0.8], 'GridAlpha', 0.5);

xlabel(ax, 'Time (s)', 'FontSize', fSize, 'Color', 'k', 'FontWeight', 'bold');
ylabel(ax, 'Knee Angle (deg)', 'FontSize', fSize, 'Color', 'k', 'FontWeight', 'bold');
xlim(ax, [0.5 1.3]); 

%% 4. Διόρθωση Legend (Μαύρα Γράμματα)
lgd = legend(ax, [p1, p2]);
set(lgd, 'Location', 'northeast', ...
         'FontSize', 28, ...
         'FontName', 'Times New Roman', ...
         'TextColor', 'k', ...         % ΕΠΙΒΟΛΗ ΜΑΥΡΟΥ ΧΡΩΜΑΤΟΣ ΣΤΑ ΓΡΑΜΜΑΤΑ
         'EdgeColor', 'k', ...         % Λεπτό μαύρο πλαίσιο γύρω από τη λεζάντα
         'Color', 'w');                % Λευκό φόντο μέσα στη λεζάντα

%% 5. Εξαγωγή σε PDF
exportgraphics(fig, 'fd_kinematics_normal_weak80.pdf', 'ContentType', 'vector');