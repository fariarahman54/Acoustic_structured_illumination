function [apod, delay_sec, P_focus] = ASI_GS_1D( ...
      x_tx, x_focus, z_mm, f0_MHz, c_mm_us, A_des, nIter, corrThresh, P_focus_init)

% if init is provided, use it; otherwise default
if nargin < 9 || isempty(P_focus_init)
    P_focus = A_des .* exp(1i*zeros(size(A_des)));
else
    P_focus = P_focus_init;
end

k = 2*pi*(f0_MHz/c_mm_us); % rad/mm, since f0 in MHz and c in mm/us % wave number

% spatial frequency axis for focus grid , it gives a list of lateral
% spatial frequencies
dx = x_focus(2)-x_focus(1); % spacing of your focus grid
Nx = numel(x_focus);  % numel returns total number of elements in x_focus array, Nx is number of lateral grid samples
kx = 2*pi*fftshift( (-floor(Nx/2):ceil(Nx/2)-1)/(Nx*dx) ); % rad/mm

% angular spectrum propagator
H_forward  = exp(1i*z_mm*sqrt( max(k^2 - kx.^2, 0) )); % evanescent truncated, propagate from transducer plane to focus plane
H_backward = conj(H_forward); % propagate backwards, complex conjugate for lossless propagation

% initial field at focus: desired amplitude, zero phase everywhere
P_focus = A_des .* exp(1i*zeros(size(A_des)));

% precompute interpolation from focus→tx and tx→focus
% (simple nearest/linear interp)
for it=1:nIter
    % backprop to transducer
    Pf = fftshift(fft(P_focus));
    Ptx_full = ifft(ifftshift(Pf .* H_backward));  %continuous transducer plane field , we wish we could create

    % sample on element positions
    Ptx_elem = interp1(x_focus, Ptx_full, x_tx, 'linear', 0); % transducer isn't continuous , it has discrete loaction at x_tx, so interpolating thye continuous field down to element locations. outside the focus grid, filling with zero

    % enforce aperture constraint: keep phase, clip amp outside (already 0 by interp)
    phase_tx = angle(Ptx_elem); %keep the phase you got 
    amp_tx   = abs(Ptx_elem);
    amp_tx   = amp_tx / max(amp_tx); % normalize to 1

    Ptx_elem = amp_tx .* exp(1i*phase_tx); % Ptx_elem is a legal transducer excitat

    % forward prop to focus
    Ptx_grid = interp1(x_tx, Ptx_elem, x_focus, 'linear', 0); % put on focus grid
    Ptx_spec = fftshift(fft(Ptx_grid));
    P_focus_new = ifft(ifftshift(Ptx_spec .* H_forward));

    % impose desired amplitude, keep phase
    P_focus = A_des .* exp(1i*angle(P_focus_new));

    % convergence check
    corrVal = corr(A_des(:), abs(P_focus_new(:)));
    if corrVal > corrThresh
        break;
    end
end

% final transducer field
Pf = fftshift(fft(P_focus));
Ptx_full = ifft(ifftshift(Pf .* H_backward));
Ptx_elem = interp1(x_focus, Ptx_full, x_tx, 'linear', 0);

apod = abs(Ptx_elem);
apod = apod / max(apod);

phase = angle(Ptx_elem);         % radians
delay_sec = -phase/(2*pi*f0_MHz*1e6); % seconds (negative is conventional)
delay_sec = delay_sec - min(delay_sec); % make non-negative
end
