% ======================================================================= %
%   PROJECT: FesRobex - Gait2392 Simbody Pipeline
%   SCRIPT:  plot_FD_CMCExo_Restoration.m
%
%   ΣΤΟΧΟΣ: IEEE-style plot για Section IV-B
%   Χρώματα ίδια με Fig.10 του paper
%
%   PANELS:
%   (a) Knee angle trajectories vs Normal - Gait Cycle (%)
%   (b) Deviation Δθ = θ_WeakExo - θ_Normal
%
%   AUTHOR:  Dimitrios Kavalieros, EE & IT MSc. & MEd.
%   DATE:    June 2026
% ======================================================================= %

clear; clc; close all;

%% ===== 1. PATHS =====
ROOT       = fileparts(fileparts(mfilename('fullpath')));   % repo root
DIR_NORMAL = fullfile(ROOT, '02_NORMAL', '05_FD_NORMAL', 'Results');
DIR_V5     = fullfile(ROOT, '04_Moco_AAN', 'Results_v5_CMC_Exo');
DIR_PLOTS  = fullfile(ROOT, '05_Plots');

f_normal = fullfile(DIR_NORMAL, 'subject01_walk1_normal_Kinematics_q.sto');
f_weak20 = fullfile(DIR_V5, 'Weak20', 'FD_with_exo', ...
    'subject01_walk1_weak20_Kinematics_q.sto');
f_weak30 = fullfile(DIR_V5, 'Weak30', 'FD_with_exo', ...
    'subject01_walk1_weak30_Kinematics_q.sto');
f_weak50 = fullfile(DIR_V5, 'Weak50', 'FD_with_exo', ...
    'subject01_walk1_weak50_Kinematics_q.sto');

for f = {f_normal, f_weak20, f_weak30, f_weak50}
    assert(exist(f{1},'file')>0, 'ΛΕΙΠΕΙ: %s', f{1});
end
fprintf('OK - Ola ta arxeia entopistikan.\n');

%% ===== 2. ΦΟΡΤΩΣΗ =====
[t_norm, q_norm] = load_knee_angle(f_normal);
[t_w20,  q_w20]  = load_knee_angle(f_weak20);
[t_w30,  q_w30]  = load_knee_angle(f_weak30);
[t_w50,  q_w50]  = load_knee_angle(f_weak50);

%% ===== 3. GAIT CYCLE GRID =====
N  = 1000;
gc = linspace(0, 100, N)';

t_start = t_norm(1);
t_end   = t_norm(end);
t_gc    = linspace(t_start, t_end, N)';

q_norm_gc = interp1(t_norm, q_norm, t_gc, 'linear', 'extrap');
q_w20_gc  = interp1(t_w20,  q_w20,  t_gc, 'linear', 'extrap');
q_w30_gc  = interp1(t_w30,  q_w30,  t_gc, 'linear', 'extrap');
q_w50_gc  = interp1(t_w50,  q_w50,  t_gc, 'linear', 'extrap');

dq_w20 = q_w20_gc - q_norm_gc;
dq_w30 = q_w30_gc - q_norm_gc;
dq_w50 = q_w50_gc - q_norm_gc;

rmse_w20 = rms(dq_w20);
rmse_w30 = rms(dq_w30);
rmse_w50 = rms(dq_w50);

fprintf('RMSE Weak20+Exo: %.4f deg\n', rmse_w20);
fprintf('RMSE Weak30+Exo: %.4f deg\n', rmse_w30);
fprintf('RMSE Weak50+Exo: %.4f deg\n', rmse_w50);

%% ===== 4. ΧΡΩΜΑΤΑ — ίδια με paper =====
col_normal = [0.00, 0.00, 0.00];        % Μαύρο
col_w50    = [0.80, 0.10, 0.10];        % Κόκκινο (Weak50 — dominant)
col_w30    = [1.00, 0.60, 0.00];        % Πορτοκαλί dashed
col_w20    = [0.20, 0.65, 0.20];        % Πράσινο dashed

