% ======================================================================= %
%   PROJECT: Gait2392 Simbody Pipeline
%   SCRIPT:  run_KneeVelocity_v2.m
%   FOLDER:  ...\Gait2392_Simbody\05_Plots\
%
%   SKOPOS:  Ypologismos tis goniakis taxytitas tou gonatou ANA SENARIO,
%            apo ta IDIA arxeia pou parigagan to Fig. 3 (NewIK targets).
%
%   DIAFORA APO v1: MONO to §7 (figure). O ypologismos (§1-§6) einai
%            APARALLAKTOS -> ta 396.3/397.7/395.9/397.1 deg/s den allazoun.
%            To plot akolouthei to stil ton Fig. 3/4 tou paper:
%              - shaded Stance (galazio) / Swing (roz)
%              - labels "Stance Phase" / "Swing Phase" mesa sto plot
%              - xromata: Normal kokkino, Weak20 portokali,
%                         Weak30 mple, Weak50 prasino
%
%   FILTRO:  Idio me to run_MotorSelection_v4.m ->
%            butter(FORDER/2) + filtfilt = 4is taxis, zero-phase, 6 Hz.
%            To filtrarisma ginetai PRIN tin paragogisi.
%
%   AUTHOR:  Dimitrios Kavalieros
% ======================================================================= %

clc; clear; close all;
import org.opensim.modeling.*;

%% ===== 1. PATHS =====
PIPE    = fileparts(fileparts(mfilename('fullpath')));   % repo root
FIG_DIR = fullfile(PIPE,'05_Plots');
IK_FILE = fullfile(PIPE,'01_Input_Files','subject01_walk1_ik.mot');
if ~exist(FIG_DIR,'dir'), mkdir(FIG_DIR); end

cases = {
 'Normal',  fullfile(PIPE,'02_NORMAL','05_FD_NORMAL','Results', ...
                     'subject01_walk1_normal_Kinematics_q.sto');
 'Weak20',  fullfile(PIPE,'03_projectGait2392_weakness', ...
                     'Results_Forward_weak20_newik', ...
                     'subject01_walk1_weak20_Kinematics_q.sto');
 'Weak30',  fullfile(PIPE,'03_projectGait2392_weakness', ...
                     'Results_Forward_weak30_newik', ...
                     'subject01_walk1_weak30_Kinematics_q.sto');
 'Weak50',  fullfile(PIPE,'03_projectGait2392_weakness', ...
                     'Results_Forward_weak50_newik', ...
                     'subject01_walk1_weak50_Kinematics_q.sto');
};

%% ===== 2. CONSTANTS =====
T_START = 0.53;   T_END = 1.99;      % idio parathyro me Fig. 3
FC      = 6;      FORDER = 4;        % idio me RRA/CMC kai MotorSelection_v4
GC_LO   = 5;      GC_HI  = 95;       % interior window
GEAR    = 50;                        % Eq. (11)
NG      = 1000;                      % omoiomorfo plegma

% --- xromata IDIA me Fig. 3 / Fig. 4 tou paper ---
COLORS = [0.75 0.00 0.10;    % Normal  - kokkino
          0.90 0.50 0.10;    % Weak20  - portokali
          0.10 0.40 0.75;    % Weak30  - mple
          0.05 0.60 0.20];   % Weak50  - prasino
LABELS = {'Normal','Weak 20%','Weak 30%','Weak 50%'};

fprintf('================================================================================\n');
fprintf('   KNEE ANGULAR VELOCITY | %d Hz zero-phase, interior %d-%d%% GC | G = %d:1\n', ...
        FC, GC_LO, GC_HI, GEAR);
fprintf('================================================================================\n\n');

%% ===== 3. LOOP ANA SENARIO =====
n   = size(cases,1);
gc  = linspace(0,100,NG)';
ANG = nan(NG,n);   OM = nan(NG,n);
R   = struct();

