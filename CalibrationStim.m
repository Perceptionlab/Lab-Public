% calibrationStim.m
%
% All-in-one script for taking photometer measurements, fitting a gamma
% function, and generating/saving the look-up tables
% For each stimulus presentation, you can type in the photometer
% measurement (cd/m2) and hit "enter". If you start typing it incorrectly,
% you can delete what you typed by pressing backspace. Curve fit and color-
% lookup table (CLUT) are generated at the end. If you mess up typing in
% the numbers, you can potentially retrieve it and then run the
% curve-fitting separately.
%
% Two ways of using it:
% (1) If you're only presenting stimuli in grayscale and want a quick set
% of measurements, you can set it to measure "all three together"
% The .mat file gets saved out with a variable "clut"; you don't need to do
% anything else other than read it into your experiment
%
% (2) If you're taking separate red, green, and blue measurements, you run
% the script 3 times and a separately labeled file is generated each time
% you run it. You then combine data from the 3 files to get your clut:
%
% % clear all;
% % red = load('red_file.mat');
% % green = load('green_file.mat');
% % blue = load('blue_file.mat');
% % clut = [red.gammaTable green.gammaTable blue.gammaTable];
% % save CLUT_BoothN_resolution_refreshrate_date.mat
%
% How to read a color-lookup table for your experiment:
%
% % load myCLUTFile.mat
% % Screen('LoadNormalizedGammaTable', wPtr, clut)
%
% For stereoscope setup, see stereoscope page on how to load separate cluts
% for the left and right monitors
%
% adapted from PTB's CalibrateMonitorPhotometer by AK (4/17/14)
% cleaned up and commented on 6/16/14
% added check for appropriate size on 6/9/15
% 7/17/15 - loaded in a linear gamma table before taking the measurements (this
% shifts things a bit, but mostly in color balance)

clear all;close all

AssertOpenGL;
KbName('UnifyKeyNames')
screens = Screen('Screens');
%screenNumber = max(screens);
if numel(screens) > 2
    screenNumber = input('You have more than 2 monitors. Select which monitor to test (i.e. 1, 2, 3): ');
    while isempty(screenNumber) 
        screenNumber = input('No such monitor number. Try again');
    end
end

% I don't know how much it matters, but if you're feeling neurotic, you may
% want to take your measurements with the same resolution and refresh rate
% that you use for stimulus presentation
disp('Check your resolution and refresh rate')

%% set stimulus parameters
params.numMeasures = input('Enter # of measurements (should be a power of 2 plus 1, ideally (9, 17, 33, etc.)): ');
% this is so they're evenly spaced (last point won't be, but it'll get dealt with in curve fitting)
% or you can use linspace -- just be sure to round your decimal points
params.checktimes = input('How many times per point?: ');
while isempty(params.checktimes) == 1
    params.checktimes = input('Error. Try again. How many times per point?: ');
end
params.levels = [0:256/(params.numMeasures - 1):256];
params.levels(end) = 255;
params.square_size = 250; %length of one side (px)
params.whichMeasure = input('Measure red(1), green(2), or blue(3), or all three together(0)? ');
if params.whichMeasure == 0
    params.rgb = [1 2 3];
else
    params.rgb = params.whichMeasure;
end
params.gLabels = {'r' 'g' 'b'};
params.booth = input('Enter station number (or other identifier): ','s');


%% stimulus presentation

ListenChar(2); %suppress keyboard input temporarily in case characters are typed accidentally during pause screen
[w screenRect]=Screen('OpenWindow',screenNumber,128);
hz=Screen('NominalFrameRate', w);

