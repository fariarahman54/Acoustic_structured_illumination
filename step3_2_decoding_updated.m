% ========================================================================
% ASI_Reconstruct_From_IQ_2DH_ONLY_BATCHSAVE.m
%updated at 02_10_2026
% Updated per your requests:
%  1) FWHM is an independent function (local_fwhm.m) -> called here
%  2) ONLY uses 2D decoding patterns H(z,x,p). Pattern1D removed.
%  3) Separate functions for lateral/axial profile extraction -> called here
%  4) Images include row/column guide lines used for profiles
%  5) Also loads ONE plane-wave IQ (.dat) and computes its lateral/axial profiles
%  6) Saves ALL figures to a designated folder
%  7) Saves FWHM results (LR, ASI, PlaneWave) into a .mat
%
% IMPORTANT: Put the helper functions (listed at the end) as separate files:
%   - local_fwhm.m
%   - get_lateral_profile.m
%   - get_axial_profile.m
%   - save_fig.m
% change folderASI,iqFiles,folderPW, iqFilePlaneWave, name, plane wave file,folderH 
% change Hfile, figSaveFolder, resultsMatFile
%change z_focus_mm = 15; & x_focus_mm = 0;here the lateral & axial profile
%is being created 

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
%PT1
% folderASI = '/Users/fariarahman/Documents/MATLAB/Acoustic Structured illumination/Codes/sakib_codes/fix_steps/GolayAsi_Merge/GolayASI/iqdata';
% 
% iqFiles={
%     'IQData_SimulationASIpattern1Apod_Deltad_0.8_Z_18_f0_7.6_delta_04082026_111404.dat'
%     'IQData_SimulationASIpattern2Apod_Deltad_0.8_Z_18_f0_7.6_delta_04082026_111419.dat'
%     'IQData_SimulationASIpattern3Apod_Deltad_0.8_Z_18_f0_7.6_delta_04082026_111438.dat'
%     'IQData_SimulationASIpattern4Apod_Deltad_0.8_Z_18_f0_7.6_delta_04082026_111453.dat'
%     'IQData_SimulationASIpattern5Apod_Deltad_0.8_Z_18_f0_7.6_delta_04082026_111503.dat'
%     }
% 
folderASI = '/Users/fariarahman/Documents/MATLAB/ASI/Codes/IQData_final/DiffDeltad/18mm/Simulation/0.0mm_delta_target';

iqFiles={
    'IQData_SimulationASIpattern1Apod_Deltad_0.0_Z_18_f0_7.6_delta_03262026_192934.dat'
    'IQData_SimulationASIpattern2Apod_Deltad_0.0_Z_18_f0_7.6_delta_03262026_192942.dat'
    'IQData_SimulationASIpattern3Apod_Deltad_0.0_Z_18_f0_7.6_delta_03262026_192951.dat'
    'IQData_SimulationASIpattern4Apod_Deltad_0.0_Z_18_f0_7.6_delta_03262026_193001.dat'
    'IQData_SimulationASIpattern5Apod_Deltad_0.0_Z_18_f0_7.6_delta_03262026_193009.dat'
    }


 folderPW = '/Users/fariarahman/Documents/MATLAB/ASI/Codes/IQData_final/DiffDeltad/18mm/Simulation/PlaneWave';
 iqFilePlaneWave = 'PlaneWaveIQData_seGVsMk1s3_04082026_224644.dat'; % <-- CHANGE THIS NAME


% --- Vantage grid params (wavelength units) ---
Trans.spacing     = 1.48;   % [wavelengths]
Trans.numelements = 128;

P.startDepth = 5;           % [wavelengths]
P.endDepth   = 192;         % [wavelengths]
PData.PDelta = [Trans.spacing, 0, 0.5]; % [wavelengths] lateral, -, axial

% --- Frequency / speed (for mm conversion) ---
c_mps = 1540;
f0    = 7.6e6;
lambda_mm = (c_mps / f0) * 1e3;

% --- Load 2D decoding patterns H(z,x,p) ---
folderH = '/Users/fariarahman/Documents/MATLAB/ASI/Codes/sakib_codes/Decoding_patterns/diffDeltaD/18mm';
Hfile   = fullfile(folderH, 'DecodingPatterns_H_Apod_Deltad_0.0_Z_18_f0_7.6_delta_374_128pixel.mat');
% --- Display options ---
dyn = 40;                % dB range for B-mode display
doContrastBoost = true;  % your previous option

