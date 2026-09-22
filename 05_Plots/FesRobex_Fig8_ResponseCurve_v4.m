% =========================================================================
% FesRobex - Fig. 8: Adaptive AAN Non-linear Response Curve  (v4)
%
% ALLAGES ENANTI TOU v3:
%   - 6 Hz zero-phase Butterworth filtering (idio me RRA/CMC pipeline)
%   - Interior peak (5% < GC < 95%) gia apofygi boundary artifacts
%   - ymax: 10 -> 6 Nm
%
% Source: Results_v3_Adaptive / Result_Adaptive_WeakXX.sto
% Output: Fig8_exo_response_curve3.pdf / .png
% =========================================================================

clear; clc; close all;

%% --- Paths ---
ROOT     = fileparts(fileparts(mfilename('fullpath')));   % repo root
dir_moco = [fullfile(ROOT,'04_Moco_AAN','Results_v3_Adaptive', ...
            'Results_adaptive_wc1e+04_mesh0.035_it1000') filesep];
out_dir  = [fullfile(ROOT,'05_Plots') filesep];

files(1).path = fullfile(dir_moco,'Weakness_20\Result_Adaptive_Weak20.sto');
files(1).weakness = 20;
files(2).path = fullfile(dir_moco,'Weakness_30\Result_Adaptive_Weak30.sto');
files(2).weakness = 30;
files(3).path = fullfile(dir_moco,'Weakness_50\Result_Adaptive_Weak50.sto');
files(3).weakness = 50;

OPTIMAL_FORCE = 100;
FC            = 6;      % Hz - idio me RRA/CMC
FORDER        = 4;
GC_LO         = 5;      % interior window
GC_HI         = 95;
YMAX          = 6;
SHOW_RATING   = false;  % true afou trexei to motor selection
HW_RATING     = 5.3;    % 4.57 x 1.17 - PROSORINO

%% --- Load, filter, peak ---
weakness_pct = zeros(1,3);
peak_torque  = zeros(1,3);

for k = 1:3
    [t, tau] = load_moco(files(k).path, OPTIMAL_FORCE);
    tau = abs(tau);

    dt = mean(diff(t));  fs = 1/dt;
    tu = (t(1):dt:t(end))';
    tau_u = interp1(t, tau, tu, 'linear');

    [b,a]   = butter(FORDER/2, FC/(fs/2), 'low');
    tau_fil = filtfilt(b, a, tau_u);
    tau_fil(tau_fil < 0) = 0;

    gc = (tu - tu(1))/(tu(end)-tu(1))*100;
    in = gc > GC_LO & gc < GC_HI;
    [pk, i] = max(tau_fil(in));
    g = gc(in);

    weakness_pct(k) = files(k).weakness;
    peak_torque(k)  = pk;
    fprintf('Weak%2d: filtered interior peak = %.4f Nm at %.1f%% GC\n', ...
            files(k).weakness, pk, g(i));
end

%% =========================================================================
%  RESPONSE CURVE
% =========================================================================
fig1 = figure('Units','centimeters','Position',[2 2 8.8 6.5],'Color','white');
ax1  = axes('Parent', fig1); hold on;

% --- Zone shading ---
fill([18 30 30 18],[0 0 YMAX YMAX],[0.85 0.95 0.85],'EdgeColor','none','FaceAlpha',0.6);
fill([30 40 40 30],[0 0 YMAX YMAX],[0.95 0.92 0.82],'EdgeColor','none','FaceAlpha',0.6);
fill([40 52 52 40],[0 0 YMAX YMAX],[0.97 0.87 0.87],'EdgeColor','none','FaceAlpha',0.6);

if SHOW_RATING
    yline(HW_RATING,'--','Color',[0.6 0.0 0.0],'LineWidth',1.2);
    text(40, HW_RATING+0.13, sprintf('%.1f Nm Hardware Rating', HW_RATING), ...
         'FontSize',7.5,'Color',[0.6 0.0 0.0],'HorizontalAlignment','center');
