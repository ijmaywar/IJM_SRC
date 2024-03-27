%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   Check a few detected peaks and make sure they look ok in the raw data.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Clear variables
clearvars

%% USER INPUTED VALUES

szn = '2021_2022';
location = "Bird_Island"; % Options: 'Bird_Island', 'Midway', 'Wandering'

%% Set Environment

% Matlab functions toolbox
addpath(genpath('/Users/ian/Documents/GitHub/'))

% Full_metadata sheet
fullmeta = readtable(strcat(GD_dir,'metadata/Full_metadata.xlsx'),'TreatAsEmpty',{'NA'});
% Specify the field season and location you are interested in
fullmeta = fullmeta(strcmp(fullmeta.Field_Season,szn) & strcmp(fullmeta.Location,location),:);

% set directories
GD_dir = "/Users/ian/Library/CloudStorage/GoogleDrive-ian.maywar@stonybrook.edu/My Drive/Thorne Lab Shared Drive/Data/Albatross/";
L1_dir = strcat(GD_dir,"L1/",location,"/Tag_Data/ECG/ECG_NRL/",szn,"/");

cd(L1_dir)
L1_fileList = dir('*.csv');
L1_fileList(startsWith({L1_fileList.name},'._')) = [];
L1_fileNames = string({L1_fileList.name});

%% Loop thru and process birds

for i = 14:length(L1_fileNames)
    %% load data to be detected
    namesplit = strsplit(L1_fileNames(i),'_');
    dep_ID = strcat(namesplit{1},'_',namesplit{2},'_',namesplit{3});

    %% Load ECG data
    m = readtable(L1_fileNames(i));
    disp(strcat("Data loaded for ",dep_ID))

    %% Load birdmeta
    birdmeta = fullmeta(strcmp(fullmeta.Deployment_ID,dep_ID),:);
    ON_DateTime = strcat(string(birdmeta.AuxON_date_yyyymmdd), " ", string(birdmeta.AuxON_time_hhmmss));
    ON_DateTime = datetime(ON_DateTime, 'InputFormat','yyyyMMdd HHmmss');

    %% Calculate new DateTimes
    if sum(strcmp(m.Properties.VariableNames,'corrected_idx'))==1
        new_DT = (ON_DateTime + seconds((m.corrected_idx-1)*(1/600)));
    elseif sum(strcmp(m.Properties.VariableNames,'corrected_idx'))==0
        disp(strcat("'corrected_idx' was not recorded for ",dep_ID,". And therefore, there were no GPS breaks."))
        new_DT = (ON_DateTime + seconds((m.idx-1)*(1/600)));
    end

    new_DT.Format = 'yyyy-MM-dd HH:mm:ss.SSSSSS';

    %% Put it in the table and change format to character so that it writes the file correctly.
    m.DateTime = string(new_DT);

    %% Save the table
    writetable(m,strcat(L1_dir,'/',dep_ID,'_L1.csv')); 
    disp("File saved.")

end
        