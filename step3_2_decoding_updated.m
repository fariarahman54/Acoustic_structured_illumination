% ========================================================================
% ========================================================================
% ASI_Reconstruct_From_IQ_2DH_ClickProfile_GaussianFWHM.m
% Updated: Click-to-select profile location per image + Gaussian FWHM
%
% Uses:
%   - fwhm_gaussian_fit.m
%   - get_lateral_profile.m
%   - get_axial_profile.m
%   - save_fig.m
%
% Before running, change:
%   folderASI, iqFiles, folderPW, iqFilePlaneWave
%   Hfile, figSaveFolder, resultsMatFile
% ========================================================================
clear; clc; close all;

% --- make sure helper functions are on the MATLAB path ---
funcFolder = '/Users/fariarahman/Documents/MATLAB/ASI/Codes/sakib_codes/functions';
if exist(funcFolder,'dir')
    addpath(funcFolder);
else
    error('Functions folder not found: %s', funcFolder);
end

%% ---------------- USER SETTINGS ----------------
folderASI = '/Users/fariarahman/Documents/MATLAB/ASI/Codes/IQData_final/GolayAsi_Merge/4pointSimulation/OnlyASI';


% Auto-detect all 5 ASI pattern files
iqFiles = auto_detect_asi_files(folderASI);

folderPW = '/Users/fariarahman/Documents/MATLAB/ASI/Codes/IQData_final/GolayAsi_Merge/4pointSimulation';
iqFilePlaneWave = 'PlaneWaveIQData_seGVsMk1s3_04092026_003513.dat';

% --- Vantage grid params (wavelength units) ---
Trans.spacing     = 1.48;
Trans.numelements = 128;

P.startDepth = 5;
P.endDepth   = 192;
PData.PDelta = [Trans.spacing, 0, 0.5];

% --- Frequency / speed (for mm conversion) ---
c_mps = 1540;
f0    = 7.6e6;
lambda_mm = (c_mps / f0) * 1e3;

% --- Load 2D decoding patterns H(z,x,p) ---
folderH = '/Users/fariarahman/Documents/MATLAB/ASI/Codes/sakib_codes/Decoding_patterns/diffDeltaD/18mm';
Hfile   = fullfile(folderH, 'DecodingPatterns_H_Apod_Deltad_0.6_Z_18_f0_7.6_delta_374_128pixel.mat');

% --- Display options ---
dyn = 40;
doContrastBoost = true;

% --- Upsample for DISPLAY / profile estimation ---
up = 8;
interpMethod = 'cubic';

% --- Expected target location (used only to pre-zoom the click figures) ---
z_focus_mm = 18.8;
x_focus_mm = -0.4498;

% --- Gaussian FWHM options ---
gaussOpts = {'WithBaseline', true, 'MinPeakFrac', 0.3, 'Plot', false};

% --- Save figures + results here ---
figSaveFolder = '/Users/fariarahman/Documents/MATLAB/ASI/Codes/IQData_final/GolayAsi_Merge/4pointSimulation/OnlyASI/figure';
if ~exist(figSaveFolder,'dir'); mkdir(figSaveFolder); end

matfilesavefolder = '/Users/fariarahman/Documents/MATLAB/ASI/Codes/IQData_final/GolayAsi_Merge/4pointSimulation/OnlyASI';
if ~exist(matfilesavefolder,'dir'); mkdir(matfilesavefolder); end

resultsMatFile = fullfile(matfilesavefolder, 'FWHM_4pointsSim_onlyASI.mat');
%%
% --- Zoom window applied to ALL B-mode images (LR, DEC, SR, PW) ---
% Set to [] to disable zoom (show full image).
zoomWindow.xmin = -1;      % mm, leftmost lateral
zoomWindow.xmax =  2.5;    % mm, rightmost lateral
zoomWindow.ymin = 16;      % mm, top depth (smaller z)
zoomWindow.ymax = 22;      % mm, bottom depth (larger z)
zoomWindow.enable = true;  % set to false to show full images
%% ---------------- DERIVE IQ GRID SIZE ----------------
Nz = round((P.endDepth - P.startDepth) / PData.PDelta(3));
Nx = Trans.numelements;

x_mm = ((0:Nx-1) - (Nx-1)/2) * Trans.spacing * lambda_mm;
z_mm = (P.startDepth + (0:Nz-1) * PData.PDelta(3)) * lambda_mm;