end

% --- Interpolation (pchip: diatirei ti monotonia) ---
w_interp = linspace(20, 50, 500);
t_interp = pchip(weakness_pct, peak_torque, w_interp);
t_interp(t_interp < 0) = 0;
plot(w_interp, t_interp, '-', 'Color',[0.20 0.30 0.70], 'LineWidth',2.0);

% --- Data points ---
colors_pts = {[0.10 0.60 0.30], [0.85 0.53 0.10], [0.75 0.10 0.10]};
offs_x = [0.8 0.8 -1.4];
for k = 1:3
    scatter(weakness_pct(k), peak_torque(k), 70, colors_pts{k}, ...
            'filled','MarkerEdgeColor','k','LineWidth',0.7);
    text(weakness_pct(k)+offs_x(k), peak_torque(k)+0.26, ...
         sprintf('%.2f Nm', peak_torque(k)), ...
         'FontSize',9,'Color',colors_pts{k},'FontWeight','bold');
end

% --- Zone labels ---
text(24, YMAX*0.90, 'Zone I',       'FontSize',9,'FontWeight','bold','Color',[0.10 0.55 0.25],'HorizontalAlignment','center');
text(24, YMAX*0.830,'Transparency', 'FontSize',8,'Color',[0.10 0.55 0.25],'HorizontalAlignment','center');
text(35, YMAX*0.90, 'Zone II',      'FontSize',9,'FontWeight','bold','Color',[0.70 0.40 0.05],'HorizontalAlignment','center');
text(35, YMAX*0.830,'Progressive',  'FontSize',8,'Color',[0.70 0.40 0.05],'HorizontalAlignment','center');
text(46, YMAX*0.90, 'Zone III',     'FontSize',9,'FontWeight','bold','Color',[0.65 0.08 0.08],'HorizontalAlignment','center');
text(46, YMAX*0.830,'Critical',     'FontSize',8,'Color',[0.65 0.08 0.08],'HorizontalAlignment','center');

text(44.5, YMAX*0.42, {'Tipping','Point'}, 'FontSize',8.5,'Color',[0.65 0.08 0.08], ...
     'FontWeight','bold','HorizontalAlignment','center');

xlim([18 52]); ylim([0 YMAX]);
xlabel('Weakness Level (%)','FontSize',10,'Color','k');
ylabel('Peak Assistive Torque (Nm)','FontSize',10,'Color','k');
set(ax1,'FontSize',9,'Box','on','XGrid','on','YGrid','on', ...
        'GridAlpha',0.25,'GridLineStyle',':','Color','white', ...
        'XColor','k','YColor','k','XTick',[20 30 50]);
set(ax1,'Position',[0.155 0.145 0.815 0.795]);
hold off;

out1 = fullfile(out_dir, 'Fig8_exo_response_curve3');
exportgraphics(fig1,[out1 '.pdf'],'ContentType','vector','BackgroundColor','white');
exportgraphics(fig1,[out1 '.png'],'Resolution',300,'BackgroundColor','white');
fprintf('\nSaved: %s (.pdf + .png)\n', out1);

% =========================================================================
function [time, torque_nm] = load_moco(filepath, optimal_force)
    fid = fopen(filepath, 'r');
    if fid == -1, error('Cannot open: %s', filepath); end
    col_names = {};
    while ~feof(fid)
        line = strtrim(fgetl(fid));
        if strcmpi(line, 'endheader')
            col_names = strsplit(strtrim(fgetl(fid)), '\t');
            break;
        end
    end
    raw = textscan(fid, repmat('%f',1,numel(col_names)), ...
                   'Delimiter','\t','CollectOutput',true);
    fclose(fid);
    data = raw{1};
    time = data(:,1);
    idx  = find(contains(col_names, 'knee_exo_device'));
    if isempty(idx), error('knee_exo_device not found'); end
    torque_nm = data(:,idx) * optimal_force;
end