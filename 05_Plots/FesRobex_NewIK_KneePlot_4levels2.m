% =========================================================
%  FesRobex — NewIK Knee Analysis (4 levels)
%  2 SEPARATE single-column figures for IEEE T-MRB
%  Output: NewIK_knee_4levels_final4_a.pdf  (Knee Angle)
%          NewIK_knee_4levels_final4_b.pdf  (Deviation)
%  Dimitrios Kavalieros | FesRobex Project
% =========================================================

clc; clear; close all;
import org.opensim.modeling.*;

%% --- SETTINGS ----------------------------------------------------------
X_AXIS  = 'percent';
PIPE    = fileparts(fileparts(mfilename('fullpath')));   % repo root
FIG_DIR = fullfile(PIPE,'05_Plots');
if ~exist(FIG_DIR, 'dir'), mkdir(FIG_DIR); end

T_START = 0.53;
T_END   = 1.99;
STANCE_SPLIT_PCT = 60.0;

% Font sizes tuned for single-column readability
PANEL_FS = 11;   % ticks
LABEL_FS = 12;   % axis labels
PHASE_FS = 9;    % STANCE/SWING
LEG_FS   = 9;    % legend

%% --- CASES -------------------------------------------------------------
cases = {
    'Normal',   fullfile(PIPE, '02_NORMAL', '05_FD_NORMAL', 'Results', 'subject01_walk1_normal_Kinematics_q.sto');
    'Weak 20%', fullfile(PIPE, '03_projectGait2392_weakness', 'Results_Forward_weak20_newik', 'subject01_walk1_weak20_Kinematics_q.sto');
    'Weak 30%', fullfile(PIPE, '03_projectGait2392_weakness', 'Results_Forward_weak30_newik', 'subject01_walk1_weak30_Kinematics_q.sto');
    'Weak 50%', fullfile(PIPE, '03_projectGait2392_weakness', 'Results_Forward_weak50_newik', 'subject01_walk1_weak50_Kinematics_q.sto');
};

COLORS = [
    0.75 0.00 0.10;   % Normal  - κόκκινο
    0.55 0.55 0.55;   % Weak20  - γκρι
    0.10 0.40 0.75;   % Weak30  - μπλε
    0.05 0.60 0.20;   % Weak50  - πράσινο
];
LINE_STYLES = {'-', '-', '-', '-'};
LINE_WIDTHS = [2.8, 2.0, 2.2, 2.2];

% 2 φάσεις μόνο — ίδιο με Σχ. 5 (μπλε stance / ροζ swing)
PHASES = {
    'Stance', 0,   60.0, [0.85 0.92 1.00];
    'Swing',  60.0, 100, [1.00 0.90 0.92];
};

%% --- X AXIS ------------------------------------------------------------
if strcmp(X_AXIS,'time')
    p2x  = @(p) T_START + p/100*(T_END - T_START);
    XL   = [T_START T_END];
    XT   = T_START : 0.2 : T_END;
    XLAB = 'Time (s)';
else
    p2x  = @(p) p;
    XL   = [0 100];
    XT   = 0:10:100;
    XLAB = 'Gait Cycle (%)';
end
splitX = p2x(STANCE_SPLIT_PCT);

%% --- LOAD DATA ---------------------------------------------------------
fprintf('=== Loading FWD Kinematics (New IK — 4 levels) ===\n');
nCases = size(cases, 1);
knee  = cell(nCases, 1); t_pct = cell(nCases, 1);
t_sec = cell(nCases, 1); xv    = cell(nCases, 1);

for c = 1:nCases
    fpath = cases{c, 2};
    try
        [t_pct{c}, t_sec{c}, knee{c}] = load_sto_column(fpath, 'knee_angle_r', T_START, T_END);
        dt_c   = mean(diff(t_pct{c})) / 100 * (T_END - T_START);
        knee{c} = smooth_sig(knee{c}, 1/dt_c, 6, 10);
        if strcmp(X_AXIS,'time'), xv{c} = t_sec{c}; else, xv{c} = t_pct{c}; end
        [pk_val, pk_idx] = min(knee{c});
        fprintf('  OK  %-12s | Peak: %.1f deg @ %.0f%% GC\n', cases{c,1}, pk_val, t_pct{c}(pk_idx));
    catch ME
        fprintf('  FAIL %-12s : %s\n', cases{c,1}, ME.message);
        knee{c} = []; t_pct{c} = []; t_sec{c} = []; xv{c} = [];
    end
end

%% --- DEVIATIONS --------------------------------------------------------
fprintf('\n=== Kinematic Deviations vs Normal ===\n');
diff_data = cell(nCases-1, 1); diff_labels = {};
peak_vals = zeros(nCases-1, 1); peak_pct_v = zeros(nCases-1, 1);
norm_k = knee{1}; norm_p = t_pct{1}; norm_x = xv{1};