fprintf('Grid: Nz=%d, Nx=%d\n', Nz, Nx);
fprintf('z_mm range: %.2f..%.2f mm | x_mm range: %.2f..%.2f mm\n', ...
    z_mm(1), z_mm(end), x_mm(1), x_mm(end));

%% ---------------- LOAD 2D DECODING PATTERNS H ----------------
S = load(Hfile);
if ~isfield(S,'H'); error('Hfile must contain variable H [Nz x Nx x 5].'); end
H = S.H;

if ~isequal(size(H,1),Nz) || ~isequal(size(H,2),Nx) || size(H,3)~=5
    error('H size mismatch. Got %s, expected [%d x %d x 5].', mat2str(size(H)), Nz, Nx);
end

for p = 1:5
    Hp = H(:,:,p);
    H(:,:,p) = Hp ./ (max(Hp(:)) + eps);
end
disp('Loaded and normalized H(z,x,p).');

%% ---------------- LOAD 5 ASI IQ IMAGES ----------------
B = zeros(Nz, Nx, 5);
B_complex = complex(zeros(Nz, Nx, 5));

for p = 1:5
    fpath = fullfile(folderASI, iqFiles{p});
    if ~exist(fpath,'file'); error('Missing IQ file: %s', fpath); end

    fid = fopen(fpath,'r');
    if fid < 0; error('Could not open file: %s', fpath); end
    raw = fread(fid, inf, 'double'); fclose(fid);

    expectedN = Nz * Nx * 2;
    if numel(raw) ~= expectedN
        error('IQ file size mismatch for p=%d. numel=%d, expected=%d.', p, numel(raw), expectedN);
    end

    raw = reshape(raw, [Nz*Nx, 2]);
    I = reshape(raw(:,1), [Nz, Nx]);
    Q = reshape(raw(:,2), [Nz, Nx]);

    IQp = complex(I, Q);
    B_complex(:,:,p) = IQp;
    B(:,:,p) = abs(IQp);

    fprintf('Loaded ASI p=%d, |IQ| range: [%.3g, %.3g]\n', ...
        p, min(B(:,:,p),[],'all'), max(B(:,:,p),[],'all'));
end

%% ---------------- LOAD PLANE WAVE IQ IMAGE ----------------
pwPath = fullfile(folderPW, iqFilePlaneWave);
if ~exist(pwPath,'file')
    warning('Plane wave file not found: %s', pwPath);
    IQpw_complex = complex(zeros(Nz,Nx));
else
    fid = fopen(pwPath,'r');
    if fid < 0; error('Could not open plane wave file: %s', pwPath); end
    raw = fread(fid, inf, 'double'); fclose(fid);

    expectedN = Nz * Nx * 2;
    if numel(raw) ~= expectedN
        error('Plane wave IQ size mismatch. numel=%d, expected=%d.', numel(raw), expectedN);
    end

    raw = reshape(raw, [Nz*Nx, 2]);
    I = reshape(raw(:,1), [Nz, Nx]);
    Q = reshape(raw(:,2), [Nz, Nx]);
    IQpw_complex = complex(I, Q);

    fprintf('Loaded PlaneWave, |IQ| range: [%.3g, %.3g]\n', ...
        min(abs(IQpw_complex),[],'all'), max(abs(IQpw_complex),[],'all'));
end

%% ---------------- ASI DECODING / RECONSTRUCTION ----------------
LR_complex  = mean(B_complex, 3);

DEC_complex = complex(zeros(Nz,Nx));
for p = 1:5
    DEC_complex = DEC_complex + B_complex(:,:,p) .* H(:,:,p);
end
DEC_complex = DEC_complex / 5;

SR_complex = DEC_complex - LR_complex;

LR_disp  = abs(LR_complex);
DEC_disp = abs(DEC_complex);
SR_disp  = abs(SR_complex);

if doContrastBoost
    SR_disp = SR_disp .* (LR_disp ./ (max(LR_disp(:)) + eps));
end

LRn  = LR_disp  ./ (max(LR_disp(:))  + eps);
DECn = DEC_disp ./ (max(DEC_disp(:)) + eps);
SRn  = SR_disp  ./ (max(SR_disp(:))  + eps);

PW_disp = abs(IQpw_complex);
PWn = PW_disp ./ (max(PW_disp(:)) + eps);

