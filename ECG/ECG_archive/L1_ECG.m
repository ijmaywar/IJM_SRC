%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   Attach DateTimes to NRL ECG and OtherSensor data
%
%   Reformat data to follow a uniform format (uniformat):
%       DateTime in GMT
%       Ax
%       Ay
%       Az
%       Pressure
%       Temperature
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Clear variables
clearvars

%% USER INPUTED VALUES

szn = '2019_2020';
location = "Bird_Island"; % Options: 'Bird_Island', 'Midway', 'Wandering'
computer = "MacMini";

%% Set Environment

% Matlab functions toolbox
addpath(genpath('/Users/ian/Documents/GitHub/AlbatrossFlightDynamics/'))

% set directories
GD_dir = findGD(computer);
L0_dir = strcat(GD_dir,"L0/",location,"/Tag_Data/",szn,"/Aux/NRL/L0_1_Decompressed/2_ECG/");
L1_dir = strcat(GD_dir,"L1/",location,"/Tag_Data/ECG/",szn,"/");
GPS_dir = strcat(GD_dir,"L1/",location,"/Tag_Data/GPS/GPS_Catlog/",szn,"/2_buffer2km/");

% Matlab functions toolbox
addpath(genpath('/Users/ian/Documents/GitHub/AlbatrossFlightDynamics/'))

% Full_metadata sheet
fullmeta = readtable(strcat(GD_dir,'metadata/Full_metadata.xlsx'),'TreatAsEmpty',{'NA'});
% Specify the field season and location you are interested in
fullmeta = fullmeta(strcmp(fullmeta.Field_season,szn) & strcmp(fullmeta.Location,location),:);

% Tag timings sheet
Tag_Timings = readtable(strcat(GD_dir,"L0/",location,"/Tag_Data/",szn,"/Aux/NRL/Tag_Meta_Timings.csv"),'Delimiter',',');

% Prevent figures from popping up when running in the background
set(0,'DefaultFigureVisible','off')

% suppress annoying warnings when reading Acc_L0 files
warning('off','MATLAB:table:ModifiedAndSavedVarnames')

%% Find data

cd(GPS_dir)
GPS_fileList = struct2table(dir('*.csv'));
GPS_fileNames = string(GPS_fileList.name);

cd(L0_dir)
L0_fileList = struct2table(dir('*.txt'));
L0_fileNames = string(L0_fileList.name);

CheckMetaGPSUnique(L0_fileList,GPS_fileList,fullmeta)

%% Loop thru and process birds

for i = 9:height(L0_fileNames)
    
    %% load data to be deteced.

    namesplit = strsplit(L0_fileNames(i),'_');
    dep_ID = strcat(namesplit{1},'_',namesplit{2},'_',namesplit{3});

    % Make sure this data is usable based on Tag_Timings
    Usable = Tag_Timings(strcmp(Tag_Timings.dep_ID,dep_ID),:).Usable;

    %%
    if Usable == 1

        meta = struct;
        meta.bird = dep_ID;
        
        %% Find HRL_on time from metadata
        birdmeta = fullmeta(strcmp(fullmeta.Deployment_ID,dep_ID),:);
        ON_DateTime = strcat(string(birdmeta.AuxON_date_yyyymmdd), " ", string(birdmeta.AuxON_time_hhmmss));
        ON_DateTime = datetime(ON_DateTime, 'InputFormat','yyyyMMdd HHmmss');
    
        % Load data
        m = readtable(L0_fileNames(i));
        
        % Add DateTime column
        samplingRate = 1/600; % 600 Hz
        nSamples = height(m);
        
        m.DateTime = (ON_DateTime + seconds(0:samplingRate:(nSamples-1)*samplingRate))';
    
        %% Format DateTime
        m.DateTime.Format = 'yyyy-MM-dd HH:mm:ss.SSSSSS';
        if strcmp(location,"Bird_Island")
            m.DateTime.TimeZone = "GMT";
        elseif strcmp(loction,"Midway")
            m.DateTime.TimeZone = "Pacific/Midway";
            % convert to GMT
            m.DateTime.TimeZone = "GMT";
        end
    
        % Format Column names
        if strcmp(intersect("EEG",m.Properties.VariableNames),"EEG")
            m = renamevars(m,"EEG","ECG");
        end
    
        m = m(:,["DateTime","ECG"]);

        %% Trim to on_bird times (between trips are not taken out)
        
        GPSdata = readtable(strcat(GPS_dir,dep_ID,"_GPS_L1_2.csv"));
        [m,timetbl,trim_meta_tbl] = TripTrim(m,GPSdata,dep_ID);

        meta.trim = trim_meta_tbl;
        meta.timetbl = timetbl;

        if trim_meta_tbl.skip == 0
            writetable(m,strcat(L1_dir,dep_ID,'_ECG_L1.csv')) %write m data
        end

        parsave(meta,strcat(L1_dir,'meta_structures/',dep_ID,'_meta.mat'));

        m = []; % Try to save space
    
    else
        disp(strcat(dep_ID, " is unusable."))
    
    end

end






