% =========================================================================
% FesRobex — Fig. 5: Muscle Activation Levels (Vastii Group)
% Conditions: Normal, Weak20, Weak30, Weak50 (New IK pipeline)
% Source: CMC _controls.sto files
% =========================================================================

clear; clc; close all;

%% --- Paths ---
ROOT = fileparts(fileparts(mfilename('fullpath')));   % repo root
base = [fullfile(ROOT,'03_projectGait2392_weakness') filesep];

files.normal = [base 'Results_CMC_normal_newik\subject01_walk1_normal_controls.sto'];
files.weak20 = [base 'Results_CMC_weak20_newik\subject01_walk1_weak20_controls.sto'];
files.weak30 = [base 'Results_CMC_weak30_newik\subject01_walk1_weak30_controls.sto'];
files.weak50 = [base 'Results_CMC_weak50_newik\subject01_walk1_weak50_controls.sto'];

muscles       = {'vas_med_r', 'vas_int_r', 'vas_lat_r'};
muscle_labels = {'Vastus Medialis (vas\_med\_r)', ...
                 'Vastus Intermedius (vas\_int\_r)', ...
                 'Vastus Lateralis (vas\_lat\_r)'};

c_normal = [0.00, 0.45, 0.70];
c_weak20 = [0.85, 0.53, 0.10];
c_weak30 = [0.80, 0.15, 0.10];
c_weak50 = [0.35, 0.05, 0.05];

lw         = 1.6;
smooth_win = 100;
stance_end = 60;
N_PTS      = 1000;  % resample points για ευθυγράμμιση

%% --- Load function με resample ---
function [t_rs, data_rs, col_names] = load_sto(filepath, N)
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
    % Normalize to 0-100%
    t_pct = (time - time(1)) ./ (time(end) - time(1)) .* 100;
    % Resample to N points για alignment
    t_rs   = linspace(0, 100, N)';
    data_rs = zeros(N, size(data,2));
    for c = 1:size(data,2)
        data_rs(:,c) = interp1(t_pct, data(:,c), t_rs, 'linear');
    end
end

function idx = find_col(col_names, name)
    idx = find(strcmpi(col_names, name));
    if isempty(idx); error('Column "%s" not found.', name); end
end

%% --- Load ---
fprintf('Loading...\n');
[t_n,  d_n,  cols_n]  = load_sto(files.normal, N_PTS);
[t_20, d_20, cols_20] = load_sto(files.weak20,  N_PTS);
[t_30, d_30, cols_30] = load_sto(files.weak30,  N_PTS);
[t_50, d_50, cols_50] = load_sto(files.weak50,  N_PTS);

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

    ymax = min(1.0, max([f_n; f_20; f_30; f_50]) * 1.15);
    ymax = max(ymax, 0.3);

    fill([0 stance_end stance_end 0], [0 0 ymax ymax], ...
         [0.85 0.92 1.00], 'EdgeColor','none','FaceAlpha',0.45);
    fill([stance_end 100 100 stance_end], [0 0 ymax ymax], ...
         [1.00 0.88 0.88], 'EdgeColor','none','FaceAlpha',0.45);

    p1 = plot(t_n,  f_n,  '-',  'Color',c_normal,'LineWidth',lw+0.4,'DisplayName','Normal (0%)');
    p2 = plot(t_20, f_20, '--', 'Color',c_weak20, 'LineWidth',lw,    'DisplayName','Weak (20%)');
    p3 = plot(t_30, f_30, '-.', 'Color',c_weak30, 'LineWidth',lw,    'DisplayName','Weak (30%)');
    p4 = plot(t_50, f_50, ':',  'Color',c_weak50, 'LineWidth',lw+0.4,'DisplayName','Weak (50%)');

    xline(stance_end, '--', 'Color',[0.4 0.4 0.4], 'LineWidth',0.8, 'Alpha',0.6);

    if m == 1
        text(30, ymax*0.90, 'Stance Phase', 'FontSize',8,'FontWeight','bold', ...
             'Color',[0.15 0.35 0.75],'HorizontalAlignment','center','Interpreter','none');
        text(80, ymax*0.90, 'Swing Phase', 'FontSize',8,'FontWeight','bold', ...
             'Color',[0.75 0.15 0.15],'HorizontalAlignment','center','Interpreter','none');
    end

    xlim([0 100]); ylim([0 ymax]);
    ylabel('Muscle Activation', 'FontSize',8.5,'Color','k');
    title(muscle_labels{m}, 'FontSize',9,'FontWeight','bold','Color','k','Interpreter','tex');

    set(ax,'FontSize',8,'Box','on','XGrid','on','YGrid','on', ...
           'GridAlpha',0.25,'GridLineStyle',':','Color','white','XColor','k','YColor','k');

    if m == 1
        leg = legend([p1 p2 p3 p4],'Location','northeast','FontSize',7.5,'TextColor','k');
        leg.Box = 'off';
        title(leg,'Condition','Color','k');
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
    'String','Vastii Group — Muscle Activation Levels', ...
    'EdgeColor','none','HorizontalAlignment','center', ...
    'FontSize',10,'FontWeight','bold','Color','k');

out_dir  = [fullfile(ROOT,'05_Plots') filesep];
out_file = fullfile(out_dir, 'Fig5_Activations_4levels');
exportgraphics(fig, [out_file '.pdf'], 'ContentType','vector','BackgroundColor','white');
exportgraphics(fig, [out_file '.png'], 'Resolution',300,'BackgroundColor','white');
fprintf('Done! Saved to: %s\n', out_file);