% --- Upsample for DISPLAY / profile estimation ---
up = 8;
interpMethod = 'cubic';

% --- Where to measure profiles ---
% z_focus_mm = 25.53;   % lateral profile depth
% x_focus_mm = -0.1499;    % axial profile lateral location

% z_focus_mm = 15.09;   % lateral profile depth
% x_focus_mm = -0.1499;    % axial profile lateral location

z_focus_mm = 18.05;   % lateral profile depth
x_focus_mm = -0.0186;
% 0.1499;    % axial profile lateral location
% z_focus_mm = 20.97;   % lateral profile depth
% x_focus_mm = 0.749;
% z_focus_mm = 24.31;   % lateral profile depth
% x_focus_mm = -1.049;
% z_focus_mm = 25.22;   % lateral profile depth
% x_focus_mm = -0.1499;    % axial profile lateral location

% z_focus_mm = 30.26;   % lateral profile depth
% x_focus_mm = -0.1499;    % axial profile lateral location

% z_focus_mm = 35.5618;   % lateral profile depth
% x_focus_mm = -0.1499;  

% --- Save all figures + results here ---
% figSaveFolder = '/Users/fariarahman/Documents/MATLAB/Acoustic Structured illumination/Codes/sakib_codes/fix_steps/Matfiles/DiffDeltadStep3figure/18mm/Simulation/random';
% if ~exist(figSaveFolder,'dir'); mkdir(figSaveFolder); end

figSaveFolder = '/Users/fariarahman/Documents/MATLAB/ASI/Codes/IQData_final/DiffDeltad/18mm/Simulation/0.0mm_delta_target/figure';
if ~exist(figSaveFolder,'dir'); mkdir(figSaveFolder); end



matfilesavefolder = '/Users/fariarahman/Documents/MATLAB/ASI/Codes/IQData_final/DiffDeltad/18mm/Simulation/0.0mm_delta_target'
if ~exist(matfilesavefolder,'dir');
    mkdir(matfilesavefolder); 
end
% resultsMatFile = fullfile(matfilesavefolder, 'FWHM_SNRCTR_results_LR_ASI_PlaneWave_2p0delta_d.mat');
resultsMatFile = fullfile(matfilesavefolder, 'FWHM_LR_onlyASI_PlaneWavetest.mat');

%% ---------------- DERIVE IQ GRID SIZE ----------------
Nz = round((P.endDepth - P.startDepth) / PData.PDelta(3));  % keep your convention
Nx = Trans.numelements;

x_mm = ((0:Nx-1) - (Nx-1)/2) * Trans.spacing * lambda_mm;                % 1xNx
z_mm = (P.startDepth + (0:Nz-1) * PData.PDelta(3)) * lambda_mm;          % 1xNz

fprintf('Grid: Nz=%d, Nx=%d\n', Nz, Nx);
fprintf('z_mm range: %.2f..%.2f mm | x_mm range: %.2f..%.2f mm\n', z_mm(1), z_mm(end), x_mm(1), x_mm(end));

%% ---------------- LOAD 2D DECODING PATTERNS H ----------------
S = load(Hfile);
if ~isfield(S,'H'); error('Hfile must contain variable H [Nz x Nx x 5].'); end
H = S.H;

if ~isequal(size(H,1),Nz) || ~isequal(size(H,2),Nx) || size(H,3)~=5
    error('H size mismatch. Got %s, expected [%d x %d x 5].', mat2str(size(H)), Nz, Nx);
end

