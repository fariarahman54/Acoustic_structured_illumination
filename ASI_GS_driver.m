function [ApodMat, DelayMat, Gsim, x_focus] = ASI_GS_driver(Trans, Resource, z_focus_mm, Delta_d_mm, numShifts)

c_mm_us = Resource.Parameters.speedOfSound/1000; % mm/us
f0_MHz  = Trans.frequency;                       % MHz
lambda_mm = c_mm_us / f0_MHz;

N = Trans.numelements;
pitch_mm = Trans.spacing * lambda_mm;

% lateral coordinate at transducer
x_tx = ((0:N-1) - (N-1)/2) * pitch_mm;

% design focal plane lateral grid
x_focus = linspace(min(x_tx), max(x_tx), 512);

% build desired multi-foci pattern for each shift
A_des_all = cell(1,numShifts);
shiftStep_mm = Delta_d_mm/numShifts;
foci_positions0 = (-2:2)*Delta_d_mm;   % 5 foci spanning ~4Δd (edit if you want)

for s=1:numShifts
    phi = (s-1)*shiftStep_mm;  % lateral shift
    foci_positions = foci_positions0 + phi;

    % desired amplitude = sum of narrow Gaussians (delta approx)
    A_des = zeros(size(x_focus));
    sigma = 0.15*Delta_d_mm;   % narrow but resolvable
    for k=1:numel(foci_positions)
        A_des = A_des + exp(-(x_focus - foci_positions(k)).^2/(2*sigma^2));
    end
    A_des = A_des / max(A_des);  % normalize
    A_des_all{s} = A_des;
end

% GS parameters
nIter = 60;
corrThresh = 0.995;

ApodMat  = zeros(N,numShifts);
DelayMat = zeros(N,numShifts);
Gsim     = cell(1,numShifts);

for s=1:numShifts
    [apod, delay_sec, Gfield] = ASI_GS_1D(x_tx, x_focus, z_focus_mm, f0_MHz, c_mm_us, A_des_all{s}, nIter, corrThresh);
    ApodMat(:,s)  = apod(:);
    DelayMat(:,s) = delay_sec(:);
    Gsim{s}       = abs(Gfield)/max(abs(Gfield)); % normalized decoding grating
end
end