% Shaded backgrounds
col_stance = [0.85, 0.92, 1.00];        % Ανοιχτό μπλε
col_swing  = [1.00, 0.90, 0.88];        % Ανοιχτό ροζ

stance_end = 60;  % % GC

%% ===== 5. FIGURE =====
fig = figure('Color','w','Position',[100 50 720 620]);

%% ----- PANEL (a) -----
ax1 = subplot(2,1,1);
hold(ax1,'on');
set(ax1,'Color','w','FontSize',10,'FontName','Times New Roman','Box','on');

% Shaded backgrounds
fill(ax1, [0 stance_end stance_end 0], ...
    [1e3 1e3 -1e3 -1e3], col_stance, ...
    'EdgeColor','none','FaceAlpha',1.0,'HandleVisibility','off');
fill(ax1, [stance_end 100 100 stance_end], ...
    [1e3 1e3 -1e3 -1e3], col_swing, ...
    'EdgeColor','none','FaceAlpha',1.0,'HandleVisibility','off');

% Stance/Swing labels
ylim_top = [min([q_norm_gc;q_w20_gc;q_w30_gc;q_w50_gc])-3, ...
             max([q_norm_gc;q_w20_gc;q_w30_gc;q_w50_gc])+5];
text(ax1, stance_end/2, ylim_top(2)-2, 'Stance Phase', ...
    'HorizontalAlignment','center','FontSize',10,'FontWeight','bold',...
    'FontName','Times New Roman','Color',[0.20 0.45 0.80]);
text(ax1, (stance_end+100)/2, ylim_top(2)-2, 'Swing Phase', ...
    'HorizontalAlignment','center','FontSize',10,'FontWeight','bold',...
    'FontName','Times New Roman','Color',[0.80 0.20 0.20]);

% Separator
plot(ax1, [stance_end stance_end], ylim_top, '--', ...
    'Color',[0.4 0.4 0.4],'LineWidth',1.0,'HandleVisibility','off');

% Curves
plot(ax1, gc, q_norm_gc, '-',  'Color',col_normal,'LineWidth',2.0,...
    'DisplayName','Normal (0%)');
plot(ax1, gc, q_w50_gc,  '-',  'Color',col_w50,   'LineWidth',1.8,...
    'DisplayName',sprintf('Weak50 + Exo (RMSE=%.2f°)',rmse_w50));
plot(ax1, gc, q_w30_gc,  '--', 'Color',col_w30,   'LineWidth',1.5,...
    'DisplayName',sprintf('Weak30 + Exo (RMSE=%.2f°)',rmse_w30));
plot(ax1, gc, q_w20_gc,  '--', 'Color',col_w20,   'LineWidth',1.5,...
    'DisplayName',sprintf('Weak20 + Exo (RMSE=%.2f°)',rmse_w20));

ylabel(ax1,'Knee Angle (deg)','FontSize',12,'FontName','Times New Roman','Color','k');
xlim(ax1,[0 100]); ylim(ax1, ylim_top);
set(ax1,'XTickLabel',[],'GridAlpha',0.15,'GridColor',[0.3 0.3 0.3],...
    'XColor','k','YColor','k','FontSize',10);
grid(ax1,'on');
legend(ax1,'Location','southwest','FontSize',10,'FontName','Times New Roman',...
    'Box','on','Color','w','TextColor','k');

text(ax1, 1, ylim_top(2)-1, '(a)','FontSize',11,'FontWeight','bold',...
    'FontName','Times New Roman');

%% ----- PANEL (b) -----
ax2 = subplot(2,1,2);
hold(ax2,'on');
set(ax2,'Color','w','FontSize',10,'FontName','Times New Roman','Box','on');

% y limits για deviation
ylim_dev = [min([dq_w20;dq_w30;dq_w50])-0.5, ...
             max([dq_w20;dq_w30;dq_w50])+1.5];