% set the color look-up table to be linear-- didn't do this in older versions; makes a difference, mostly in color balance
oldTable= Screen('LoadNormalizedGammaTable',w,repmat(linspace(0,1,256)',1,3));

HideCursor;

Screen(w, 'TextSize',24);
Screen(w,'DrawText','For each screen, enter value in cd/m2, and press enter. Press Space Bar to begin',50,50,255);
Screen('Flip', w);
while 1
    [keyIsDown,seconds,keyCode] = KbCheck;
    if keyCode(KbName('space'))
        break;
    end
end
WaitSecs(.5);
ListenChar(0);

params.bgmat = 255*[ones(screenRect(4), screenRect(3)/(2)) zeros(screenRect(4), screenRect(3)/(2))];
i = randperm(numel(params.bgmat));
params.bgmat(:) = params.bgmat(i);
vals = []; resp = zeros(params.checktimes,1);

for stim = 1:length(params.levels)
    
    bgtex = Screen('MakeTexture', w,params.bgmat);
    sq_color = zeros(1,3);
    sq_color(params.rgb) = params.levels(stim);
    Screen('DrawTexture',w,bgtex)
    Screen('FillRect',w, sq_color,[screenRect(3)/2-params.square_size/2 screenRect(4)/2-params.square_size/2 screenRect(3)/2+params.square_size/2 screenRect(4)/2+params.square_size/2]);
    Screen('Flip',w);
    
    fprintf('\n============\n============\n Point #%d \n\n',stim);
    
    for checktimecount = 1:params.checktimes
        currName = sprintf('Value #%d? ', checktimecount);
        currNum = input(currName);
        while isempty(currNum) == 1
            currNum = input('Try Again. Value? ');
        end
        resp(checktimecount,1) = currNum;
        clear currNum
    end
    
    resp = mean(resp);
    vals = [vals;resp]; %
    
end


Screen('CloseAll');

%% Curve fitting:
% the rest borrows a lot from CalibrateMonitorPhotometer
% (if you want to do yor own curve fitting, you can generate a CLUT by
% fitting a gamma function (ax^g+b) to the raw values or (x^g) to the
% normalized values. Taking the inverse of that function and scaling from
% 0-1 gives you the CLUT

inputVals = params.levels; %inputVals = gun values of the square patch
rawMeasurements = vals; % rawMeasurements = photometer measurements

%Normalize values
displayRange = (max(rawMeasurements) - min(rawMeasurements));
displayBaseline = min(rawMeasurements);
vals = (vals - displayBaseline)/(max(vals) - min(vals));
inputV = inputVals/255;

% Gamma function fitting: x^g
% Alternatively, you could add a couple extra parameters (so it's (ax^g+b))
% and use fminsearch to fit the points. However, since
% the measurements get normalized (above), you don't really need the extra
% a and b parameters (or at least the difference will be very small)
g = fittype('x^g');
fittedmodel = fit(inputV',vals,g);
displayGamma = fittedmodel.g;
gammaTable = ((([0:255]'/255))).^(1/fittedmodel.g);
gammaFit = fittedmodel([0:255]/255);
if length(params.rgb) ==3;
    gammaTable = repmat(gammaTable,1,3);
end

%plot it
figure;plot([0:255]/255, gammaFit);
hold on;scatter(inputV,vals,'.');
hold on;plot([0:255]/255, gammaTable,'r');xlim([0 1]);ylim([0 1]);
legend({'gamma fit' 'raw measurements' 'gamma inverse (for clut)'})

if size(gammaTable,1)~=256 
    error('Size of gamma table is wrong. Something went bad!')
end

%generate filename
timestamp = datestr(clock, 0);
timestamp([3 7 12]) = '_';
timestamp([15 18]) = [];
filename = ['Photometer_Measurements_Station' params.booth '_' [params.gLabels{params.rgb}] '_' num2str(screenRect(3)) 'x' num2str(screenRect(4)) '_'  num2str(hz) 'Hz_' timestamp];

%save it
if params.whichMeasure == 0 %grayscale
    clut = gammaTable;
    save(filename,'rawMeasurements','inputVals','displayGamma','gammaTable','gammaFit','params','clut');
else % separate r,g,b measurements
    save(filename,'rawMeasurements','inputVals','displayGamma','gammaTable','gammaFit','params');
end


%% for separate r,g,b measurements once you're done with all 3:

% clear all;
% red = load('red_file.mat');
% green = load('green_file.mat');
% blue = load('blue_file.mat');
% clut = [red.gammaTable green.gammaTable blue.gammaTable];
% save CLUT_BoothN_resolution_refresh_date.mat