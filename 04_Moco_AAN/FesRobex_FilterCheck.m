% =========================================================================
% FesRobex - Low-pass filtering of the exoskeleton control profiles
%
% SKOPOS: Oi lyseis tou MocoInverse periexoun talantoseis ypsilis
%   syxnotitas metaxy diadoxikon komvon collocation (px Weak50:
%   1.90 -> 6.69 -> 4.88 -> 0.14 Nm se 4 komvous). To MocoControlGoal
%   poinikopoiei to MEGETHOS ton controls, oxi tin OMALOTITA tous,
%   opote talantoumenes lyseis me to idio oloklirooma kostizoun to idio.
%
%   Edo efarmozetai to IDIO filtro pou xrisimopoieitai idi sto RRA/CMC
%   pipeline (6 Hz, 4th-order zero-phase Butterworth), oste ta
%   anaferomena peaks na einai symvata me tin kinimatiki epexergasia
%   tis Enotitas II.
%
% METHODOS (Table V, both columns):
%   abs(control)*100 -> interp se omoiomorfo grid -> 6 Hz filtfilt
%   -> clip < 0 -> PEAK sto ESOTERIKO parathyro 5-95% GC,
%   RMS se OLO ton kyklo (Table V). To RMS tou esoterikou
%   parathyrou typonetai epipleon, gia sygkrisi.
%   Xoris to esoteriko parathyro, ena boundary artifact sto GC=0%
%   alloionei to Weak30.
%
% EISODOS: SET = 'adaptive' -> Results_v3_Adaptive\...\Result_Adaptive_Weak*.sto
%          SET = 'static'   -> Results_v3_Static\...\Result_Static_Weak*.sto
% EXODOS:  sygkritikos pinakas raw vs filtered + plot elegxou
%
% AUTHOR: Dimitrios Kavalieros
% DATE:   August 2026
% =========================================================================

clear; clc; close all;

%% ===== CONFIG =====
ROOT    = fileparts(fileparts(mfilename('fullpath')));   % repo root (parent of 04_Moco_AAN)
SET = 'static';   % 'adaptive' -> Table V, Adaptive | 'static' -> Table V, Static
switch SET
    case 'adaptive'
        DIR_RES = fullfile(ROOT, '04_Moco_AAN', 'Results_v3_Adaptive', ...
                           'Results_adaptive_wc1e+04_mesh0.035_it1000');
        PREFIX  = 'Result_Adaptive_Weak';
    case 'static'
        DIR_RES = fullfile(ROOT, '04_Moco_AAN', 'Results_v3_Static', ...
                           'Results_paper_wc1e+04_mesh0.035_it1000');
        PREFIX  = 'Result_Static_Weak';
    otherwise
        error('SET must be ''adaptive'' or ''static''.');
end
DIR_OUT = fullfile(ROOT, '05_Plots');
if ~exist(DIR_OUT,'dir'), mkdir(DIR_OUT); end

FC     = 6;      % Hz - idio me to RRA/CMC pipeline
ORDER  = 4;      % 4th-order (2nd-order x2 logo filtfilt)
OPTF   = 100;    % OptimalForce
GC_LO  = 5;      % esoteriko parathyro %GC
GC_HI  = 95;

lv = [20 30 50];

fprintf('================================================================\n');
fprintf('  Low-pass filtering of u_exo  |  %d Hz, %dth-order zero-phase\n', FC, ORDER);
fprintf('  Interior window: %d-%d%% GC  |  SET = %s\n', GC_LO, GC_HI, SET);
fprintf('================================================================\n\n');

res = zeros(3,7);   % [pct rawPeak rawGC filtPeak filtGC rmsFull rmsInterior]
                    % peaks sto 5-95% GC | rmsFull = Table V
T   = cell(1,3);  TAU_RAW = cell(1,3);  TAU_FIL = cell(1,3);  GC = cell(1,3);
MASK = cell(1,3);