%% ---------------- DISPLAY IMAGES (ORIGINAL GRID) ----------------
fig = figure('Name','LR (original grid)');
imagesc(x_mm, z_mm, 20*log10(LRn + 1e-12));
colormap gray; caxis([-dyn 0]); set(gca,'YDir','reverse');
xlabel('x (mm)'); ylabel('z (mm)'); title('LR (original grid)');
apply_zoom(zoomWindow);
save_fig(fig, figSaveFolder, 'LR_original');

fig = figure('Name','DEC (original grid)');
imagesc(x_mm, z_mm, 20*log10(DECn + 1e-12));
colormap gray; caxis([-dyn 0]); set(gca,'YDir','reverse');
xlabel('x (mm)'); ylabel('z (mm)'); title('DEC (original grid)');
apply_zoom(zoomWindow);
save_fig(fig, figSaveFolder, 'DEC_original');

fig = figure('Name','ASI SR (original grid)');
imagesc(x_mm, z_mm, 20*log10(SRn + 1e-12));
colormap gray; caxis([-dyn 0]); set(gca,'YDir','reverse');
xlabel('x (mm)'); ylabel('z (mm)');
xlim([-2 0.8]); ylim([15 16.3]);
title('ASI SR (original grid)');
apply_zoom(zoomWindow);
save_fig(fig, figSaveFolder, 'SR_original');

fig = figure('Name','PlaneWave (original grid)');
imagesc(x_mm, z_mm, 20*log10(PWn + 1e-12));
colormap gray; caxis([-dyn 0]); set(gca,'YDir','reverse');
xlabel('x (mm)'); ylabel('z (mm)');
xlim([-2 0.8]); ylim([16 19]);
title('PlaneWave (original grid)');apply_zoom(zoomWindow);
save_fig(fig, figSaveFolder, 'PlaneWave_original');

%% ---------------- UPSAMPLE ----------------
x_mm_up = linspace(x_mm(1), x_mm(end), numel(x_mm)*up);
z_mm_up = linspace(z_mm(1), z_mm(end), numel(z_mm)*up);
[Xq, Zq] = meshgrid(x_mm_up, z_mm_up);

LR_up  = interp2(x_mm, z_mm, LRn,  Xq, Zq, interpMethod, 0);  LR_up  = max(real(LR_up),0);
DEC_up = interp2(x_mm, z_mm, DECn, Xq, Zq, interpMethod, 0);  DEC_up = max(real(DEC_up),0);
SR_up  = interp2(x_mm, z_mm, SRn,  Xq, Zq, interpMethod, 0);  SR_up  = max(real(SR_up),0);
PW_up  = interp2(x_mm, z_mm, PWn,  Xq, Zq, interpMethod, 0);  PW_up  = max(real(PW_up),0);

%% ---------------- CLICK TO SELECT PROFILE LOCATION PER IMAGE ----------------
% Each pop-up image lets you click the target center ONCE.
% Uses the reusable function click_select_point.m

% Zoom window for the click figures — centered on expected target
clickZoom = [x_focus_mm - 3, x_focus_mm + 3, z_focus_mm - 3, z_focus_mm + 3];

fprintf('\n=== CLICK-TO-SELECT MODE ===\n');
fprintf('A figure will pop up for each image. Click the TARGET CENTER.\n\n');

[xp_LR, zp_LR, ix_LR, iz_LR] = click_select_point(LR_up, x_mm_up, z_mm_up, ...
                                 'Label','LR',  'Zoom', clickZoom, 'Dyn', dyn);

[xp_SR, zp_SR, ix_SR, iz_SR] = click_select_point(SR_up, x_mm_up, z_mm_up, ...
                                 'Label','ASI', 'Zoom', clickZoom, 'Dyn', dyn);

[xp_PW, zp_PW, ix_PW, iz_PW] = click_select_point(PW_up, x_mm_up, z_mm_up, ...
                                 'Label','PlaneWave', 'Zoom', clickZoom, 'Dyn', dyn);

fprintf('=== Click selection complete ===\n\n');

% Reference indices for display guide lines (ASI peak as representative)
iz_up  = iz_SR;
ix_up  = ix_SR;
z_used = z_mm_up(iz_up);
x_used = x_mm_up(ix_up);