% Shaded backgrounds
fill(ax2,[0 stance_end stance_end 0], ...
    [1e3 1e3 -1e3 -1e3], col_stance,...
    'EdgeColor','none','FaceAlpha',1.0,'HandleVisibility','off');
fill(ax2,[stance_end 100 100 stance_end], ...
    [1e3 1e3 -1e3 -1e3], col_swing,...
    'EdgeColor','none','FaceAlpha',1.0,'HandleVisibility','off');

% Separator
plot(ax2,[stance_end stance_end], ylim_dev,'--',...
    'Color',[0.4 0.4 0.4],'LineWidth',1.0,'HandleVisibility','off');

% Zero line
plot(ax2,[0 100],[0 0],'k-','LineWidth',0.8,'HandleVisibility','off');

% Deviation curves
plot(ax2, gc, dq_w50, '-',  'Color',col_w50,'LineWidth',1.8,...
    'DisplayName',sprintf('\\Delta\\theta_{Weak50} (RMSE=%.2f°)',rmse_w50));
plot(ax2, gc, dq_w30, '--', 'Color',col_w30,'LineWidth',1.5,...
    'DisplayName',sprintf('\\Delta\\theta_{Weak30} (RMSE=%.2f°)',rmse_w30));
plot(ax2, gc, dq_w20, '--', 'Color',col_w20,'LineWidth',1.5,...
    'DisplayName',sprintf('\\Delta\\theta_{Weak20} (RMSE=%.2f°)',rmse_w20));

% Peak annotations
[pk50, idx50] = max(abs(dq_w50));
text(ax2, gc(idx50)+2, dq_w50(idx50)+0.2, ...
    sprintf('%.1f°', dq_w50(idx50)),...
    'FontSize',8,'Color',col_w50,'FontName','Times New Roman');

xlabel(ax2,'Gait Cycle (%)','FontSize',12,'FontName','Times New Roman',...
    'Interpreter','none','Color','k');
ylabel(ax2,'\Delta\theta = \theta_{Exo} - \theta_{Normal} (deg)',...
    'FontSize',12,'FontName','Times New Roman','Color','k');
xlim(ax2,[0 100]); ylim(ax2, ylim_dev);
set(ax2,'GridAlpha',0.15,'GridColor',[0.3 0.3 0.3],...
    'XColor','k','YColor','k','FontSize',10);
grid(ax2,'on');
legend(ax2,'Location','northeast','FontSize',10,'FontName','Times New Roman',...
    'Box','on','Color','w','TextColor','k');

text(ax2, 1, ylim_dev(2)-0.2,'(b)','FontSize',11,'FontWeight','bold',...
    'FontName','Times New Roman');

%% ===== 6. SAVE =====
set(fig,'PaperUnits','centimeters','PaperSize',[8.8 12],...
    'PaperPosition',[0 0 8.8 12]);

outPDF = fullfile(DIR_PLOTS,'Fig_FD_CMCExo_Restoration.pdf');
outPNG = fullfile(DIR_PLOTS,'Fig_FD_CMCExo_Restoration.png');

saveas(fig, outPDF);
print(fig, outPNG, '-dpng', '-r300');
fprintf('\nSaved:\n  %s\n  %s\n', outPDF, outPNG);

%% ===== FUNCTION =====
function [time, angle_deg] = load_knee_angle(filepath)
    data = importdata(filepath);
    if ~isstruct(data), error('Cannot load: %s',filepath); end
    time_idx = find(strcmpi(data.colheaders,'time'),1);
    knee_idx = find(contains(lower(data.colheaders),'knee_angle_r') & ...
                   ~contains(lower(data.colheaders),'speed') & ...
                   ~contains(lower(data.colheaders),'beta'),1);
    if isempty(knee_idx)
        knee_idx = find(contains(lower(data.colheaders),'knee_angle_r'),1);
    end
    time      = data.data(:,time_idx);
    angle_deg = data.data(:,knee_idx);
end