for c = 2:nCases
    if ~isempty(knee{c})
        w_interp = interp1(t_pct{c}, knee{c}, norm_p, 'linear', 'extrap');
        diff_raw = w_interp - norm_k;
        dt_c = mean(diff(norm_p)) / 100 * (T_END - T_START);
        diff_data{c-1} = smooth_sig(diff_raw, 1/dt_c, 3, 25);
        diff_labels{end+1} = cases{c,1};
        [~, idx] = max(abs(diff_data{c-1}));
        peak_vals(c-1)  = diff_data{c-1}(idx);
        peak_pct_v(c-1) = norm_p(idx);
        fprintf('  %-12s Peak delta = %.2f deg @ %.0f%% GC\n', cases{c,1}, peak_vals(c-1), peak_pct_v(c-1));
    end
end
DEF_COLORS = COLORS(2:end,:);
xoff = 0.015 * (XL(2) - XL(1));

% y-limits
allK = [];
for c = 1:nCases, if ~isempty(knee{c}), allK = [allK; knee{c}]; end, end
y_min1 = floor(min(allK)/10)*10 - 5;
y_max1 = ceil(max(allK)/10)*10  + 5;

all_d = [];
for c = 1:length(diff_data), if ~isempty(diff_data{c}), all_d = [all_d; diff_data{c}]; end, end
y_min2 = min(-5, floor(min(all_d)/5)*5 - 5);
y_max2 = max( 5, ceil(max(all_d)/5)*5  + 5);

%% ====================== PANEL (a) — Knee Angle =========================
fig_a = figure('Color','white','Units','inches','Position',[1 1 3.5 2.7]);
ax_a  = axes(fig_a,'Position',[0.16 0.16 0.80 0.80]); hold(ax_a,'on');
add_phases(ax_a, PHASES, y_min1, y_max1, p2x, splitX);

for c = 1:nCases
    if ~isempty(knee{c})
        plot(ax_a, xv{c}, knee{c}, LINE_STYLES{c}, ...
            'Color', COLORS(c,:), 'LineWidth', LINE_WIDTHS(c)+1.0, ...
            'DisplayName', cases{c,1});
    end
end
text(ax_a, p2x(30), y_max1-(y_max1-y_min1)*0.08, 'STANCE', ...
    'HorizontalAlignment','center','FontSize',PHASE_FS,'FontWeight','bold',...
    'Color',[0.25 0.25 0.25],'FontName','Arial','HandleVisibility','off');
text(ax_a, p2x(82), y_max1-(y_max1-y_min1)*0.08, 'SWING', ...
    'HorizontalAlignment','center','FontSize',PHASE_FS,'FontWeight','bold',...
    'Color',[0.25 0.25 0.25],'FontName','Arial','HandleVisibility','off');
xlabel(ax_a, XLAB,'FontSize',LABEL_FS,'FontName','Arial');
ylabel(ax_a,'Knee Angle (deg)','FontSize',LABEL_FS,'FontName','Arial');
lg_a = legend(ax_a,'Location','southwest','FontSize',LEG_FS,'NumColumns',1);
set(lg_a,'Color','white','TextColor','black','EdgeColor',[0.6 0.6 0.6],'Box','on');
grid(ax_a,'on'); box(ax_a,'on');
xlim(ax_a,XL); ylim(ax_a,[y_min1 y_max1]); xticks(ax_a,XT);
style_ax(ax_a, PANEL_FS);

exportgraphics(fig_a, fullfile(FIG_DIR,'NewIK_knee_4levels_final4_a.pdf'), ...
    'ContentType','vector','BackgroundColor','white');
savefig(fig_a, fullfile(FIG_DIR,'NewIK_knee_4levels_final4_a.fig'));
fprintf('\nSaved: NewIK_knee_4levels_final4_a.pdf + .fig\n');


%% ====================== PANEL (b) — Deviation ==========================
fig_b = figure('Color','white','Units','inches','Position',[1 1 3.5 2.7]);
ax_b  = axes(fig_b,'Position',[0.16 0.16 0.80 0.80]); hold(ax_b,'on');
add_phases(ax_b, PHASES, y_min2, y_max2, p2x, splitX);
yline(ax_b, 0, '-', 'Color',[0.35 0.35 0.35],'LineWidth',1.2,'HandleVisibility','off');

for c = 1:length(diff_data)
    if ~isempty(diff_data{c})
        plot(ax_b, norm_x, diff_data{c}, '-', ...
            'Color', DEF_COLORS(c,:), 'LineWidth', 3.0, ...
            'DisplayName', diff_labels{c});
        if abs(peak_vals(c)) > 1.5
            text(ax_b, p2x(peak_pct_v(c))+xoff, peak_vals(c)-2.0, ...
                sprintf('%.1f\xB0', peak_vals(c)), ...
                'FontSize',9,'FontWeight','bold', ...
                'Color',DEF_COLORS(c,:),'FontName','Arial');
            plot(ax_b, p2x(peak_pct_v(c)), peak_vals(c), 'o', ...
                'Color',DEF_COLORS(c,:),'MarkerSize',6, ...
                'MarkerFaceColor',DEF_COLORS(c,:),'HandleVisibility','off');
        end
    end
