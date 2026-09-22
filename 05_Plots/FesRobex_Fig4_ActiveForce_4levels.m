% =========================================================================
% FesRobex — Fig. 4: Active Muscle Fiber Forces (Vastii Group)
% Conditions: Normal, Weak20, Weak30, Weak50 (New IK pipeline)
% Muscles: vas_med_r, vas_int_r, vas_lat_r
% Output: publication-quality PDF for IEEE T-MRB
% =========================================================================

clear; clc; close all;

%% --- Paths ---
ROOT = fileparts(fileparts(mfilename('fullpath')));   % repo root
base = [ROOT filesep];

files.normal = [base '03_projectGait2392_weakness\Results_CMC_normal_newik\subject01_walk1_normal_Actuation_force.sto'];
files.weak20 = [base '03_projectGait2392_weakness\Results_CMC_weak20_newik\subject01_walk1_weak20_Actuation_force.sto'];
files.weak30 = [base '03_projectGait2392_weakness\Results_CMC_weak30_newik\subject01_walk1_weak30_Actuation_force.sto'];
files.weak50 = [base '03_projectGait2392_weakness\Results_CMC_weak50_newik\subject01_walk1_weak50_Actuation_force.sto'];

%% --- Muscles ---
muscles       = {'vas_med_r', 'vas_int_r', 'vas_lat_r'};
muscle_labels = {'Vastus Medialis Force ($F_{\rm active}$)', ...
                 'Vastus Intermedius Force ($F_{\rm active}$)', ...
                 'Vastus Lateralis Force ($F_{\rm active}$)'};

%% --- Colors (paper style) ---
c_normal = [0.00, 0.45, 0.70];   % blue   solid
c_weak20 = [0.85, 0.53, 0.10];   % orange dashed
c_weak30 = [0.80, 0.15, 0.10];   % red    dash-dot
c_weak50 = [0.35, 0.05, 0.05];   % dark red dotted

lw         = 1.6;
smooth_win = 50;
stance_end = 60;

%% --- Load function (full cycle, no crop) ---
function [time_pct, force_data, col_names] = load_sto(filepath)
    fid = fopen(filepath, 'r');
    if fid == -1; error('Cannot open: %s', filepath); end
    col_names = {};
    while ~feof(fid)
        line = strtrim(fgetl(fid));
        if strcmpi(line, 'endheader')
            col_line  = strtrim(fgetl(fid));
            col_names = strsplit(col_line, '\t');
            break;
        end
    end
    raw  = textscan(fid, repmat('%f',1,numel(col_names)), 'Delimiter','\t','CollectOutput',true);
    fclose(fid);
    data = raw{1};
    time = data(:,1);
    time_pct   = (time - time(1)) ./ (time(end) - time(1)) .* 100;
    force_data = data;
end

function idx = find_col(col_names, name)
    idx = find(strcmpi(col_names, name));
    if isempty(idx); error('Column "%s" not found.', name); end
end

%% --- Load ---
fprintf('Loading...\n');
[t_n,  d_n,  cols_n]  = load_sto(files.normal);
[t_20, d_20, cols_20] = load_sto(files.weak20);
[t_30, d_30, cols_30] = load_sto(files.weak30);
[t_50, d_50, cols_50] = load_sto(files.weak50);

fprintf('Normal:  %.3f - %.3f s (%d rows)\n', d_n(1,1),  d_n(end,1),  size(d_n,1));
fprintf('Weak20:  %.3f - %.3f s (%d rows)\n', d_20(1,1), d_20(end,1), size(d_20,1));
fprintf('Weak30:  %.3f - %.3f s (%d rows)\n', d_30(1,1), d_30(end,1), size(d_30,1));
fprintf('Weak50:  %.3f - %.3f s (%d rows)\n', d_50(1,1), d_50(end,1), size(d_50,1));

%% --- Figure ---
fig = figure('Units','centimeters','Position',[2 2 18 15],'Color','white');

