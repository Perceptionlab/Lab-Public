function filetoclut(DD,MMM,YYYY,StationNum)
%This function will automatically convert the filenames into the CLUT
%This function will work anywhere as long as there is a proper setpath. it
%assumes that the files are in the current directory. Otherwise it will
%make an error message.
%DD should be in digit. Single day is in single digit format
%MMM should have ' ' and is a string, first letter of month is Caps
%YYYY should be in digit.
%StationNum is a digit for the station number.
%NOTE: I DIDN'T WRITE THIS FUNCTION TO INCLUDE TIME. So if you have
%multiple files with the same date, you should probably remove those files
%you don't want away from the current folder.

if nargin < 1
    error('Not enough Input. DD and YYYY are in digits, and MMM is a string. Use apostrophe');
end
if nargin < 4
    error('You did not specify monitor name');
end


%% Search for filenames in the current directory that starts with Photometer.
currname = sprintf('Photometer_Measurements_Station%d*', StationNum);
filenamedir = dir(currname);
if isempty(filenamedir)
    error('Cannot find files. Are you in the correct directory?');
end

x = 1; %counter
%Now we only look at filenames that satisfies the DD, MMM, YYYY
for i = 1:size(filenamedir,1)
    InputDate = sprintf('%d_%s_%d',DD,MMM,YYYY);
    %We find each string with the DD_MMM_YYYY. 
    value = strfind(filenamedir(i).name,InputDate);
    if value > 0 %If something matches, we save that filename to a new var
        Thenames{x,1} = filenamedir(i).name;
        x = x+1;
    end
end

%% Look at individual filenames and find R,G,B in the name.
%These correspond to the red, green, blue data.
for i = 1:size(Thenames,1)
    %replace _ with spaces. Split the new string. The RGB always stored at the same spot
    currname = strsplit(strrep(Thenames{i,1},'_',' '));
    %Compare the strings. Corresponding RGB value stored as filenames
    %Then save the filename string into a variable that will be loaded.
    %Note the { curly fries } . Use it to grab strings from a cell.
    if strcmp(currname(4),'r') == 1 || strcmp(currname(4),'R') == 1
        fileRed = Thenames{i}; %curly fries
    elseif strcmp(currname(4),'b') == 1 || strcmp(currname(4),'B') == 1
        fileBlue = Thenames{i}; %curly fries
    elseif strcmp(currname(4),'g') == 1 || strcmp(currname(4),'G') == 1
        fileGreen = Thenames{i}; %curly fries
    end
    
    clear currname
    
end

%% Load'em all and save CLUT
red = load(fileRed);
green = load(fileGreen);
blue = load(fileBlue);
clut = [red.gammaTable green.gammaTable blue.gammaTable];

currname = strsplit(strrep(Thenames{i,1},'_',' '));
filename = ['CLUT_' currname{3} '_' currname{5} '_' currname{6} '_' num2str(DD) '_' MMM '_' num2str(YYYY) '.mat'];
save (filename, 'clut', 'red', 'green', 'blue');


fprintf('\n\n You have just compiled %s with a configuration of %s, %s \n\n', currname{3},currname{5},currname{6});
clear currname


end