end
text(ax_b, p2x(30), y_max2*0.88, 'STANCE', ...
    'HorizontalAlignment','center','FontSize',PHASE_FS,'FontWeight','bold',...
    'Color',[0.25 0.25 0.25],'FontName','Arial','HandleVisibility','off');
text(ax_b, p2x(82), y_max2*0.88, 'SWING', ...
    'HorizontalAlignment','center','FontSize',PHASE_FS,'FontWeight','bold',...
    'Color',[0.25 0.25 0.25],'FontName','Arial','HandleVisibility','off');
xlabel(ax_b, XLAB,'FontSize',LABEL_FS,'FontName','Arial');
ylabel(ax_b,'\Delta\theta (deg)','FontSize',LABEL_FS,'FontName','Arial');
lg_b = legend(ax_b,'Location','southwest','FontSize',LEG_FS,'NumColumns',1);
set(lg_b,'Color','white','TextColor','black','EdgeColor',[0.6 0.6 0.6],'Box','on');
grid(ax_b,'on'); box(ax_b,'on');
xlim(ax_b,XL); ylim(ax_b,[y_min2 y_max2]); xticks(ax_b,XT);
y_range = y_max2 - y_min2;
if y_range <= 20, y_step=5; elseif y_range <= 40, y_step=10; else, y_step=20; end
yticks(ax_b, ceil(y_min2/y_step)*y_step : y_step : floor(y_max2/y_step)*y_step);
style_ax(ax_b, PANEL_FS);

exportgraphics(fig_b, fullfile(FIG_DIR,'NewIK_knee_4levels_final4_b.pdf'), ...
    'ContentType','vector','BackgroundColor','white');
savefig(fig_b, fullfile(FIG_DIR,'NewIK_knee_4levels_final4_b.fig'));
fprintf('Saved: NewIK_knee_4levels_final4_b.pdf + .fig\n');


fprintf('\n=== 2 SEPARATE PANELS SAVED ===\n');
fprintf('  Panel (a): NewIK_knee_4levels_final4_a.pdf\n');
fprintf('  Panel (b): NewIK_knee_4levels_final4_b.pdf\n');

% =========================================================================
%  LOCAL FUNCTIONS
% =========================================================================
function [t_pct, t_sec, data] = load_sto_column(filepath, colname, t_start, t_end)
    import org.opensim.modeling.*;
    storage = Storage(filepath);
    nRows   = storage.getSize();
    time    = zeros(nRows, 1);
    for i = 1:nRows
        time(i) = storage.getStateVector(i-1).getTime();
    end
    col = ArrayDouble();
    storage.getDataColumn(colname, col);
    rawData = zeros(col.getSize(), 1);
    for i = 1:col.getSize()
        rawData(i) = col.get(i-1);
    end
    idx   = time >= t_start & time <= t_end;
    t_sec = time(idx);
    data  = rawData(idx);
    t_pct = (t_sec - t_sec(1)) / (t_sec(end) - t_sec(1)) * 100;
end

function data_f = smooth_sig(data, fs, fc, ma_win)
    Wn = min(fc / (fs/2), 0.99);
    [b, a] = butter(4, Wn, 'low');
    data_f = movmean(filtfilt(b, a, data), ma_win);
end

function add_phases(ax, phases, y_min, y_max, p2x, splitX)
    hold(ax, 'on');
    for p = 1:size(phases, 1)
        p1  = phases{p,2}; p2 = phases{p,3}; clr = phases{p,4};
        x1  = p2x(p1);     x2 = p2x(p2);
        patch(ax, [x1 x2 x2 x1], [y_min y_min y_max y_max], clr, ...
            'FaceAlpha',0.50,'EdgeColor','none','HandleVisibility','off');
    end
    xline(ax, splitX, '-', 'Color',[0.25 0.25 0.25],'LineWidth',1.8,'HandleVisibility','off');
end

function style_ax(ax, FS)
    set(ax,'FontSize',FS,'Color','white','XColor','black','YColor','black', ...
        'GridColor',[0.80 0.80 0.80],'GridAlpha',0.5,'LineWidth',0.9, ...
        'TickDir','out','FontName','Arial','Layer','top');
    leg = findobj(ax,'Type','Legend');
    if ~isempty(leg)
        set(leg,'Color','white','TextColor','black','EdgeColor',[0.60 0.60 0.60],'Box','on');
    end
end