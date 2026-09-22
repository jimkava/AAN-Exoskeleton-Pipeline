% =========================================================================
% FesRobex - Fig. 9: Temporal Exo Assistance (3 panels)  (v4)
%
% ALLAGES ENANTI TOU v3:
%   - 6 Hz zero-phase Butterworth filtering (idio me RRA/CMC pipeline)
%   - Interior peak (5% < GC < 95%) gia apofygi boundary artifacts
%   - Megethos 8.8 cm (IEEE single column) -> xoris smikrynsi sto LaTeX
%   - Nea oria y ana panel
%
% Source: Results_v3_Adaptive / Result_Adaptive_WeakXX.sto
% Output: fig9_Exo_Assistance.pdf / .png
% =========================================================================

clear; clc; close all;

%% --- Paths ---
ROOT     = fileparts(fileparts(mfilename('fullpath')));   % repo root
dir_moco = [fullfile(ROOT,'04_Moco_AAN','Results_v3_Adaptive', ...
            'Results_adaptive_wc1e+04_mesh0.035_it1000') filesep];
out_dir  = [fullfile(ROOT,'05_Plots') filesep];

files(1).path = fullfile(dir_moco,'Weakness_20\Result_Adaptive_Weak20.sto'); files(1).lv=20;
files(2).path = fullfile(dir_moco,'Weakness_30\Result_Adaptive_Weak30.sto'); files(2).lv=30;
files(3).path = fullfile(dir_moco,'Weakness_50\Result_Adaptive_Weak50.sto'); files(3).lv=50;

OPTIMAL_FORCE = 100;
FC            = 6;     % Hz
FORDER        = 4;
GC_LO         = 5;     % interior window
GC_HI         = 95;
stance_end    = 60;

% --- Oria y ana panel (peaks: 4.57 / 0.23 / 0.03) ---
YMAX_50 = 5.5;
YMAX_30 = 0.30;
YMAX_20 = 0.04;

%% --- Load & filter ---
GC = cell(1,3); TAU = cell(1,3); PK = zeros(1,3); PKGC = zeros(1,3);

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

    GC{k} = gc;  TAU{k} = tau_fil;  PK(k) = pk;  PKGC(k) = g(i);
    fprintf('Weak%2d: peak = %.4f Nm at %.1f%% GC\n', files(k).lv, pk, g(i));
end

c20 = [0.00 0.45 0.10];
c30 = [0.85 0.53 0.10];
c50 = [0.75 0.10 0.10];

%% =========================================================================
%  FIGURE (8.8 cm = IEEE single column)
% =========================================================================
fig = figure('Units','centimeters','Position',[2 2 8.8 11],'Color','white');

% ---------- (a) Weak50 ----------
ax_a = subplot(3,1,1); hold on;
shade(stance_end, YMAX_50);
plot(GC{3}, TAU{3}, '-', 'Color',c50, 'LineWidth',1.6);
plot(PKGC(3), PK(3), 'o','Color',c50,'MarkerFaceColor',c50,'MarkerSize',5);
text(PKGC(3)-24, PK(3)+0.15, sprintf('%.2f Nm', PK(3)), ...
     'FontSize',8,'FontWeight','bold','Color',c50);
xline(stance_end,'--','Color',[0.4 0.4 0.4],'LineWidth',0.8);
text(28, YMAX_50*0.90,'Stance','FontSize',7.5,'FontWeight','bold','Color',[0.15 0.35 0.75],'HorizontalAlignment','center');
text(80, YMAX_50*0.90,'Swing', 'FontSize',7.5,'FontWeight','bold','Color',[0.75 0.15 0.15],'HorizontalAlignment','center');
text(2,  YMAX_50*0.90,'(a) Weak50','FontSize',9,'FontWeight','bold','Color',c50);
xlim([0 100]); ylim([0 YMAX_50]);
ylabel('Torque (Nm)','FontSize',9);
style_ax(ax_a); set(ax_a,'XTickLabel',[]);
set(ax_a,'Position',[0.155 0.695 0.815 0.265]);
hold off;

% ---------- (b) Weak30 ----------
ax_b = subplot(3,1,2); hold on;
shade(stance_end, YMAX_30);
plot(GC{2}, TAU{2}, '-', 'Color',c30, 'LineWidth',1.6);
plot(PKGC(2), PK(2), 'o','Color',c30,'MarkerFaceColor',c30,'MarkerSize',5);
text(PKGC(2)+3, PK(2)+0.012, sprintf('%.2f Nm', PK(2)), ...
     'FontSize',8,'FontWeight','bold','Color',c30);
xline(stance_end,'--','Color',[0.4 0.4 0.4],'LineWidth',0.8);
text(2, YMAX_30*0.90,'(b) Weak30','FontSize',9,'FontWeight','bold','Color',c30);
xlim([0 100]); ylim([0 YMAX_30]);
ylabel('Torque (Nm)','FontSize',9);
style_ax(ax_b); set(ax_b,'XTickLabel',[]);
set(ax_b,'Position',[0.155 0.400 0.815 0.265]);
hold off;

% ---------- (c) Weak20 ----------
ax_c = subplot(3,1,3); hold on;
shade(stance_end, YMAX_20);
plot(GC{1}, TAU{1}, '-', 'Color',c20, 'LineWidth',1.6);
plot(PKGC(1), PK(1), 'o','Color',c20,'MarkerFaceColor',c20,'MarkerSize',5);
text(PKGC(1)+3, PK(1)+0.0016, sprintf('%.3f Nm', PK(1)), ...
     'FontSize',8,'FontWeight','bold','Color',c20);
xline(stance_end,'--','Color',[0.4 0.4 0.4],'LineWidth',0.8);
text(2, YMAX_20*0.90,'(c) Weak20','FontSize',9,'FontWeight','bold','Color',c20);
xlim([0 100]); ylim([0 YMAX_20]);
xlabel('Gait Cycle (%)','FontSize',9);
ylabel('Torque (Nm)','FontSize',9);
style_ax(ax_c);
set(ax_c,'Position',[0.155 0.105 0.815 0.265]);
hold off;

%% --- Save ---
out = fullfile(out_dir, 'fig9_Exo_Assistance');
exportgraphics(fig,[out '.pdf'],'ContentType','vector','BackgroundColor','white');
exportgraphics(fig,[out '.png'],'Resolution',300,'BackgroundColor','white');
fprintf('\nSaved: %s (.pdf + .png)\n', out);

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

function shade(stance_end, ymax)
    fill([0 stance_end stance_end 0],[0 0 ymax ymax],[0.85 0.92 1.00],'EdgeColor','none','FaceAlpha',0.45);
    fill([stance_end 100 100 stance_end],[0 0 ymax ymax],[1.00 0.88 0.88],'EdgeColor','none','FaceAlpha',0.45);
end

function style_ax(ax)
    set(ax,'FontSize',8,'Box','on','XGrid','on','YGrid','on','GridAlpha',0.25,...
        'GridLineStyle',':','Color','white','XColor','k','YColor','k','Layer','top');
end