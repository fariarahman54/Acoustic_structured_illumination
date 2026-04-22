% ========================================================================
% ASI_GS_Design_And_Visualize_kWave_COMBINED.m
%
% ONE drop-in script that:
%   (A) Runs Gerchberg–Saxton (GS) using k-Wave angularSpectrumCW to design
%       ApodMap [Ne x 5] and DelayMap [Ne x 5] (microseconds)
%   (B) Visualizes the pressure/intensity field (TXPD-like) using the SAME
%       visualization workflow you said "looks correct" (your SimulateTXPD_kWaveAngSpec style)
%
% IMPORTANT:
%   - Keep c_mps and f0 CONSISTENT across GS + visualization.
%   - GS grid: x_mm is a column [Nx x 1]. Viz grid: x_mm is a row [1 x Nx].
%     (That's OK as long as spacing matches. We rebuild x_mm for viz exactly as your working code.)
%   - dB mapping: Your working visualization uses 20*log10(I). That is not physically
%     "intensity dB" (should be 10*log10), but I am keeping it EXACTLY as your working code.
%
% Requires: k-Wave Toolbox on MATLAB path (angularSpectrumCW).
% ========================================================================

% this is version 2 , I am using this to do the reverse propagation in a
% proper way . 
clear; clc; close all;

%% ================= USER SETTINGS =================
% Medium / frequency (KEEP SAME everywhere)
c_mps = 1540;          % [m/s]
f0    = 7.6e6;         % [Hz]
f0_MHz = f0/1e6;

% Array
Ne       = 128;
pitch_mm = 0.3;       % [mm]
     % [mm]

% GS propagation grid
dx_mm = 0.05;          % [mm]
Nx    = 2048;          % power of 2

% ASI pattern parameters
numFoci     = 5;
numPatterns = 5;


FWHM_mult   = 2.5;       % Delta_d = FWHM_mult * FWHM
z_focus_mm = 18; 


% GS loop controls
numIterMax = 10;
corrThresh = 0.995;
minIter    = 2;

% Visualization settings (match your working code)
p = 3;                 % which pattern (1..5) to simulate/visualize
z_min_mm = 0;
z_max_mm = 40;
Nz       = 200;

%% Save mat file settings
doSave   = true;

saveDir = '/Users/fariarahman/Documents/MATLAB/Acoustic Structured illumination/Codes/sakib_codes/fix_steps/Matfiles/depthExperimentSameDeltaD';

% create folder once
if ~exist(saveDir, 'dir')
    mkdir(saveDir);
end

saveName = sprintf(['ApodDelay_%.2fdeltad_7.6MHz_%dmm_delta test' ...
    ' .mat'], FWHM_mult,z_focus_mm);
  
%saveName='random'
%% ================= DERIVED / GRIDS (GS) =================
lambda_mm = (c_mps / f0) * 1e3;

x_mm_col = ((-Nx/2):(Nx/2-1)).' * dx_mm;   % [Nx x 1] column
dx_m     = dx_mm * 1e-3;
x_m_col  = x_mm_col * 1e-3;

elem_x_mm = ((1:Ne) - (Ne+1)/2) * pitch_mm;   % [1 x Ne]
elem_x_m  = elem_x_mm * 1e-3;

aperture_mm   = Ne * pitch_mm;
aperture_mask = (x_mm_col >= -aperture_mm/2) & (x_mm_col <= aperture_mm/2);

z_focus_m = z_focus_mm * 1e-3;

% foci spacing (Kathy-style)
FWHM_mm    = 1.206 * (lambda_mm * z_focus_mm) / aperture_mm;
Delta_d_mm =0.2;
% FWHM_mult * FWHM_mm;

shift_step_mm = Delta_d_mm / numPatterns;
shift_list_mm = (-2:2) * shift_step_mm;
shift_list_m  = shift_list_mm * 1e-3;

foci_index    = (-2:2);
foci_base_mm  = foci_index * Delta_d_mm;
foci_base_m   = foci_base_mm * 1e-3;

% Gaussian width for each focus in desired amplitude at focus plane
sigma_mm = Delta_d_mm /6;
sigma_m  = sigma_mm * 1e-3;

% k-Wave medium
medium.sound_speed = c_mps;

%% ================= OUTPUT ARRAYS =================
ApodMap     = zeros(Ne, numPatterns);
DelayMap    = zeros(Ne, numPatterns);      % [us]
Pattern1D   = zeros(Nx, numPatterns);      % final focal amplitude patterns
corrHistAll = nan(numIterMax, numPatterns);

%% ================= GS DESIGN LOOP (KEEP THIS PART) =================
fprintf('=== GS design using k-Wave angularSpectrumCW ===\n');
t0 = tic;

for pp = 1:numPatterns
    fprintf('Pattern %d / %d\n', pp, numPatterns);

    % --- Desired amplitude A1 at focus plane (z=z_focus) ---
    shift_m          = shift_list_m(pp);
    foci_positions_m = foci_base_m + shift_m;


    % this is for gaussian target 
    A1 = zeros(Nx, 1);
    for kf = 1:numFoci
        A1 = A1 + exp(-((x_m_col - foci_positions_m(kf)).^2) / (2*sigma_m^2));
    end
    A1 = A1 / max(A1(:));

    %here the target is the grating as a sum of delta functions spaced by
    %delta d like kathys paper 
    A1 = zeros(Nx,1);
    for kf = 1:numFoci
        [~,ix] = min(abs(x_m_col - foci_positions_m(kf)));
        A1(ix) = 1;
    end

    % %optional: very small blur (1–2 pixels) to help convergence
    % A1 = conv(A1, [0.25 0.5 0.25]', 'same');
    % 
    % A1 = A1 / max(A1+eps);


    % Initial complex field at focus: amplitude A1, zero phase
    P1 = A1 .* exp(1i*0);

    corrHist = nan(numIterMax, 1);

    for it = 1:numIterMax
        % Back propagate (focus -> aperture plane)
        P2 = propagateCW_back(P1, z_focus_m, dx_m, f0, medium);
        P2(~aperture_mask) = 0;

        % Forward propagate (aperture -> focus)
        P1_forw = propagateCW(P2, z_focus_m, dx_m, f0, medium);

        % Correlation of amplitudes
        amp_now = abs(P1_forw);
        a = amp_now(:) - mean(amp_now(:));
        b = A1(:)      - mean(A1(:));
        corrVal = sum(a.*b) / sqrt(sum(a.^2) * sum(b.^2) + eps);
        corrHist(it) = corrVal;

        if it >= minIter && corrVal >= corrThresh
            fprintf('  Converged at it=%d (corr=%.4f)\n', it, corrVal);
            break;
        end

        % Enforce desired amplitude, keep phase
        P1 = A1 .* exp(1i * angle(P1_forw));
    end

    % for sanity check 
    if it == numIterMax || (it>=minIter && corrVal>=corrThresh)
        figure; 
        plot(x_mm_col, A1./max(A1), 'k--', 'LineWidth', 2); hold on;
        plot(x_mm_col, abs(P1_forw)./max(abs(P1_forw)), 'b', 'LineWidth', 2);
        xlim([-3 3]); ;
        legend('Desired A1','Achieved |P1_{forw}|');
        title(sprintf('Focus-plane amplitude match, pattern %d, corr=%.4f', pp, corrVal));
    end





    corrHistAll(:,pp) = corrHist;

    % Save final focal amplitude pattern
    amp_final = abs(P1_forw);
    amp_final = amp_final / max(amp_final(:));
    Pattern1D(:,pp) = amp_final;

    % Recompute P2 on aperture plane for sampling at elements
    P2 = propagateCW_back(P1, z_focus_m, dx_m, f0, medium);
    P2(~aperture_mask) = 0;

    % Sample complex field at element centers
    P2_elem = interp1(x_mm_col, P2, elem_x_mm, 'linear', 0);   % [1 x Ne] complex

    % Apodization
    apod = abs(P2_elem(:));
    if max(apod) > 0, apod = apod / max(apod); end

    % Phase -> delays
    phi = angle(P2_elem(:));
    phi = unwrap(phi);
    tau_s  = -phi / (2*pi*f0); % negative sign is added to flip the delay curve because side elements fire first 
    tau_s= tau_s-min(tau_s);  % making relative delays nonnegative 
    tau_us = tau_s * 1e6;

    ApodMap(:,pp)  = apod;
    DelayMap(:,pp) = tau_us;
end

fprintf('GS done in %.2f s\n', toc(t0));

%% ================= QUICK SANITY PLOTS (GS OUTPUT) =================
elem_index=1:Ne;
figure('Name','Apod/Delay sanity');
subplot(2,1,1);
plot(elem_index, ApodMap(:,p),'LineWidth',1.5); 
xlabel('Element x [mm]'); ylabel('Apod (norm)');
title(sprintf('Apodization (pattern %d)', p));xlim([1 128]);

subplot(2,1,2);
plot(elem_index, DelayMap(:,p),'LineWidth',1.5); 
xlabel('Element x [mm]'); ylabel('Delay [\mus]');xlim([1 128]);
title(sprintf('Delay (pattern %d)', p));

figure('Name','GS correlation');
plot(corrHistAll(:,p),'LineWidth',1.5); 
xlabel('Iteration'); ylabel('corr');
title(sprintf('GS correlation history (pattern %d)', p));

disp(foci_positions_mm)
for k = 1:numel(foci_positions_mm)
    xline(foci_positions_mm(k),'r--');
end


%% ================= VISUALIZATION (KEEP THIS PART STYLE) =================
% This block is your "working" visualization style, but now it uses the
% ApodMap/DelayMap we JUST computed (no loading a .mat).

fprintf('=== Visualization using your SimulateTXPD_kWaveAngSpec workflow ===\n');

% ---- Build complex weights from apod + delay ----
apod   = ApodMap(:,p);         % [Ne x 1], 0..1
tau_us = DelayMap(:,p);        % [Ne x 1], microseconds

% make delays relative (constant offset doesn't matter for CW pattern)
tau_s_rel = (tau_us - min(tau_us)) * 1e-6;   % [s]

% phase advance for transmit: negative sign
phi = -2*pi*f0 * tau_s_rel;    % [rad]

w_elem = apod .* exp(1i*phi);  % complex weight per element

%% ---- Lateral grid for field simulation ----
% (Rebuild exactly like your working code)
dx_mm_v = dx_mm;               % keep same number, but explicit
dx_m_v  = dx_mm_v * 1e-3;
Nx_v    = Nx;

x_mm = (-Nx_v/2 : Nx_v/2-1) * dx_mm_v;   % [1 x Nx] row

%% ---- Build complex aperture field on fine grid (sum of weighted elements) ----
% sigma_elem = pitch_mm/2;       % [mm]
% 
% P0 = zeros(1, Nx_v);           % field at z=0 (row)
% for n = 1:Ne
%     P0 = P0 + w_elem(n) .* exp( -((x_mm - elem_x_mm(n)).^2) / (2*sigma_elem^2) );
% end

% Build aperture field directly from element weights (no Gaussian smoothing)
P0 = interp1(elem_x_mm(:), w_elem(:), x_mm(:), 'linear', 0).';   % row 1xNx

%% ---- Propagate to multiple depths using k-Wave angularSpectrumCW ----
z_mm_vec = linspace(z_min_mm, z_max_mm, Nz);
z_m_vec  = z_mm_vec * 1e-3;

Field = zeros(Nz, Nx_v);

for iz = 1:Nz
    dz_m = z_m_vec(iz);
    Pz_col      = propagateCW(P0.', dz_m, dx_m_v, f0, medium);  % column
    Field(iz,:) = Pz_col.';                                    % row
end

%% ---- Intensity and focal-plane profile ----
I = abs(Field).^2;
I = I / max(I(:));
A = abs(Field);
A = A / max(A(:));      % normalize amplitude (like GS does)
[~, iz30] = min(abs(z_mm_vec - z_focus_mm));   % nearest depth to focus

% expected foci for pattern p (keep your exact intent)
shift_mm          = shift_list_mm(p);
foci_positions_mm = foci_base_mm + shift_mm;

figure('Name','Lateral profile at focus');
% plot(x_mm, I(iz30,:),'LineWidth',2); 
plot(x_mm, A(iz30,:)/max(A(iz30,:)),'LineWidth',2); % Amplitude plotting 
hold on;
yL = ylim;
% for k = 1:numel(foci_positions_mm)
%     xline(foci_positions_mm(k),'r--');
% end
xlim([-5 5]);
ylim(yL);
xlabel('x [mm]'); ylabel('Intensity (norm.)');
title(sprintf('Lateral profile at %.1f mm, f_0=%.1f MHz, x=%.1f', ...
      z_focus_mm, f0_MHz, FWHM_mult));
;

%% ---- Plot like TXPD (depth vs lateral) ----
fprintf('max |P0| = %g\n', max(abs(P0(:))));
fprintf('max I = %g, min I = %g\n', max(I(:)), min(I(:)));

% KEEP exactly like your working code (even though it's unconventional for intensity):
figure('Name','TXPD-like map (your dB mapping)');
imagesc(x_mm, z_mm_vec, 10*log10(I + 1e-12));
set(gca,'YDir','reverse');
colormap(jet); 
%colorbar;
clim([-55 -25]);  % keep exactly as your code
title(sprintf('f_0 = %.1f MHz, Delta d = %.2f mm, depth = %d mm,X = %.1f', ...
    f0_MHz, Delta_d_mm, z_focus_mm, FWHM_mult));
xlabel('Lateral [mm]'); xlim([-5 5]);
ylabel('Depth [mm]');  ylim([10 40]);

%%
% % linear (most similar to paper)
% imagesc(x_mm, z_mm_vec, I); 
% set(gca,'YDir','reverse'); colorbar; caxis([0 1]);

% % OR dB but realistic window
% imagesc(x_mm, z_mm_vec, 10*log10(I + 1e-12));   % intensity dB
% caxis([-110 0]);  % or [-35 0]


%% ---- Optional: plot raw Apod/Delay for sanity ----
figure('Name','Apodization (element index)');
plot(ApodMap(:,p),'LineWidth',2); ;
xlabel('Element index'); ylabel('Magnitude'); xlim([1 128]);
title(sprintf('Apodization, pattern %d', p));

figure('Name','Delay (element index)');
plot(DelayMap(:,p),'LineWidth',2); ;
xlabel('Element index'); ylabel('Delay [\\mus]'); xlim([1 128]);
title(sprintf('Delay, pattern %d', p));

%% ================= SAVE (optional) =================
if doSave
    savePath = fullfile(saveDir, saveName);

    save(savePath, ...
        'ApodMap','DelayMap','Pattern1D', ...
        'elem_x_mm','x_mm_col', ...
        'foci_base_mm','shift_list_mm', ...
        'Delta_d_mm','z_focus_mm','lambda_mm', ...
        'corrHistAll', ...
        'I','z_mm_vec','p','c_mps','f0','dx_mm','Nx');

    fprintf('Saved to:\n%s\n', savePath);
end

%% sanity check for back propagation
% Make a random aperture field, forward propagate, then backprop
test0 = exp(1i*2*pi*rand(Nx,1));   % random phase
testF = propagateCW(test0, z_focus_m, dx_m, f0, medium);
testB = propagateCW_back(testF, z_focus_m, dx_m, f0, medium);

% testB should look like test0 (up to scaling)
fprintf('corr = %.4f\n', abs(sum(test0 .* conj(testB))) / sqrt(sum(abs(test0).^2)*sum(abs(testB).^2)));

%% ================= Helper functions (k-Wave) =================
function P_out = propagateCW(P_in, dz_m, dx_m, f0, medium)
%PROPAGATECW  1D CW angular spectrum propagation using k-Wave.
%   P_in : [Nx x 1] complex field vs x (at z = 0)
%   dz_m : distance to propagate in meters (>= 0)
%   dx_m : grid spacing in meters
%   f0   : CW frequency [Hz]
%   medium: struct with medium.sound_speed

Nx = numel(P_in);

P2D = angularSpectrumCW( reshape(P_in, [Nx, 1]), ...
    dx_m, [0 dz_m], f0, medium, ...
    'AngularRestriction', true, ...
    'DataCast', 'off');

P_out = squeeze(P2D(:, 1, 2));  % [Nx x 1]
end

% function P_out = propagateCW_back(P_in, dz_m, dx_m, f0, medium)
% % Backward propagation consistent with your GS usage.
% % (Matches what you used when your GS+viz looked good.)
% P_out = propagateCW(conj(P_in), dz_m, dx_m, f0, medium);
% end


function P_out = propagateCW_back(P_in, dz_m, dx_m, f0, medium)
Nx = numel(P_in);

P2D = angularSpectrumCW( reshape(P_in, [Nx, 1]), ...
    dx_m, [0 dz_m], f0, medium, ...
    'AngularRestriction', true, ...
    'DataCast', 'off', ...
    'Reverse', true);

% IMPORTANT: with Reverse=true, the z-stack is flipped internally.
% So plane 1 is the propagated plane, plane 2 is the original plane.
P_out = squeeze(P2D(:, 1, 1));   % <-- THIS is the back-propagated field
end
