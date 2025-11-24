% updated 09.24.2020 by Jihun Kim

%%
clear all
close all
folder = 'F:\outputsfolderfaria'
%folder = 'D:/rawdata_ulm/L22/';
ex_name = 'seGVsMk1s3';    %No underbar

P.startDepth = 5%6;
P.endDepth =192;                                                            
% --- ASI parameters ---
P.numShifts = 5;              % 5 pattern shifts
P.numAngles = P.numShifts;    % reuse your existing variable usage
P.Angles = 0;                 % no steering
dtheta = 0; startAngle = 0;

P.Vin = 5; % +/- 5 v => 10 Vpp %the pulsar will swing +- 5v when it fires
P.numAcqs = P.numAngles;      % no. of Receive frames (real-time images are produced 1 per frame)

P.numFrames =  1;% 500;      % no. of Receive frames (real-time images are produced 1 per frame)
simulateMode = 0;   % set to acquire data using Vantage 128 hardware
% --- set LNA,PGA and pulse amplitude
RcvProfile.LnaZinSel = 31; %Input impedance setting (usually leave as is unless you're tuning hardware).
% RcvProfile.PgaGain = 30;    % 30dB (default: 24 dB; can bet set as 24, 30 dB)
RcvProfile.LnaGain = 24;    % 24dB (default: 18dB; can be set as 15,18,24 dB) %amplifies the echo signal before saving them
TPC(1).hv = P.Vin; % +-15V

% -----------------------------------------------------------------------------

%% Define system parameters.
filename = 'LFHFR_RFacq'; % used to launch VSX automatically
Resource.Parameters.connector = 1; 
Resource.Parameters.numTransmit = 128;      % number of transmit channels.
Resource.Parameters.numRcvChannels = 128;   % number of receive channels.
Resource.Parameters.speedOfSound = 1540;    % set speed of sound in m/sec before calling computeTrans
Resource.Parameters.verbose = 2;
Resource.Parameters.initializeOnly = 0;
Resource.Parameters.simulateMode = 0; %simulateMode;
%  Resource.Parameters.simulateMode = 1 forces simulate mode, even if hardware is present.
%  Resource.Parameters.simulateMode = 2 stops sequence and processes RcvData continuously.


%% Specify Trans structure array.
Trans.name = 'L11-5v';
Trans.units = 'wavelengths';
Trans = computeTrans(Trans);
Trans.maxHighVoltage = 20;  % set maximum high voltage limit for pulser supply.
RcvProfile.LnaZinSel = 31; % put LNA in "high-z" input state for best sensitivity
%% Specify PData structure array.
% PData.PDelta = [0.4, 0, 0.25]; % [pdeltaX, pdeltaY, pdeltaZ]
PData.PDelta=[Trans.spacing, 0, 0.5];
PData.Size(1) = ceil((P.endDepth-P.startDepth)/PData.PDelta(3)); % range, origin and pdelta set PData.Size.
PData.Size(2) = ceil((Trans.numelements*Trans.spacing)/PData.PDelta(1));
PData.Size(3) = 1;      % single image page
PData.Origin = [-Trans.spacing*(Trans.numelements-1)/2,0,P.startDepth]; % x,y,z of uppr lft crnr.
% No PData.Region specified, so a default Region for the entire PData array will be created by computeRegions.

 %% Specify Media object.

%MP=PointsDifferentDepth(5,0,[145 185]); %PointsDifferentDepth(numPoints, xPos, depthRange)
% MP = moving_MultiplePointsTarget(numPoints, xRange, zRange, ampRange, velRange);
numPoints= 4;
MP=Rand_PointsTarget(numPoints,25,145);
Media.MP=MP;
Media.attenuation=-0.5;
Media.function = 'movePoints';



% ← INSERT THIS LINE:
Para.Media = Media;

% (then you would save Para, e.g.)
% save(fullfile(folder, ['Para_' filename '.mat']), 'Para');
% figure; scatter(MP(:,1), MP(:,3), 'filled');
% xlabel('Lateral (lambda)'); ylabel('Depth (lambda)');
% title('Simulated Random Multiple Points Target Location');


%% Specify Resources.
Resource.RcvBuffer(1).datatype = 'int16';

Resource.RcvBuffer(1).rowsPerFrame = P.numAngles*2176; % this size allows for maximum range
Resource.RcvBuffer(1).colsPerFrame = Resource.Parameters.numRcvChannels;
Resource.RcvBuffer(1).numFrames = P.numFrames;    % frames stored in RcvBuffer.
Resource.InterBuffer(1).numFrames = 1;   % one intermediate buffer needed.
Resource.ImageBuffer(1).numFrames = P.numFrames;
Resource.DisplayWindow(1).Title = 'LF_Flash Angles_HFR';
Resource.DisplayWindow(1).pdelta = 0.18; %Means each display pixel = 0.18 mm in the image.
ScrnSize = get(0,'ScreenSize'); %1536 and 864—are simply your monitor’s pixel resolution:1536 pixels wide and 864 pixels tall
DwWidth = ceil(PData(1).Size(2)*PData(1).PDelta(1)/Resource.DisplayWindow(1).pdelta); %PData.Size(2)*PData.PDelta(1) = total lateral span in mm,Dividing by 0.18 mm/pixel and rounding up → how many pixels wide your window must be.
DwHeight = ceil(PData(1).Size(1)*PData(1).PDelta(3)/Resource.DisplayWindow(1).pdelta);
% Resource.DisplayWindow(1).Position = [250,(ScrnSize(4)-(DwHeight+150))/2, ...  % lower left corner position
%                                       DwWidth, DwHeight];
Resource.DisplayWindow(1).Position = [450,50, ...  % lower left corner position
                                      DwWidth, DwHeight];
Resource.DisplayWindow(1).ReferencePt = [PData(1).Origin(1),0,PData(1).Origin(3)];   % 2D imaging is in the X,Z plane
Resource.DisplayWindow(1).Type = 'Verasonics';
Resource.DisplayWindow(1).numFrames = 20;
Resource.DisplayWindow(1).AxesUnits = 'mm';
Resource.DisplayWindow(1).Colormap = gray(256);
%% Loading extracted maps 
% Delaymap = load('Delay30mmIntensity.mat');        % should contain DelayVec
% Apodmap  = load('Apod30mmIntensity.mat');         % should contain ApodVec
% 
% DelayVec0 = Delaymap.DelayVec(:).';  % 1x128
% ApodVec0  = Apodmap.ApodVec(:).';    % 1x128



%% Specify Transmit waveform structure.
% --- TX waveform same as before ---
TW.type = 'parametric';
TW.Parameters = [7.6, 0.67, 1, 1]; % 1 cycle (paper uses ~1 cycle) :contentReference[oaicite:3]{index=3}

% --- TX array: one TX per shift ---
TX = repmat(struct('waveform',1,'Origin',[0 0 0], ...
                   'focus',0,'Steer',[0 0],'Apod',zeros(1,128), ...
                   'Delay',zeros(1,128)), 1, P.numShifts);

% element pitch (mm) for L11-5v
pitch_mm = Trans.spacing * (Resource.Parameters.speedOfSound/1000/Trans.frequency);

% choose desired grating period ?d in mm (from paper/your design)
Delta_d_mm = 1.1;                 % example at 30 mm depth :contentReference[oaicite:4]{index=4}
shiftStep_mm = Delta_d_mm/P.numShifts;

% element shift per pattern
elemShiftPerStep = shiftStep_mm / pitch_mm;


[ApodMat, DelayMat, Gsim, x_focus] = ASI_GS_driver(Trans, Resource, 30, 1.1, 5);

for s=1:P.numShifts
    TX(s).Apod  = ApodMat(:,s).';
    TX(s).Delay = DelayMat(:,s).';  % seconds
end

save('ASI_DecodingPatterns.mat','Gsim','x_focus');


% for s = 1:P.numShifts
%     elemShift = round((s-1)*elemShiftPerStep);
% 
%     TX(s).Apod  = circshift(ApodVec0, [0 elemShift]);
%     TX(s).Delay = circshift(DelayVec0,[0 elemShift]);

    % IMPORTANT: Ensure Delay units are seconds.
    % If your DelayVec0 was in "wavelengths", convert:
    % lambda_mm = Resource.Parameters.speedOfSound/1000/Trans.frequency;
    % TX(s).Delay = Delay_wls * lambda_mm / (Resource.Parameters.speedOfSound/1000);
% end

%% Specify TGC Waveform structure.
% TGC.CntrlPts = [0 1023 1023 1023 1023 1023 1023 1023]; % [0,511,716,920,1023,1023,1023,1023];
TGC.CntrlPts = [0,297,424,300,300,300,300,300];
TGC.rangeMax = P.endDepth;
TGC.Waveform = computeTGCWaveform(TGC);

%% Specify Receive structure arrays.
% - We need na Receives for every frame.

% sampling center frequency is 15.625, but we want the bandpass filter
% centered on the actual transducer center frequency of 18 MHz with 67%
% bandwidth, or 12 to 24 MHz.  Coefficients below were set using
% "filterTool" with normalized cf=1.15 (18 MHz), bw=0.85,
% xsn wdth=0.41 resulting in -3 dB 0.71 to 1.6 (11.1 to 25 MHz), and
% -20 dB 0.57 to 1.74 (8.9 to 27.2 MHz)
%
% BPF1 = [ -0.00009 -0.00128 +0.00104 +0.00085 +0.00159 +0.00244 -0.00955 ...
%          +0.00079 -0.00476 +0.01108 +0.02103 -0.01892 +0.00281 -0.05206 ...
%          +0.01358 +0.06165 +0.00735 +0.09698 -0.27612 -0.10144 +0.48608 ];

maxAcqLength = ceil(sqrt(P.endDepth^2 + ((Trans.numelements-1)*Trans.spacing)^2));
Receive = repmat(struct('Apod', ones(1,Trans.numelements), ...
                        'startDepth', P.startDepth, ...
                        'endDepth', maxAcqLength,...
                        'TGC', 1, ...
                        'bufnum', 1, ...
                        'framenum', 1, ...
                        'acqNum', 1, ...
                        'sampleMode', 'NS200BW', ...
                        'mode', 0, ...
                        'callMediaFunc', 0), 1, P.numAngles*Resource.RcvBuffer(1).numFrames);

% - Set event specific Receive attributes for each frame.
for i = 1:Resource.RcvBuffer(1).numFrames
    Receive(P.numAngles*(i-1)+1).callMediaFunc = 1;
    for j = 1:P.numAngles
        Receive(P.numAngles*(i-1)+j).framenum = i;
        Receive(P.numAngles*(i-1)+j).acqNum = j;
    end
end

%% Specify Recon structure arrays.
% - We need one Recon structure which will be reused for all frames.
Recon = struct('senscutoff', 0.6, ...
               'pdatanum', 1, ...
               'rcvBufFrame',-1, ...
               'IntBufDest', [1,1], ...
               'ImgBufDest', [1,-1], ...
               'RINums',1:P.numAngles);

% Define ReconInfo structures.
% We need na ReconInfo structures for the na steering angles.
ReconInfo = repmat(struct('mode', 4, ...  % default is to accumulate IQ data.
                   'txnum', 1, ...
                   'rcvnum', 1, ...
                   'regionnum', 1), 1, P.numAngles);
% - Set specific ReconInfo attributes.
if P.numAngles>1
    ReconInfo(1).mode = 'replaceIQ'; % replace IQ data
    for j = 1:P.numAngles  % For each row in the column
        ReconInfo(j).txnum = j;
        ReconInfo(j).rcvnum = j;
    end
    ReconInfo(P.numAngles).mode = 'accumIQ_replaceIntensity'; % accum and detect
else
    ReconInfo(1).mode = 'replaceIntensity';
end

%% Specify Process structure array.
pers = 20;
Process(1).classname = 'Image';
Process(1).method = 'imageDisplay';
Process(1).Parameters = {'imgbufnum',1,...   % number of buffer to process.
                         'framenum',-1,... % (-1 => lastFrame)
                         'pdatanum',1,...    % number of PData structure to use
                         'pgain',1.0,...     % pgain is image processing gain
                         'reject',2,...
                         'persistMethod','simple',... % none, simple, dynamic
                         'persistLevel',pers,...
                         'interpMethod','4pt',...  % method of interpolation
                         'grainRemoval','none',...
                         'processMethod','none',...
                         'averageMethod','none',...
                         'compressMethod','power',...
                         'compressFactor',40,...
                         'mappingMode','full',...
                         'display',1,...      % display image after processing
                         'displayWindow',1};

%% Specify SeqControl structure arrays. 
% should change depending on the applications at sequence and event parts
SeqControl(1).command = 'jump';
SeqControl(1).argument = 1;
SeqControl(2).command = 'timeToNextAcq';
% SeqControl(2).argument = 86 + 336 ;  % added 
SeqControl(2).argument = 160;  % 160 usec dlay between each acquisition
SeqControl(3).command = 'timeToNextAcq';
% SeqControl(3).argument = 2000 - (P.numAngles-1)*SeqControl(2).argument;  % ex : 2000 =  2 msec (~ 500 fps);  
SeqControl(3).argument = 20000 - (P.numAngles-1)*160;  % 20 msec
SeqControl(4).command = 'returnToMatlab';
nsc = 5; % nsc is count of SeqControl objects

% Specify Event structure arrays.
n = 1;
for i = 1:P.numFrames
    k = P.numAngles*(i-1);
    for j = 1:P.numAngles  % Acquire frame
        Event(n).info = 'Full aperture.';
        Event(n).tx = j;   % use steered TX structure.
        Event(n).rcv = k+j;
        Event(n).recon = 0;      % no reconstruction.
        Event(n).process = 0;    % no processing
        Event(n).seqControl = 2;
        n = n+1;
    end
    % Set last acquisitions SeqControl for transferToHost.
    Event(n-1).seqControl = [3,nsc];
    SeqControl(nsc).command = 'transferToHost'; % transfer all acqs in one super frame
    nsc = nsc + 1;
    % no recon
end
Event(n).info = 'recon and process';
Event(n).tx = 0;         % no transmit
Event(n).rcv = 0;        % no rcv
Event(n).recon = 1;      % reconstruction
Event(n).process = 1;    % process
Event(n).seqControl = 4;
n = n+1;

% --- If this last event is not included, the sequence stops after one pass, and enters "freeze" state
%     Pressing the freeze button runs the "one-shot" sequence one more time
%     For live acquisition in mode 0, simply comment out the 'if/end' statements and manually freeze and exit when the data looks good.
if simulateMode==2 || simulateMode==0 %  In live acquisiton or playback mode, run continuously, but run only once for all frames in simulation
    Event(n).info = 'Jump back to first event';
    Event(n).tx = 0;
    Event(n).rcv = 0;
    Event(n).recon = 0;
    Event(n).process = 0;
    Event(n).seqControl = 1;
end



%% User specified UI Control Elements

% User specified UI Control Elements
% - Sensitivity Cutoff
UI(1).Control =  {'UserB7','Style','VsSlider','Label','Sens. Cutoff',...
                  'SliderMinMaxVal',[0,1.0,Recon(1).senscutoff],...
                  'SliderStep',[0.025,0.1],'ValueFormat','%1.3f'};
UI(1).Callback = text2cell('%SensCutoffCallback');

% - Range Change

MinMaxVal = [64,300,P.endDepth]; % default unit is wavelength
AxesUnit = 'wls';
if isfield(Resource.DisplayWindow(1),'AxesUnits')&&~isempty(Resource.DisplayWindow(1).AxesUnits)
    if strcmp(Resource.DisplayWindow(1).AxesUnits,'mm');
        AxesUnit = 'mm';
        MinMaxVal = MinMaxVal * (Resource.Parameters.speedOfSound/1000/Trans.frequency);
    end
end
UI(2).Control = {'UserA1','Style','VsSlider','Label',['Range (',AxesUnit,')'],...
                 'SliderMinMaxVal',MinMaxVal,'SliderStep',[0.1,0.2],'ValueFormat','%3.0f'};
UI(2).Callback = text2cell('%RangeChangeCallback');

% Specify factor for converting sequenceRate to frameRate.
frameRateFactor = P.numAcqs;
%%
Resource.DisplayWindow(1).saveFrame = 'F:\outputsfolderfaria\VSXvideo.avi';

%% Save all the structures to a .mat file.
% and invoke VSX automatically
save(['MatFiles/',filename]);
disp([ mfilename ': NOTE -- Running VSX automatically!']), disp(' ')
VSX
commandwindow  % just makes the Command window active to show printout

%%  After VSX returns
disp ('Info:  Saving the RF Data buffer -- please wait!'), disp(' ')
[row, col, pages] = size(RcvData{1});
time = num2str(datestr(now,'mmddyyyy_HHMMSS'));
mem = [num2str(row),'_',num2str(col),'_',num2str(pages)];
filename2 = ['/LFHFRonlywater_RF_',ex_name,'_',mem,'_',time];

% --- save in .mat
% tic; 
% save([folder,filename2,'.mat'], 'RcvData','-v7.3');
% fprintf("Saving time for .mat: %2.2f sec \n",toc);

% --- save in .dat
tic;
raw = int16(zeros(row,col,pages));
raw = RcvData{1}(:,:,:);

matRF = reshape(raw,[row*col*pages 1]);

fid = fopen([folder,filename2, '.dat'], 'w');
fwrite(fid, matRF, 'int16');
fclose(fid);
fprintf("Saving time for .dat: %2.2f sec \n",toc);


return



%% **** Callback routines to be converted by text2cell function. ****
%SensCutoffCallback - Sensitivity cutoff change
ReconL = evalin('base', 'Recon');
for i = 1:size(ReconL,2)
    ReconL(i).senscutoff = UIValue;
end
assignin('base','Recon',ReconL);
Control = evalin('base','Control');
Control.Command = 'update&Run';
Control.Parameters = {'Recon'};
assignin('base','Control', Control);
return
%SensCutoffCallback

%RangeChangeCallback - Range change
simMode = evalin('base','Resource.Parameters.simulateMode');
% No range change if in simulate mode 2.
if simMode == 2
    set(hObject,'Value',evalin('base','P.endDepth'));
    return
end
Trans = evalin('base','Trans');
Resource = evalin('base','Resource');
scaleToWvl = Trans.frequency/(Resource.Parameters.speedOfSound/1000);

P = evalin('base','P');
P.endDepth = UIValue;
if isfield(Resource.DisplayWindow(1),'AxesUnits')&&~isempty(Resource.DisplayWindow(1).AxesUnits)
    if strcmp(Resource.DisplayWindow(1).AxesUnits,'mm');
        P.endDepth = UIValue*scaleToWvl;
    end
end
assignin('base','P',P);

evalin('base','PData(1).Size(1) = ceil((P.endDepth-P.startDepth)/PData(1).PDelta(3));');
evalin('base','PData(1).Region = computeRegions(PData(1));');
evalin('base','Resource.DisplayWindow(1).Position(4) = ceil(PData(1).Size(1)*PData(1).PDelta(3)/Resource.DisplayWindow(1).pdelta);');
Receive = evalin('base', 'Receive');
maxAcqLength = ceil(sqrt(P.endDepth^2 + ((Trans.numelements-1)*Trans.spacing)^2));
for i = 1:size(Receive,2)
    Receive(i).endDepth = maxAcqLength;
end
assignin('base','Receive',Receive);
evalin('base','TGC.rangeMax = P.endDepth;');
evalin('base','TGC.Waveform = computeTGCWaveform(TGC);');
Control = evalin('base','Control');
Control.Command = 'update&Run';
Control.Parameters = {'PData','InterBuffer','ImageBuffer','DisplayWindow','Receive','TGC','Recon'};
assignin('base','Control', Control);
assignin('base', 'action', 'displayChange');
return
%RangeChangeCallback