for m = 1:3
    ax = subplot(3,1,m);
    hold on;

    col_n  = find_col(cols_n,  muscles{m});
    col_20 = find_col(cols_20, muscles{m});
    col_30 = find_col(cols_30, muscles{m});
    col_50 = find_col(cols_50, muscles{m});

    f_n  = movmean(d_n(:,col_n),   smooth_win);
    f_20 = movmean(d_20(:,col_20), smooth_win);
    f_30 = movmean(d_30(:,col_30), smooth_win);
    f_50 = movmean(d_50(:,col_50), smooth_win);

    ymax = max([f_n; f_20; f_30; f_50]) * 1.15;
    if ymax < 10; ymax = 250; end

    % Shading
    fill([0 stance_end stance_end 0], [0 0 ymax ymax], ...
         [0.85 0.92 1.00], 'EdgeColor','none','FaceAlpha',0.45);
    fill([stance_end 100 100 stance_end], [0 0 ymax ymax], ...
         [1.00 0.88 0.88], 'EdgeColor','none','FaceAlpha',0.45);

    % Lines
    p1 = plot(t_n,  f_n,  '-',  'Color',c_normal,'LineWidth',lw+0.4,'DisplayName','Normal (0%)');
    p2 = plot(t_20, f_20, '--', 'Color',c_weak20, 'LineWidth',lw,    'DisplayName','Weak (20%)');
    p3 = plot(t_30, f_30, '-.', 'Color',c_weak30, 'LineWidth',lw,    'DisplayName','Weak (30%)');
    p4 = plot(t_50, f_50, ':',  'Color',c_weak50, 'LineWidth',lw+0.4,'DisplayName','Weak (50%)');

    xline(stance_end, '--', 'Color',[0.4 0.4 0.4], 'LineWidth',0.8, 'Alpha',0.6);

    text(30, ymax*0.90, 'Stance Phase', 'FontSize',8,'FontWeight','bold', ...
         'Color',[0.15 0.35 0.75],'HorizontalAlignment','center','Interpreter','none');
    text(80, ymax*0.90, 'Swing Phase',  'FontSize',8,'FontWeight','bold', ...
         'Color',[0.75 0.15 0.15],'HorizontalAlignment','center','Interpreter','none');

    xlim([0 100]); ylim([0 ymax]);
    ylabel('Active Force (N)', 'FontSize',8.5,'Color','k');
    title(muscle_labels{m}, 'FontSize',9,'FontWeight','bold','Color','k','Interpreter','latex');

    set(ax,'FontSize',8,'Box','on','XGrid','on','YGrid','on', ...
           'GridAlpha',0.25,'GridLineStyle',':','Color','white','XColor','k','YColor','k');

    if m == 1
        leg = legend([p1 p2 p3 p4], 'Location','northeast','FontSize',7.5,'TextColor','k');
        leg.Box = 'off';
        title(leg, 'Atrophy Scenario','Color','k');
    end

    if m == 3
        xlabel('Gait Cycle (%)', 'FontSize',9,'Color','k');
    else
        set(ax,'XTickLabel',[]);
    end

    hold off;
end

subplot(3,1,1); set(gca,'Position',[0.08 0.68 0.88 0.26]);
subplot(3,1,2); set(gca,'Position',[0.08 0.38 0.88 0.26]);
subplot(3,1,3); set(gca,'Position',[0.08 0.07 0.88 0.26]);

annotation('textbox',[0 0.95 1 0.04], ...
    'String','Vastii Group — Active Muscle Fiber Forces', ...
    'EdgeColor','none','HorizontalAlignment','center', ...
    'FontSize',10,'FontWeight','bold','Color','k');

%% --- Export ---
out_dir  = [fullfile(ROOT,'05_Plots') filesep];
out_file = fullfile(out_dir, 'Fig4_ActiveForce_4levels');

exportgraphics(fig, [out_file '.pdf'], 'ContentType','vector','BackgroundColor','white');
exportgraphics(fig, [out_file '.png'], 'Resolution',300,'BackgroundColor','white');
fprintf('Done! Saved to: %s\n', out_file);
