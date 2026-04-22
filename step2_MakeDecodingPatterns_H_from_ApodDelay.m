% ============================================================
% MakeDecodingPatterns_H_from_ApodDelay.m
% Builds H(z,x,p) on the SAME grid as your IQ beamformed grid.
% Output: H [Nz x Nx x 5]
% ============================================================
clear; clc;

%% --- Load your GS output (ApodMap, DelayMap, elem_x_mm, etc.) ---
%S = load('ASI_GS_ApodDelay_kWave_GSplusViz.mat', ...
  %  'ApodMap','DelayMap','elem_x_mm','c_mps','f0','pitch_mm');

%where matfile is 
dataFolder ='/Users/fariarahman/Documents/MATLAB/Acoustic Structured illumination/Codes/sakib_codes/fix_steps/Matfiles/DiffDeltadApodstep1/18mm';
fileName = 'Apod_Deltad_0.0_depth_18mm_f0_7.6_delta.mat';
%fileName='Apod_Deltad_0.1_depth_18mm_f0_7.6_delta.mat';
S = load(fullfile(dataFolder, fileName));
  
%save options , where pattern will be saved 
saveFolder = '/Users/fariarahman/Documents/MATLAB/Acoustic Structured illumination/Codes/sakib_codes/Decoding_patterns/diffDeltaD/18mm';
if ~exist(saveFolder, 'dir')
    mkdir(saveFolder);
end
outFile = 'DecodingPatterns_H_Apod_Deltad_0.0_Z_18_f0_7.6_delta_374_128pixel.mat';



ApodMap    = S.ApodMap;
DelayMap   = S.DelayMap;
elem_x_mm  = S.elem_x_mm(:).';
%c_mps      = S.c_mps;
c_mps= 1540;
%f0         = S.f0;
f0=7.6e6;
pitch_mm   = 0.3;

medium.sound_speed = c_mps;

%% --- Define YOUR IQ grid (must match reconstruction) ---
Trans_spacing_wl = 1.48;   % your Trans.spacing (wavelengths)
Nx = 128;                  % your IQ lateral size
P_startDepth_wl = 5;
P_endDepth_wl   = 192;
dz_wl           = 0.5;     % PData.PDelta(3)

lambda_mm = (c_mps/f0)*1e3;

Nz = round((P_endDepth_wl - P_startDepth_wl)/dz_wl);   % <-- IMPORTANT +1

x_mm = ((0:Nx-1) - (Nx-1)/2) * Trans_spacing_wl * lambda_mm;     % 1xNx
z_mm = (P_startDepth_wl + (0:Nz-1)*dz_wl) * lambda_mm;          % 1xNz

%% --- Simulation lateral grid (fine) ---
dx_sim_mm = 0.05;
Nx_sim    = 2048;
x_sim_mm  = (-Nx_sim/2 : Nx_sim/2-1) * dx_sim_mm;   % 1xNx_sim
dx_sim_m  = dx_sim_mm * 1e-3;

sigma_elem = pitch_mm/2;   % same as your design/viz

%% --- Build H ---
H = zeros(Nz, Nx, 5);
tic;
for p = 1:5
    apod   = ApodMap(:,p);
    tau_us = DelayMap(:,p);

    tau_s_rel = (tau_us - min(tau_us)) * 1e-6;
    phi = -2*pi*f0*tau_s_rel;
    w_elem = apod .* exp(1i*phi);

    % aperture field on fine grid
    P0 = zeros(1, Nx_sim);
    for n = 1:numel(w_elem)
        P0 = P0 + w_elem(n) .* exp( -((x_sim_mm - elem_x_mm(n)).^2)/(2*sigma_elem^2) );
    end

    % propagate to each z in YOUR beamformed grid
    Field_sim = zeros(Nz, Nx_sim);
    for iz = 1:Nz
        dz_m = z_mm(iz) * 1e-3;
        Pz = propagateCW(P0.', dz_m, dx_sim_m, f0, medium); % [Nx_sim x 1]
        Field_sim(iz,:) = Pz.';                             % [1 x Nx_sim]
    end

    % choose what H should represent:
    % Option 1 (common): intensity illumination pattern
    I_sim = abs(Field_sim).^2;

    % normalize pattern
    I_sim = I_sim ./ (max(I_sim(:)) + eps);

    % resample lateral from sim grid -> IQ grid
    for iz = 1:Nz
        H(iz,:,p) = interp1(x_sim_mm, I_sim(iz,:), x_mm, 'linear', 0);
    end

    % optional: normalize again after interpolation
    Hp = H(:,:,p);
    H(:,:,p) = Hp ./ (max(Hp(:)) + eps);

    fprintf('Built H for p=%d, range [%.3g %.3g]\n', p, min(H(:,:,p),[],'all'), max(H(:,:,p),[],'all'));
end
toc;
%%


save(fullfile(saveFolder, outFile), 'H', 'x_mm', 'z_mm', '-v7.3');
%save('DecodingPatterns_H_ASI_GS_ApodDelay_4FWHM_7.6MHz_01_05_2026_10pm.mat');
%disp('Saved DecodingPatterns_H_ASI_GS_ApodDelay_7.6MHz_2.5FWHM_30mm_simulateTXPD_01052026_9pm.mat');

%% ---- helper (same as yours) ----
function P_out = propagateCW(P_in, dz_m, dx_m, f0, medium)
Nx = numel(P_in);
P2D = angularSpectrumCW( reshape(P_in,[Nx,1]), dx_m, [0 dz_m], f0, medium, ...
    'AngularRestriction', true, 'DataCast', 'off');
P_out = squeeze(P2D(:,1,2));
end