for c = 1:n
    name = cases{c,1};
    if ~isfile(cases{c,2})
        fprintf('  MISSING %-8s : %s\n', name, cases{c,2});  continue;
    end

    [tp, ts, q] = load_sto_column(cases{c,2}, 'knee_angle_r', T_START, T_END);

    % --- BIMA 1: omoiomorfo plegma (to filtfilt einai akyro allios) ---
    tu = linspace(ts(1), ts(end), NG)';
    dt = mean(diff(tu));   fs = 1/dt;
    qu = interp1(ts, q, tu, 'pchip');

    % --- BIMA 2: 6 Hz zero-phase Butterworth (4is taxis meta to filtfilt) ---
    [b,a] = butter(FORDER/2, FC/(fs/2), 'low');
    qf    = filtfilt(b, a, qu);

    % --- BIMA 3: paragogisi PANO sto filtrarismeno sima ---
    om_dps = gradient(qf, tu);              % [deg/s]
    om_rpm = om_dps / 360 * 60;             % [rpm] sto gonato

    ANG(:,c) = qf;   OM(:,c) = om_dps;

    % --- BIMA 4: koryfi entos tou interior window ---
    win = gc > GC_LO & gc < GC_HI;
    tmp = abs(om_dps);  tmp(~win) = NaN;
    [pk_dps, i_pk] = max(tmp);

    % --- gia sygkrisi: koryfi XORIS filtro, se olo ton kyklo ---
    raw_dps = max(abs(gradient(qu, tu)));

    R(c).name     = name;
    R(c).pk_dps   = pk_dps;
    R(c).pk_rads  = pk_dps * pi/180;
    R(c).pk_rpm   = pk_dps / 360 * 60;
    R(c).shaft_rpm= pk_dps / 360 * 60 * GEAR;
    R(c).gc_pk    = gc(i_pk);
    R(c).phase    = ternary(gc(i_pk) < 60, 'stance', 'swing');
    R(c).rms_dps  = rms(om_dps(win));
    R(c).raw_dps  = raw_dps;
    st  = gc > GC_LO & gc < 50;
    tmp2 = om_dps;  tmp2(~st) = NaN;
    [R(c).st_dps, i_st] = min(tmp2);
    R(c).st_gc = gc(i_st);
end

%% ===== 4. ANAFORA =====
fprintf('   %-8s %10s %9s %9s %11s %8s %8s %10s\n', ...
        'Case','peak d/s','rad/s','knee rpm','shaft rpm','@ %GC','phase','raw d/s');
fprintf('   %s\n', repmat('-',1,80));
for c = 1:n
    if isempty(R(c).name), continue; end
    fprintf('   %-8s %10.1f %9.2f %9.2f %11.0f %8.1f %8s %10.1f\n', ...
        R(c).name, R(c).pk_dps, R(c).pk_rads, R(c).pk_rpm, ...
        R(c).shaft_rpm, R(c).gc_pk, R(c).phase, R(c).raw_dps);
end
fprintf('   %s\n\n', repmat('-',1,80));

fprintf('\n   STANCE MINIMUM (loading response, 5-50%% GC)\n');
fprintf('   %s\n', repmat('-',1,50));
for c = 1:n
    if isempty(R(c).name), continue; end
    fprintf('   %-8s %10.1f deg/s  @ %.1f%% GC\n', ...
        R(c).name, R(c).st_dps, R(c).st_gc);
end
fprintf('   %s\n\n', repmat('-',1,50));

%% ===== 5. ELEGXOS: to NORMAL IK pou xrisimopoiei to MotorSelection_v4 =====
if isfile(IK_FILE)
    dm  = importdata(IK_FILE);
    ia  = find(contains(dm.colheaders,'knee_angle_r'), 1);
    tik = dm.data(:,1);
    m   = tik >= T_START & tik <= T_END;
    tu  = linspace(tik(find(m,1)), tik(find(m,1,'last')), NG)';
    aik = interp1(tik, dm.data(:,ia), tu, 'pchip');

    % (a) opos akrivos to kanei to run_MotorSelection_v4.m: XORIS filtro
    spd_v4 = gradient(deg2rad(aik), mean(diff(tu))) * (60/(2*pi));
    rpm_v4 = max(abs(spd_v4));

    % (b) me to idio filtro pou efarmozoume parapano
    fs2   = 1/mean(diff(tu));
    [b2,a2] = butter(FORDER/2, FC/(fs2/2), 'low');
    aikf  = filtfilt(b2, a2, aik);
    spd_f = gradient(aikf, tu) / 360 * 60;
    tmp   = abs(spd_f);  tmp(~(gc > GC_LO & gc < GC_HI)) = NaN;
    rpm_f = max(tmp);

    fprintf('   ELEGXOS ENANTI run_MotorSelection_v4.m (Normal IK)\n');
    fprintf('   %s\n', repmat('-',1,80));
    fprintf('   v4 (afiltrarist., olos o kyklos) : %7.2f rpm knee  ->  %6.0f rpm shaft\n', ...
            rpm_v4, rpm_v4*GEAR);
    fprintf('   me 6 Hz filtro + interior window : %7.2f rpm knee  ->  %6.0f rpm shaft\n', ...
            rpm_f, rpm_f*GEAR);
    fprintf('   diafora                          : %7.1f %%\n\n', ...
            (rpm_f-rpm_v4)/rpm_v4*100);