fprintf('Profiles will be extracted through each image''s clicked point.\n');
%% ---------------- LR / ASI / PW UPSAMPLED — SIDE BY SIDE ----------------
fig = figure('Name','LR vs ASI vs PlaneWave (upsampled)', ...
             'Position',[100 100 1500 500]);  % wide figure

% --- LR ---
subplot(1,3,1);
imagesc(x_mm_up, z_mm_up, 20*log10(LR_up + 1e-12));
colormap gray; caxis([-dyn 0]); set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)'); ylabel('z (mm)');
title(sprintf('LR (upsampled x%d)', up));
hold on; yline(z_used,'y-','LineWidth',1.5);xline(x_used,'y-','LineWidth',1.5); hold off;
apply_zoom(zoomWindow);

% --- ASI (SR) ---
subplot(1,3,2);
imagesc(x_mm_up, z_mm_up, 20*log10(SR_up + 1e-12));
colormap gray; caxis([-dyn 0]); set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)'); ylabel('z (mm)');
title(sprintf('ASI SR (upsampled x%d)', up));
hold on; yline(z_used,'y-','LineWidth',1.5);xline(x_used,'y-','LineWidth',1.5); hold off;
apply_zoom(zoomWindow);

% --- PlaneWave ---
subplot(1,3,3);
imagesc(x_mm_up, z_mm_up, 20*log10(PW_up + 1e-12));
colormap gray; caxis([-dyn 0]); set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)'); ylabel('z (mm)');
title(sprintf('Plane Wave (upsampled x%d)', up));
hold on; yline(z_used,'y-','LineWidth',1.5); xline(x_used,'y-','LineWidth',1.5);hold off;
apply_zoom(zoomWindow);

sgtitle('Upsampled B-mode: LR vs ASI vs PlaneWave', ...
        'FontWeight','bold','FontSize',14);

save_fig(fig, figSaveFolder, 'combined_LR_ASI_PW_upsampled');
% DEC (keep separate)
fig = figure('Name','DEC (upsampled)');
imagesc(x_mm_up, z_mm_up, 20*log10(DEC_up + 1e-12));
colormap gray; caxis([-dyn 0]); set(gca,'YDir','reverse');
xlabel('x (mm)'); ylabel('z (mm)');
title(sprintf('DEC (upsampled x%d)', up));
apply_zoom(zoomWindow);
save_fig(fig, figSaveFolder, 'DEC_upsampled_with_profile_lines');
%% ---------------- EXTRACT PROFILES (each through its own clicked point) ----------------
[x_lat, LR_lat] = get_lateral_profile(x_mm_up, LR_up, iz_LR, true);
[~,     SR_lat] = get_lateral_profile(x_mm_up, SR_up, iz_SR, true);
[~,     PW_lat] = get_lateral_profile(x_mm_up, PW_up, iz_PW, true);

[z_ax,  LR_ax] = get_axial_profile(z_mm_up, LR_up, ix_LR, true);
[~,     SR_ax] = get_axial_profile(z_mm_up, SR_up, ix_SR, true);
[~,     PW_ax] = get_axial_profile(z_mm_up, PW_up, ix_PW, true);

%% ---------------- PLOT PROFILES ----------------
fig = figure('Name','Lateral profiles: LR vs ASI vs PlaneWave');
plot(x_lat, LR_lat, 'LineWidth', 2); hold on;
plot(x_lat, SR_lat, 'LineWidth', 2);
plot(x_lat, PW_lat, 'LineWidth', 2);
yline(0.5,'k--','LineWidth',1.2);
xlabel('Lateral x (mm)'); xlim([-1.8 1.5]);
ylabel('Normalized amplitude');
title(sprintf('Lateral profiles (each through its own clicked peak)'));
legend('LR','ASI |SR|','PlaneWave','0.5','Location','best');
save_fig(fig, figSaveFolder, 'profiles_lateral_LR_ASI_PW');

fig = figure('Name','Axial profiles: LR vs ASI vs PlaneWave');
plot(z_ax, LR_ax, 'LineWidth', 2); hold on;
plot(z_ax, SR_ax, 'LineWidth', 2);
plot(z_ax, PW_ax, 'LineWidth', 2);
yline(0.5,'k--','LineWidth',1.2);
xlabel('Depth z (mm)');xlim([18 21])
ylabel('Normalized amplitude');
title(sprintf('Axial profiles'));
legend('LR','ASI |SR|','PlaneWave','0.5','Location','best');
save_fig(fig, figSaveFolder, 'profiles_axial_LR_ASI_PW');