% Normalize each H pattern to max=1
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

    expectedN = Nz * Nx * 2; % each pixel has 2 numbers (I(1),Q(1)...
    if numel(raw) ~= expectedN
        error(['IQ file size mismatch for p=%d.\nnumel(raw)=%d, expected=%d.\nFix Nz/Nx.'], p, numel(raw), expectedN);
    end

    raw = reshape(raw, [Nz*Nx, 2]); % each row has 2 colums  I and Q
    I = reshape(raw(:,1), [Nz, Nx]); % first column
    Q = reshape(raw(:,2), [Nz, Nx]);

    IQp = complex(I, Q);
    B_complex(:,:,p) = IQp; % why dont use complex IQ data 
    B(:,:,p) = abs(IQp);

    fprintf('Loaded ASI p=%d, |IQ| range: [%.3g, %.3g]\n', p, min(B(:,:,p),[],'all'), max(B(:,:,p),[],'all'));
end

%% ---------------- LOAD PLANE WAVE IQ IMAGE ----------------
pwPath = fullfile(folderPW, iqFilePlaneWave);
if ~exist(pwPath,'file')
    warning('Plane wave file not found: %s\nSet iqFilePlaneWave correctly.', pwPath);
    IQpw_complex = complex(zeros(Nz,Nx));
else
    fid = fopen(pwPath,'r');
    if fid < 0; error('Could not open plane wave file: %s', pwPath); end
    raw = fread(fid, inf, 'double'); fclose(fid);

    expectedN = Nz * Nx * 2;
    if numel(raw) ~= expectedN
        error(['Plane wave IQ size mismatch.\nnumel(raw)=%d, expected=%d.\nFix Nz/Nx.'], numel(raw), expectedN);
    end

    raw = reshape(raw, [Nz*Nx, 2]); 
    I = reshape(raw(:,1), [Nz, Nx]);
    Q = reshape(raw(:,2), [Nz, Nx]);
    IQpw_complex = complex(I, Q);

    fprintf('Loaded PlaneWave, |IQ| range: [%.3g, %.3g]\n', ...
        min(abs(IQpw_complex),[],'all'), max(abs(IQpw_complex),[],'all'));
end

%% ---------------- SHOW 5 RAW PATTERNS (SAVE) ----------------
% fig = figure('Name','All 5 raw pattern images');
% for p = 1:5
%     subplot(2,3,p);
%     img = B(:,:,p);
%     img_n = img ./ (max(img(:)) + eps);
%     imagesc(x_mm, z_mm, 20*log10(img_n + 1e-12));
%     colormap gray; caxis([-dyn 0]); set(gca,'YDir','reverse');
%     xlabel('x (mm)'); ylabel('z (mm)');
%     title(sprintf('Pattern %d', p));
% end
% sgtitle('5 acquired ASI frames (before LR/DEC/SR)');
% save_fig(fig, figSaveFolder, 'raw_patterns_1to5');

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

% Normalize for display
LRn  = LR_disp  ./ (max(LR_disp(:))  + eps);
DECn = DEC_disp ./ (max(DEC_disp(:)) + eps);
SRn  = SR_disp  ./ (max(SR_disp(:))  + eps);

PW_disp = abs(IQpw_complex);
PWn = PW_disp ./ (max(PW_disp(:)) + eps); %It rescales the plane-wave image so its brightest pixel = 1.



% --------- Profile indices on ORIGINAL grid (before upsample) ----------
[~, iz0] = min(abs(z_mm - z_focus_mm));   % row for lateral profile
[~, ix0] = min(abs(x_mm - x_focus_mm));   % col for axial profile

z_used0 = z_mm(iz0); % iz0 is index , z_used0 means what is the value in that index
x_used0 = x_mm(ix0);

fprintf('ORIGINAL grid profiles at: z=%.3f mm (iz0=%d), x=%.3f mm (ix0=%d)\n', ...
    z_used0, iz0, x_used0, ix0);

% LR (original)
fig = figure('Name','LR (original grid)');
imagesc(x_mm, z_mm, 20*log10(LRn + 1e-12));
colormap gray; caxis([-dyn 0]); set(gca,'YDir','reverse');
xlabel('x (mm)'); 
%xlim([-1.5 1.2]);
ylabel('z (mm)');
%ylim([20 30]);
title('LR (original grid)');
hold on; 
%xline(x_used0,'y-','LineWidth',1.5); yline(z_used0,'y-','LineWidth',1.5); hold off;
save_fig(fig, figSaveFolder, 'LR_original_with_profile_lines');

% DEC (original)
fig = figure('Name','DEC (original grid)');
imagesc(x_mm, z_mm, 20*log10(DECn + 1e-12));
colormap gray; caxis([-dyn 0]); set(gca,'YDir','reverse');
xlabel('x (mm)'); 
%xlim([-1.5 1.2]);
ylabel('z (mm)');
%ylim([20 30]);
title('DEC (original grid)');
hold on; 
%xline(x_used0,'y-','LineWidth',1.5); yline(z_used0,'y-','LineWidth',1.5); hold off;
save_fig(fig, figSaveFolder, 'DEC_original_with_profile_lines');

% SR (original)
fig = figure('Name','Golay Coded structured illumination(original grid)');
imagesc(x_mm, z_mm, 20*log10(SRn + 1e-12));
colormap gray; caxis([-dyn 0]); set(gca,'YDir','reverse');
xlabel('x (mm)'); 

ylabel('z (mm)');
 xlim([-2 0.8]);
 ylim([15 16.3]);
title('ASI SR (original grid)');
hold on; 
%%xline(x_used0,'y-','LineWidth',1.5); yline(z_used0,'y-','LineWidth',1.5); hold off;
save_fig(fig, figSaveFolder, 'SR_original_with_profile_lines');

% Plane Wave (original)
fig = figure('Name','PlaneWave (original grid)');
imagesc(x_mm, z_mm, 20*log10(PWn + 1e-12));
colormap gray; caxis([-dyn 0]); set(gca,'YDir','reverse');
xlabel('x (mm)'); 
ylabel('z (mm)');
 xlim([-2 0.8]);
 ylim([16 19]);
title('Plane Wave (original grid)');
hold on; 
%%xline(x_used0,'y-','LineWidth',1.5); yline(z_used0,'y-','LineWidth',1.5); hold off;
save_fig(fig, figSaveFolder, 'PlaneWave_original_with_profile_lines');





%% ---------------- UPSAMPLE (FOR DISPLAY + SMOOTHER PROFILE) ----------------
x_mm_up = linspace(x_mm(1), x_mm(end), numel(x_mm)*up); % up=8
z_mm_up = linspace(z_mm(1), z_mm(end), numel(z_mm)*up);
[Xq, Zq] = meshgrid(x_mm_up, z_mm_up);

LR_up  = interp2(x_mm, z_mm, LRn,  Xq, Zq, interpMethod, 0);  LR_up  = max(real(LR_up),0);
DEC_up = interp2(x_mm, z_mm, DECn, Xq, Zq, interpMethod, 0);  DEC_up = max(real(DEC_up),0);
SR_up  = interp2(x_mm, z_mm, SRn,  Xq, Zq, interpMethod, 0);  SR_up  = max(real(SR_up),0);

PW_up  = interp2(x_mm, z_mm, PWn,  Xq, Zq, interpMethod, 0);  PW_up  = max(real(PW_up),0);

%% ---------------- PROFILE INDICES (ON UPSAMPLED GRID) ----------------
[~, iz_up] = min(abs(z_mm_up - z_focus_mm));     % lateral profile row
[~, ix_up] = min(abs(x_mm_up - x_focus_mm));     % axial profile column
z_used = z_mm_up(iz_up);
x_used = x_mm_up(ix_up);

fprintf('\nProfiles taken at:\n  Lateral @ z=%.3f mm (row iz_up=%d)\n  Axial   @ x=%.3f mm (col ix_up=%d)\n', ...
    z_used, iz_up, x_used, ix_up);

%% ---------------- DISPLAY LR / DEC / SR with guide lines (SAVE) ----------------
% LR
fig = figure('Name','LR (upsampled)');
imagesc(x_mm_up, z_mm_up, 20*log10(LR_up + 1e-12)); colormap gray; caxis([-dyn 0]);
set(gca,'YDir','reverse'); xlabel('x (mm)');
%xlim([-5 5]);
ylabel('z (mm)');
%ylim([20 30]);
title(sprintf('LR (upsampled x%d)', up));
hold on;
%xline(x_used,'y-','LineWidth',1.5);   % axial column
yline(z_used,'y-','LineWidth',1.5);   % lateral row
hold off;
save_fig(fig, figSaveFolder, 'LR_upsampled_with_profile_lines');

% DEC
fig = figure('Name','DEC (upsampled)');
imagesc(x_mm_up, z_mm_up, 20*log10(DEC_up + 1e-12)); colormap gray; caxis([-dyn 0]);
set(gca,'YDir','reverse'); xlabel('x (mm)'); 
% xlim([-5 5]);
ylabel('z (mm)');
% ylim([20 30]);
title(sprintf('DEC (upsampled x%d)', up));
hold on; %xline(x_used,'y-','LineWidth',1.5); yline(z_used,'y-','LineWidth',1.5); hold off;
save_fig(fig, figSaveFolder, 'DEC_upsampled_with_profile_lines');

% SR
fig = figure('Name','ASI SR (upsampled)');
imagesc(x_mm_up, z_mm_up, 20*log10(SR_up + 1e-12)); colormap gray; caxis([-dyn 0]);
set(gca,'YDir','reverse'); xlabel('x (mm)'); 
% xlim([-5 5]);
ylabel('z (mm)');%ylim([20 30]);
title(sprintf('ASI SR (upsampled x%d)', up));
hold on; 
%xline(x_used,'y-','LineWidth',1.5); yline(z_used,'y-','LineWidth',1.5); 
hold off;
save_fig(fig, figSaveFolder, 'SR_upsampled_with_profile_lines');

% Plane wave
fig = figure('Name','PlaneWave (upsampled)');
imagesc(x_mm_up, z_mm_up, 20*log10(PW_up + 1e-12)); colormap gray; clim([-dyn 0]);
set(gca,'YDir','reverse'); xlabel('x (mm)');
%xlim([-1.5 1.2]);
ylabel('z (mm)');%ylim([25 25.4]);
title(sprintf('Plane Wave (upsampled x%d)', up));
hold on; 
%xline(x_used,'y-','LineWidth',1.5); yline(z_used,'y-','LineWidth',1.5); hold off;
save_fig(fig, figSaveFolder, 'PlaneWave_upsampled_with_profile_lines');

%% ---------------- EXTRACT PROFILES (CALL FUNCTIONS) ----------------
% Lateral profiles at z_used
[x_lat, LR_lat] = get_lateral_profile(x_mm_up, LR_up, iz_up, true);
[~,     SR_lat] = get_lateral_profile(x_mm_up, SR_up, iz_up, true);
[~,     PW_lat] = get_lateral_profile(x_mm_up, PW_up, iz_up, true);

% Axial profiles at x_used
[z_ax,  LR_ax] = get_axial_profile(z_mm_up, LR_up, ix_up, true);
[~,     SR_ax] = get_axial_profile(z_mm_up, SR_up, ix_up, true);
[~,     PW_ax] = get_axial_profile(z_mm_up, PW_up, ix_up, true);

%% ---------------- PLOT PROFILES (SAVE) ----------------
% Lateral comparison
fig = figure('Name','Lateral profiles: LR vs ASI vs PlaneWave');
plot(x_lat, LR_lat, 'LineWidth', 2); hold on;
plot(x_lat, SR_lat, 'LineWidth', 2);
plot(x_lat, PW_lat, 'LineWidth', 2);
yline(0.5,'k--','LineWidth',1.2);
xlabel('Lateral x (mm)');xlim([-1.8 1.5]); 
ylabel('Normalized amplitude');
title(sprintf('Lateral profiles at z=%.3f mm', z_used));
legend('LR','ASI |SR|','PlaneWave','0.5', 'Location','best');
% legend('LR','ASI |SR|', 'Location','best');

save_fig(fig, figSaveFolder, 'profiles_lateral_LR_ASI_PW');

% Axial comparison
fig = figure('Name','Axial profiles: LR vs ASI vs PlaneWave');
plot(z_ax, LR_ax, 'LineWidth', 2); hold on;
plot(z_ax, SR_ax, 'LineWidth', 2);
plot(z_ax, PW_ax, 'LineWidth', 2);
yline(0.5,'k--','LineWidth',1.2);
xlabel('Depth z (mm)'); xlim([17 19]);
ylabel('Normalized amplitude');
title(sprintf('Axial profiles at x=%.3f mm', x_used));
legend('LR','ASI |SR|','PlaneWave','0.5', 'Location','best');
% legend('LR','ASI |SR|','Location','best');

save_fig(fig, figSaveFolder, 'profiles_axial_LR_ASI_PW');

%% ---------------- FWHM RESULTS (CALL INDEPENDENT FUNCTION) ----------------
% Lateral FWHM
[FWHM_LR_lat, xL_LR_lat, xR_LR_lat] = local_fwhm(x_lat, LR_lat, 0.5);
[FWHM_ASI_lat, xL_ASI_lat, xR_ASI_lat] = local_fwhm(x_lat, SR_lat, 0.5);
[FWHM_PW_lat, xL_PW_lat, xR_PW_lat] = local_fwhm(x_lat, PW_lat, 0.5);

% Axial FWHM
[FWHM_LR_ax, zL_LR_ax, zR_LR_ax] = local_fwhm(z_ax, LR_ax, 0.5);
[FWHM_ASI_ax, zL_ASI_ax, zR_ASI_ax] = local_fwhm(z_ax, SR_ax, 0.5);
[FWHM_PW_ax, zL_PW_ax, zR_PW_ax] = local_fwhm(z_ax, PW_ax, 0.5);

fprintf('\n===== FWHM @ z=%.3fmm (lateral) =====\n', z_used);
fprintf('LR       : %.4f mm (xL=%.4f, xR=%.4f)\n', FWHM_LR_lat,  xL_LR_lat,  xR_LR_lat);
fprintf('ASI |SR| : %.4f mm (xL=%.4f, xR=%.4f)\n', FWHM_ASI_lat, xL_ASI_lat, xR_ASI_lat);
fprintf('PlaneWave: %.4f mm (xL=%.4f, xR=%.4f)\n', FWHM_PW_lat,  xL_PW_lat,  xR_PW_lat);

fprintf('\n===== FWHM @ x=%.3fmm (axial) =====\n', x_used);
fprintf('LR       : %.4f mm (zL=%.4f, zR=%.4f)\n', FWHM_LR_ax,  zL_LR_ax,  zR_LR_ax);
fprintf('ASI |SR| : %.4f mm (zL=%.4f, zR=%.4f)\n', FWHM_ASI_ax, zL_ASI_ax, zR_ASI_ax);
fprintf('PlaneWave: %.4f mm (zL=%.4f, zR=%.4f)\n', FWHM_PW_ax,  zL_PW_ax,  zR_PW_ax);
%% ---------------- SNR/CTR ROIs (draw ONCE per depth) ----------------
% Use the SAME upsampled grid you already made, but use LINEAR images:
LR_lin_up = interp2(x_mm, z_mm, LR_disp, Xq, Zq, interpMethod, 0); LR_lin_up = max(real(LR_lin_up),0);
SR_lin_up = interp2(x_mm, z_mm, SR_disp, Xq, Zq, interpMethod, 0); SR_lin_up = max(real(SR_lin_up),0);
PW_lin_up = interp2(x_mm, z_mm, PW_disp, Xq, Zq, interpMethod, 0); PW_lin_up = max(real(PW_lin_up),0);

% Normalize ONLY for viewing while drawing ROIs (does not affect masks)
LR_view = LR_lin_up ./ (max(LR_lin_up(:)) + eps);

fig = figure('Name','Draw ROIs for SNR/CTR (applied to LR/ASI/PW)');
imagesc(x_mm_up, z_mm_up, 20*log10(LR_view + 1e-12));
axis image; colormap gray; colorbar; set(gca,'YDir','reverse');
caxis([-dyn 0]);
title('Draw SIGNAL ROI (double-click to finish)');
hSig = drawrectangle('Color','g'); wait(hSig);
signalMask = createMask(hSig);

title('Draw BACKGROUND ROI (double-click to finish)');
hBg = drawrectangle('Color','r'); wait(hBg);
bgMask = createMask(hBg);
close(fig);
%%
% % ---------------- DRAW ROIs ----------------
% fig = figure('Name','Draw ROIs for SNR/CTR (applied to LR/ASI/PW)');
% imagesc(x_mm_up, z_mm_up, 20*log10(LR_view + 1e-12));
% axis image; colormap gray; colorbar; set(gca,'YDir','reverse');
% caxis([-dyn 0]);
% 
% title('Draw SIGNAL ROI (double-click to finish)');
% hSig = drawrectangle('Color','g'); wait(hSig);
% signalMask = createMask(hSig);
% 
% title('Draw BACKGROUND ROI (double-click to finish)');
% hBg = drawrectangle('Color','r'); wait(hBg);
% bgMask = createMask(hBg);
% close(fig);

% =====================================================
% >>> INSERT ROI PIXEL INSPECTION CODE RIGHT HERE <<<
% =====================================================

% % ===== Extract ROI pixels for LR / ASI / PW =====
% LR_img  = LR_lin_up;
% ASI_img = SR_lin_up;
% PW_img  = PW_lin_up;
% 
% sig_LR  = LR_img(signalMask);   bg_LR  = LR_img(bgMask);
% sig_ASI = ASI_img(signalMask);  bg_ASI = ASI_img(bgMask);
% sig_PW  = PW_img(signalMask);   bg_PW  = PW_img(bgMask);
% 
% fprintf('\n=== ROI Pixel Stats (linear amplitude) ===\n');
% fprintf('LR  Noise std = %.3g\n', std(bg_LR));
% fprintf('ASI Noise std = %.3g\n', std(bg_ASI));
% fprintf('PW  Noise std = %.3g\n', std(bg_PW));

% figure;
% subplot(3,2,1); histogram(sig_LR,80); title('LR Signal');
% subplot(3,2,2); histogram(bg_LR,80);  title('LR Noise');
% subplot(3,2,3); histogram(sig_ASI,80);title('ASI Signal');
% subplot(3,2,4); histogram(bg_ASI,80); title('ASI Noise');
% subplot(3,2,5); histogram(sig_PW,80); title('PW Signal');
% subplot(3,2,6); histogram(bg_PW,80);  title('PW Noise');

% =====================================================
% >>> THEN SNR/CTR COMPUTATION COMES AFTER <<<
% =====================================================

% isPower = false;
% snrctr_LR  = measureSNR_CTR_masks(LR_lin_up, signalMask, bgMask, isPower);
% snrctr_ASI = measureSNR_CTR_masks(SR_lin_up, signalMask, bgMask, isPower);
% snrctr_PW  = measureSNR_CTR_masks(PW_lin_up, signalMask, bgMask, isPower);

%%
% Compute SNR/CTR on LINEAR images using same masks
isPower = false; % because you use abs(IQ) amplitude
snrctr_LR = measureSNR_CTR_masks(LR_lin_up, signalMask, bgMask, isPower);
snrctr_ASI = measureSNR_CTR_masks(SR_lin_up, signalMask, bgMask, isPower); % ASI = |SR|
snrctr_PW = measureSNR_CTR_masks(PW_lin_up, signalMask, bgMask, isPower);

fprintf('\n===== SNR/CTR (same ROIs) =====\n');
fprintf('LR  : SNR=%.2f dB, CTR=%.2f dB\n', snrctr_LR.SNR_dB,  snrctr_LR.CTR_dB);
fprintf('ASI : SNR=%.2f dB, CTR=%.2f dB\n', snrctr_ASI.SNR_dB, snrctr_ASI.CTR_dB);
fprintf('PW  : SNR=%.2f dB, CTR=%.2f dB\n', snrctr_PW.SNR_dB,  snrctr_PW.CTR_dB);


%% ---------------- SAVE RESULTS MAT ----------------
results = struct();

results.meta.Nz = Nz;
results.meta.Nx = Nx;
results.meta.up = up;
results.meta.z_focus_mm = z_focus_mm;
results.meta.x_focus_mm = x_focus_mm;
results.meta.z_used_mm = z_used;
results.meta.x_used_mm = x_used;
results.meta.interpMethod = interpMethod;

results.lateral.LR.FWHM_mm = FWHM_LR_lat;
results.lateral.LR.xL_mm   = xL_LR_lat;
results.lateral.LR.xR_mm   = xR_LR_lat;

results.lateral.ASI.FWHM_mm = FWHM_ASI_lat;
results.lateral.ASI.xL_mm   = xL_ASI_lat;
results.lateral.ASI.xR_mm   = xR_ASI_lat;

results.lateral.PlaneWave.FWHM_mm = FWHM_PW_lat;
results.lateral.PlaneWave.xL_mm   = xL_PW_lat;
results.lateral.PlaneWave.xR_mm   = xR_PW_lat;

results.axial.LR.FWHM_mm = FWHM_LR_ax;
results.axial.LR.zL_mm   = zL_LR_ax;
results.axial.LR.zR_mm   = zR_LR_ax;

results.axial.ASI.FWHM_mm = FWHM_ASI_ax;
results.axial.ASI.zL_mm   = zL_ASI_ax;
results.axial.ASI.zR_mm   = zR_ASI_ax;

results.axial.PlaneWave.FWHM_mm = FWHM_PW_ax;
results.axial.PlaneWave.zL_mm   = zL_PW_ax;
results.axial.PlaneWave.zR_mm   = zR_PW_ax;

results.snrctr.LR = snrctr_LR;
results.snrctr.ASI = snrctr_ASI;
results.snrctr.PlaneWave = snrctr_PW;


save(resultsMatFile, 'results');
fprintf('\nSaved FWHM results to:\n  %s\n', resultsMatFile);

disp('DONE. All images saved, results saved.');