else
    fprintf('   [!] Den vrethike to %s\n\n', IK_FILE);
end

%% ===== 6. EXAGOGI =====
T = struct2table(R);
writetable(T, fullfile(FIG_DIR,'knee_velocity_summary.csv'));
fprintf('   Saved: knee_velocity_summary.csv\n');

%% ===== 7. FIGURE (single column, IEEE - stil Fig. 3/4) =====
fig = figure('Color','w','Units','inches','Position',[1 1 3.5 2.7]);
ax  = axes(fig,'Position',[0.165 0.165 0.815 0.805]); hold(ax,'on');

% --- oria y: extra xoros sto pano meros gia ta labels ton faseon ---
ymin = min(OM(:));  ymax = max(OM(:));
yl   = [ymin - 0.10*(ymax-ymin), ymax + 0.28*(ymax-ymin)];

% --- shaded background: Stance (galazio) / Swing (roz) ---
patch(ax,[0 60 60 0],[yl(1) yl(1) yl(2) yl(2)],[0.87 0.91 0.97], ...
      'FaceAlpha',1.0,'EdgeColor','none','HandleVisibility','off');
patch(ax,[60 100 100 60],[yl(1) yl(1) yl(2) yl(2)],[0.99 0.90 0.93], ...
      'FaceAlpha',1.0,'EdgeColor','none','HandleVisibility','off');
xline(ax,60,'-','Color',[0.45 0.45 0.45],'LineWidth',1.0,'HandleVisibility','off');
yline(ax,0,'-','Color',[0.55 0.55 0.55],'LineWidth',0.8,'HandleVisibility','off');

% --- labels faseon mesa sto plot (opos Fig. 3/4) ---
ytxt = yl(2) - 0.055*(yl(2)-yl(1));
text(ax,30,ytxt,'Stance Phase','Color',[0.10 0.25 0.65], ...
     'FontWeight','bold','FontSize',9,'FontName','Arial', ...
     'HorizontalAlignment','center','VerticalAlignment','top');
text(ax,80,ytxt,'Swing Phase','Color',[0.75 0.10 0.15], ...
     'FontWeight','bold','FontSize',9,'FontName','Arial', ...
     'HorizontalAlignment','center','VerticalAlignment','top');

% --- kampyles ---
for c = 1:n
    if all(isnan(OM(:,c))), continue; end
    plot(ax, gc, OM(:,c), '-', 'Color', COLORS(c,:), 'LineWidth', 1.6, ...
         'DisplayName', LABELS{c});
end

xlabel(ax,'Gait Cycle (%)','FontSize',10,'FontName','Arial');
ylabel(ax,'Knee Angular Velocity (deg/s)','FontSize',10,'FontName','Arial');
lg = legend(ax,'Location','southwest','FontSize',8,'FontName','Arial');
set(lg,'Color','white','EdgeColor',[0.45 0.45 0.45],'Box','on');
box(ax,'on'); grid(ax,'off');
xlim(ax,[0 100]); ylim(ax,yl); xticks(ax,0:10:100);
set(ax,'FontSize',9,'FontName','Arial','TickDir','out','Layer','top', ...
    'LineWidth',0.8,'XColor',[0.15 0.15 0.15],'YColor',[0.15 0.15 0.15]);

exportgraphics(fig, fullfile(FIG_DIR,'knee_velocity_4levels.pdf'), ...
    'ContentType','vector','BackgroundColor','white');
savefig(fig, fullfile(FIG_DIR,'knee_velocity_4levels.fig'));
fprintf('   Saved: knee_velocity_4levels.pdf + .fig\n\n');


%% ======================= LOCAL FUNCTIONS ===============================
function [t_pct, t_sec, data] = load_sto_column(filepath, colname, t0, t1)
    import org.opensim.modeling.*;
    storage = Storage(filepath);
    nRows   = storage.getSize();
    time    = zeros(nRows,1);
    for i = 1:nRows
        time(i) = storage.getStateVector(i-1).getTime();
    end
    col = ArrayDouble();
    storage.getDataColumn(colname, col);
    raw = zeros(col.getSize(),1);
    for i = 1:col.getSize()
        raw(i) = col.get(i-1);
    end
    idx   = time >= t0 & time <= t1;
    t_sec = time(idx);
    data  = raw(idx);
    t_pct = (t_sec - t_sec(1)) / (t_sec(end) - t_sec(1)) * 100;
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