%% ---------------- FWHM (GAUSSIAN FIT) ----------------
% Lateral
[FWHM_LR_lat,  infoLR_lat]  = fwhm_gaussian_fit(x_lat, LR_lat, gaussOpts{:});
[FWHM_ASI_lat, infoASI_lat] = fwhm_gaussian_fit(x_lat, SR_lat, gaussOpts{:});
[FWHM_PW_lat,  infoPW_lat]  = fwhm_gaussian_fit(x_lat, PW_lat, gaussOpts{:});

% Axial
[FWHM_LR_ax,  infoLR_ax]  = fwhm_gaussian_fit(z_ax, LR_ax, gaussOpts{:});
[FWHM_ASI_ax, infoASI_ax] = fwhm_gaussian_fit(z_ax, SR_ax, gaussOpts{:});
[FWHM_PW_ax,  infoPW_ax]  = fwhm_gaussian_fit(z_ax, PW_ax, gaussOpts{:});

% Crossings from fits
xL_LR_lat  = infoLR_lat.xL;   xR_LR_lat  = infoLR_lat.xR;
xL_ASI_lat = infoASI_lat.xL;  xR_ASI_lat = infoASI_lat.xR;
xL_PW_lat  = infoPW_lat.xL;   xR_PW_lat  = infoPW_lat.xR;

zL_LR_ax  = infoLR_ax.xL;   zR_LR_ax  = infoLR_ax.xR;
zL_ASI_ax = infoASI_ax.xL;  zR_ASI_ax = infoASI_ax.xR;
zL_PW_ax  = infoPW_ax.xL;   zR_PW_ax  = infoPW_ax.xR;

fprintf('\n===== FWHM (Gaussian fit) — LATERAL =====\n');
fprintf('LR       : %.4f mm (fit OK: %d, sigma=%.4f, peak x=%.4f mm)\n', ...
    FWHM_LR_lat,  infoLR_lat.success,  infoLR_lat.sigma,  x_mm_up(ix_LR));
fprintf('ASI |SR| : %.4f mm (fit OK: %d, sigma=%.4f, peak x=%.4f mm)\n', ...
    FWHM_ASI_lat, infoASI_lat.success, infoASI_lat.sigma, x_mm_up(ix_SR));
fprintf('PlaneWave: %.4f mm (fit OK: %d, sigma=%.4f, peak x=%.4f mm)\n', ...
    FWHM_PW_lat,  infoPW_lat.success,  infoPW_lat.sigma,  x_mm_up(ix_PW));

fprintf('\n===== FWHM (Gaussian fit) — AXIAL =====\n');
fprintf('LR       : %.4f mm (fit OK: %d, sigma=%.4f, peak z=%.4f mm)\n', ...
    FWHM_LR_ax,  infoLR_ax.success,  infoLR_ax.sigma,  z_mm_up(iz_LR));
fprintf('ASI |SR| : %.4f mm (fit OK: %d, sigma=%.4f, peak z=%.4f mm)\n', ...
    FWHM_ASI_ax, infoASI_ax.success, infoASI_ax.sigma, z_mm_up(iz_SR));
fprintf('PlaneWave: %.4f mm (fit OK: %d, sigma=%.4f, peak z=%.4f mm)\n', ...
    FWHM_PW_ax,  infoPW_ax.success,  infoPW_ax.sigma,  z_mm_up(iz_PW));

%% ---------------- OVERLAY GAUSSIAN FITS ON PROFILES ----------------
fig = figure('Name','Lateral: data + Gaussian fits');
plot(x_lat, LR_lat, 'b-',  'LineWidth', 1.2, 'DisplayName','LR data'); hold on;
plot(x_lat, SR_lat, 'r-',  'LineWidth', 1.2, 'DisplayName','ASI data');
plot(x_lat, PW_lat, 'g-',  'LineWidth', 1.2, 'DisplayName','PW data');
plot(infoLR_lat.xFit,  infoLR_lat.yModel,  'b--', 'LineWidth', 2, 'DisplayName','LR fit');
plot(infoASI_lat.xFit, infoASI_lat.yModel, 'r--', 'LineWidth', 2, 'DisplayName','ASI fit');
plot(infoPW_lat.xFit,  infoPW_lat.yModel,  'g--', 'LineWidth', 2, 'DisplayName','PW fit');
yline(0.5,'k--','HandleVisibility','off');
xlabel('Lateral x (mm)'); xlim([-1.8 1.5]);
ylabel('Normalized amplitude');
title('Lateral: Gaussian fits');
legend('Location','best'); grid on;
save_fig(fig, figSaveFolder, 'profiles_lateral_with_gauss_fits');