for k = 1:3
    f = fullfile(DIR_RES, sprintf('Weakness_%d',lv(k)), ...
                 sprintf('%s%d.sto',PREFIX,lv(k)));
    assert(exist(f,'file')>0, 'MISSING: %s', f);

    d   = importdata(f);
    idx = find(contains(d.colheaders,'knee_exo_device'),1);
    t   = d.data(:,1);
    tau = abs(d.data(:,idx)) * OPTF;          % abs PRIN to filtro

    % --- Omoiomorfo xronovima gia to filtro ---
    dt  = mean(diff(t));
    fs  = 1/dt;
    tu  = (t(1):dt:t(end))';
    tau_u = interp1(t, tau, tu, 'linear');

    % --- Zero-phase Butterworth ---
    [b,a]   = butter(ORDER/2, FC/(fs/2), 'low');
    tau_fil = filtfilt(b, a, tau_u);
    tau_fil(tau_fil < 0) = 0;

    gc = (tu - tu(1))/(tu(end)-tu(1))*100;

    % --- ESOTERIKO parathyro 5-95% GC ---
    m   = (gc >= GC_LO) & (gc <= GC_HI);
    gcm = gc(m);

    [pkR, iR] = max(tau_u(m));
    [pkF, iF] = max(tau_fil(m));

    res(k,:) = [lv(k), pkR, gcm(iR), pkF, gcm(iF), rms(tau_fil), rms(tau_fil(m))];

    T{k} = tu;  TAU_RAW{k} = tau_u;  TAU_FIL{k} = tau_fil;  GC{k} = gc;
    MASK{k} = m;

    fprintf('Weak%2d  |  fs = %.1f Hz  |  n = %d samples\n', lv(k), fs, numel(tu));
end

%% ===== SYGKRITIKOS PINAKAS =====
fprintf('\n----------------------------------------------------------------\n');
fprintf('%-8s %-12s %-10s %-14s %-10s %-14s %-14s\n', ...
        'Weak','Raw peak','at %GC','Filtered peak','at %GC','RMS full','RMS 5-95%');
fprintf('----------------------------------------------------------------\n');
for k = 1:3
    fprintf('%-8d %-12.4f %-10.1f %-14.4f %-10.1f %-14.4f %-14.4f\n', ...
            res(k,1), res(k,2), res(k,3), res(k,4), res(k,5), res(k,6), res(k,7));
end
fprintf('----------------------------------------------------------------\n');
fprintf('Table V = Filtered peak (5-95%% GC) + RMS full cycle\n');
fprintf('Meiosi peak logo filtrarismatos: %.1f%% / %.1f%% / %.1f%%\n', ...
        100*(1-res(:,4)./res(:,2)));

%% ===== ELEGXOS OMALOTITAS =====
fprintf('\nElegxos omalotitas (max metavoli metaxy diadoxikon komvon):\n');
for k = 1:3
    dR = max(abs(diff(TAU_RAW{k})));
    dF = max(abs(diff(TAU_FIL{k})));
    fprintf('  Weak%2d  raw: %.3f Nm/step   filtered: %.3f Nm/step\n', ...
            lv(k), dR, dF);
end

%% ===== PLOT ELEGXOU =====
fig = figure('Units','centimeters','Position',[2 2 18 15],'Color','white');
cols = {[0.00 0.45 0.10],[0.85 0.53 0.10],[0.75 0.10 0.10]};

for k = 3:-1:1
    sp = 4-k;
    ax = subplot(3,1,sp); hold on;
    plot(GC{k}, TAU_RAW{k}, '-', 'Color',[0.65 0.65 0.65], 'LineWidth',0.9);
    plot(GC{k}, TAU_FIL{k}, '-', 'Color',cols{k}, 'LineWidth',2.0);
    pkF = res(k,4);  gcF = res(k,5);
    plot(gcF, pkF, 'o','Color',cols{k},'MarkerFaceColor',cols{k},'MarkerSize',6);
    text(gcF+2, pkF, sprintf('%.2f Nm', pkF), ...
         'FontSize',8,'FontWeight','bold','Color',cols{k});
    xline(GC_LO,':','Color',[0.4 0.4 0.4],'LineWidth',0.8);
    xline(GC_HI,':','Color',[0.4 0.4 0.4],'LineWidth',0.8);
    xline(60,'--','Color',[0.4 0.4 0.4],'LineWidth',0.8);
    title(sprintf('Weak%d%%  (grey: raw, colour: %d Hz filtered, peak in %d-%d%% GC)', ...
          lv(k), FC, GC_LO, GC_HI), 'FontSize',9,'FontWeight','normal');
    ylabel('Torque (Nm)','FontSize',9);
    if sp==3, xlabel('Gait Cycle (%)','FontSize',9); end
    xlim([0 100]); grid on; box on;
    set(ax,'FontSize',8,'GridLineStyle',':','GridAlpha',0.25);
    hold off;
end

out = fullfile(DIR_OUT, sprintf('FilterCheck_%dHz_%s', FC, SET));
exportgraphics(fig,[out '.png'],'Resolution',200,'BackgroundColor','white');
fprintf('\nSaved: %s.png\n', out);

save(fullfile(DIR_RES,'FilteredPeaks.mat'),'res','FC','ORDER','GC_LO','GC_HI');
fprintf('Saved: %s\n', fullfile(DIR_RES,'FilteredPeaks.mat'));