fig = figure('Name','Axial: data + Gaussian fits');
plot(z_ax, LR_ax, 'b-', 'LineWidth', 1.2, 'DisplayName','LR data'); hold on;
plot(z_ax, SR_ax, 'r-', 'LineWidth', 1.2, 'DisplayName','ASI data');
plot(z_ax, PW_ax, 'g-', 'LineWidth', 1.2, 'DisplayName','PW data');
plot(infoLR_ax.xFit,  infoLR_ax.yModel,  'b--', 'LineWidth', 2, 'DisplayName','LR fit');
plot(infoASI_ax.xFit, infoASI_ax.yModel, 'r--', 'LineWidth', 2, 'DisplayName','ASI fit');
plot(infoPW_ax.xFit,  infoPW_ax.yModel,  'g--', 'LineWidth', 2, 'DisplayName','PW fit');
yline(0.5,'k--','HandleVisibility','off');
xlabel('Depth z (mm)'); xlim([17 22]);
ylabel('Normalized amplitude');
title('Axial: Gaussian fits');
legend('Location','best'); grid on;
save_fig(fig, figSaveFolder, 'profiles_axial_with_gauss_fits');
%% ---------------- GAUSSIAN-FITTED ONLY PLOTS (clean view) ----------------
% Match colors from the axial profile plot:
%   LR  = blue   (#0072BD, MATLAB default blue)
%   ASI = orange (#D95319, MATLAB default orange)
%   PW  = yellow (#EDB120, MATLAB default yellow)

colLR  = [0.0000 0.4470 0.7410];   % blue
colASI = [0.8500 0.3250 0.0980];   % orange
colPW  = [0.9290 0.6940 0.1250];   % yellow

% ---- Dense x for smooth Gaussian curves ----
gauss = @(p,xx) p(1) .* exp(-(xx - p(2)).^2 ./ (2*p(3)^2)) + p(4) * (numel(p)==4);

% Helper to evaluate the fitted Gaussian on any x
% Pure Gaussian part only (peak normalized to 1, no baseline pedestal)
evalFit = @(info, xx) ...
    exp(-(xx - info.b).^2 ./ (2*info.sigma^2));
% --- LATERAL: Gaussian-fitted only ---
x_dense_lat = linspace(min(x_lat), max(x_lat), 2000);

fig = figure('Name','Lateral: Gaussian-fitted profiles only');
plot(x_dense_lat, evalFit(infoLR_lat,  x_dense_lat), '-', 'Color', colLR,  'LineWidth', 2.5); hold on;
plot(x_dense_lat, evalFit(infoASI_lat, x_dense_lat), '-', 'Color', colASI, 'LineWidth', 2.5);
plot(x_dense_lat, evalFit(infoPW_lat,  x_dense_lat), '-', 'Color', colPW,  'LineWidth', 2.5);
yline(0.5, 'k--', 'LineWidth', 1.2);
xlabel('Lateral x (mm)', 'FontSize', 12);
ylabel('Normalized amplitude', 'FontSize', 12);
xlim([-1.8 1.5]); ylim([0 1.05]);
title('Lateral profile with Gaussian fitted', 'FontWeight','bold','FontSize',13);
legend('LR','ASI |SR|','PlaneWave','0.5','Location','best');
grid on;
save_fig(fig, figSaveFolder, 'profiles_lateral_gaussian_only');

% --- AXIAL: Gaussian-fitted only ---
z_dense_ax = linspace(min(z_ax), max(z_ax), 2000);

fig = figure('Name','Axial: Gaussian-fitted profiles only');
plot(z_dense_ax, evalFit(infoLR_ax,  z_dense_ax), '-', 'Color', colLR,  'LineWidth', 2.5); hold on;
plot(z_dense_ax, evalFit(infoASI_ax, z_dense_ax), '-', 'Color', colASI, 'LineWidth', 2.5);
plot(z_dense_ax, evalFit(infoPW_ax,  z_dense_ax), '-', 'Color', colPW,  'LineWidth', 2.5);
yline(0.5, 'k--', 'LineWidth', 1.2);
xlabel('Depth z (mm)', 'FontSize', 12);
ylabel('Normalized amplitude', 'FontSize', 12);
xlim([18 21]); ylim([0 1.05]);
title('Axial profile with Gaussian fitted', 'FontWeight','bold','FontSize',13);
legend('LR','ASI |SR|','PlaneWave','0.5','Location','best');
grid on;
save_fig(fig, figSaveFolder, 'profiles_axial_gaussian_only');
%% ---------------- SAVE RESULTS MAT ----------------
results = struct();

results.meta.Nz           = Nz;
results.meta.Nx           = Nx;
results.meta.up           = up;
results.meta.interpMethod = interpMethod;
results.meta.fwhmMethod   = 'Gaussian fit (fwhm_gaussian_fit.m)';

% Clicked peak positions
results.clicks.LR.x_mm  = x_mm_up(ix_LR);   results.clicks.LR.z_mm  = z_mm_up(iz_LR);
results.clicks.ASI.x_mm = x_mm_up(ix_SR);   results.clicks.ASI.z_mm = z_mm_up(iz_SR);
results.clicks.PW.x_mm  = x_mm_up(ix_PW);   results.clicks.PW.z_mm  = z_mm_up(iz_PW);

% Lateral FWHM
results.lateral.LR.FWHM_mm    = FWHM_LR_lat;
results.lateral.LR.xL_mm      = xL_LR_lat;
results.lateral.LR.xR_mm      = xR_LR_lat;
results.lateral.LR.sigma_mm   = infoLR_lat.sigma;
results.lateral.LR.fitSuccess = infoLR_lat.success;

results.lateral.ASI.FWHM_mm    = FWHM_ASI_lat;
results.lateral.ASI.xL_mm      = xL_ASI_lat;
results.lateral.ASI.xR_mm      = xR_ASI_lat;
results.lateral.ASI.sigma_mm   = infoASI_lat.sigma;
results.lateral.ASI.fitSuccess = infoASI_lat.success;

results.lateral.PlaneWave.FWHM_mm    = FWHM_PW_lat;
results.lateral.PlaneWave.xL_mm      = xL_PW_lat;
results.lateral.PlaneWave.xR_mm      = xR_PW_lat;
results.lateral.PlaneWave.sigma_mm   = infoPW_lat.sigma;
results.lateral.PlaneWave.fitSuccess = infoPW_lat.success;

% Axial FWHM
results.axial.LR.FWHM_mm    = FWHM_LR_ax;
results.axial.LR.zL_mm      = zL_LR_ax;
results.axial.LR.zR_mm      = zR_LR_ax;
results.axial.LR.sigma_mm   = infoLR_ax.sigma;
results.axial.LR.fitSuccess = infoLR_ax.success;

results.axial.ASI.FWHM_mm    = FWHM_ASI_ax;
results.axial.ASI.zL_mm      = zL_ASI_ax;
results.axial.ASI.zR_mm      = zR_ASI_ax;
results.axial.ASI.sigma_mm   = infoASI_ax.sigma;
results.axial.ASI.fitSuccess = infoASI_ax.success;

results.axial.PlaneWave.FWHM_mm    = FWHM_PW_ax;
results.axial.PlaneWave.zL_mm      = zL_PW_ax;
results.axial.PlaneWave.zR_mm      = zR_PW_ax;
results.axial.PlaneWave.sigma_mm   = infoPW_ax.sigma;
results.axial.PlaneWave.fitSuccess = infoPW_ax.success;

% Full fit info for re-plotting later
results.fitInfo.lateral.LR  = infoLR_lat;
results.fitInfo.lateral.ASI = infoASI_lat;
results.fitInfo.lateral.PW  = infoPW_lat;
results.fitInfo.axial.LR    = infoLR_ax;
results.fitInfo.axial.ASI   = infoASI_ax;
results.fitInfo.axial.PW    = infoPW_ax;

save(resultsMatFile, 'results');
fprintf('\nSaved results to:\n  %s\n', resultsMatFile);

disp('DONE. All images saved, results saved.');
