%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   Attach DateTimes to HRL ECG and OtherSensor data
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
L1_dir = strcat(GD_dir,"L1/",location,"/Tag_Data/ECG/",szn,"/");
L2_dir = strcat(GD_dir,"L2/",location,"/Tag_Data/ECG/",szn,"/");
GPS_dir = strcat(GD_dir,'L1/',location,'/Tag_Data/GPS/GPS_Catlog/',szn,'/2_buffer2km/');

% Matlab functions toolbox
addpath(genpath('/Users/ian/Documents/GitHub/AlbatrossFlightDynamics/'))

% Full_metadata sheet
fullmeta = readtable(strcat(GD_dir,'metadata/Full_metadata.xlsx'),'TreatAsEmpty',{'NA'});
% Specify the field season and location you are interested in
fullmeta = fullmeta(strcmp(fullmeta.Field_season,szn) & strcmp(fullmeta.Location,location),:);

% Start indices sheet
idx_tbl = readtable(strcat(GD_dir,"L0/",location,"/Tag_Data/",szn,"/Aux/HRL/2019-2020_HRL_start-detection-times.csv"),'Delimiter',',');

% Allow figures to be visible
set(0,'DefaultFigureVisible','on')

% suppress annoying warnings when reading Acc_L0 files
warning('off','MATLAB:table:ModifiedAndSavedVarnames')

%% Find data
cd(L1_dir)
L1_fileList = struct2table(dir('*.csv'));
L1_fileNames = string(L1_fileList.name);

%% Loop thru and process birds

for i = 1:1%height(L1_fileNames)
    %% load data to be deteced.

    namesplit = strsplit(L1_fileNames(i),'_');
    dep_ID = strcat(namesplit{1},'_',namesplit{2},'_',namesplit{3});

    L1_data = readtable(L1_fileNames(i));

    % Find start_idx
    start_idx = idx_tbl(strcmp(string(idx_tbl.bird),dep_ID),:).start;

    %% stop idx
    % FIND THESE VALUES BEFORE HAND BEFORE LOOPING THRU
    og_length = height(L1_data);
    figure
    plot(og_length-5000000:og_length,L1_data.ECG(og_length-5000000:og_length))
    disp('please click where the usable data ends')
    [stop_idx,~] = ginput(1);
    stop_idx = round(stop_idx);

    %% Trim data

    L1_data = L1_data(start_idx:stop_idx,:);
    x = L1_data.ECG;

    %% load template, template is extracted from the high SNR data .
    load('meanbeat');

    %% parameter 
    % change Ini = 1 to input the initialization by hand
    % IF the detection performance is not good, change the Ini = 1 to improve
    % the performance
    Ini = 1;
    
    % samples frequency
    fs = 600; 
    
    % L The length of the template, we do not recommend you change the length
    % of the template, this length has the best performance when 10 < L < 40
    param.L = 31;
    
    %  N number of noise sample account into consideration when calculate the probability
    param.N = 75;
    
    % Number of the models
    % M for the detection from left to right (constant)
    % M for the detection from right to left  (constant)
    % MV is variable, will change according to the data as time goes on
    param.M = 30;
    param.MV = 30;
    
    % local detrend
    x = locdetrend(x,fs,[1 .1]);
    
    % the low probbility peaks that you want to delete
    param.probthres = 0.2; 

    %% Differenced data 
    [x1_1,x1_2,s1_1,s1_2] = Diff_Down(x,s);

    %% test statistic for first several peaks 
    % make template length = L1  differenced data
    s1_1(param.L+1:end) = [];
    s1_2(param.L+1:end) = [];
    if Ini == 0
        %get the frist two peaks  differenced data
        [peak_left,P] = detFirstTwoPeakdiff(param.L,s1_1,x1_1);
        
        [peak_left,noPeakDet] = firstTwoPeak(peak_left,P);
        
        if(noPeakDet)
            disp('The first two peak are not clearly detected')
            figure
            plot(x1_1(1:5000))
            peak_left = input('please input the first two peaks in the figure:e.x.:[120 200]');
        end
    else
        figure
        plot(x1_1(1:1000))

        % Use findpeaks to find indices of local maxima
        PeakThreshold = input('Please input the threshold for the first two peaks: ');                  
        [pks, locs] = findpeaks(x1_1(1:1000),'MinPeakHeight',PeakThreshold)
        % peak_left = locs(1:2)'

        peak_left = input('please input the first two peaks (e.x.[120 200]): ');
        close all
    end

    %% detect by the differenced data from left to right

    T(1) = peak_left(2)-peak_left(1);
    % result from sequence 1
    % peak_left_s1 : peak detected from sequence 1
    % prob_left_s1 : probability of the peaks
    % interval_left_s1 : the interval between peaks
    [peak_left_s1,prob_left_s1,interval_left_s1] = MatchDetection(peak_left,T,param,x1_1,s1_1);
    
    % result from sequence 2
    [peak_left_s2,prob_left_s2,interval_left_s2] = MatchDetection(peak_left,T,param,x1_2,s1_2);
    
    % median Interval that will be used as a parameter in the following code
    param.medianInter1 = round(median([ interval_left_s1 interval_left_s2 ] ));
    
    % combine the two sets of peaks 
    [peak_left,prob_left] = compareTwoSetPeaks(peak_left_s1,peak_left_s2,prob_left_s1,prob_left_s2,s1_1,x1_1,param);
    
    %% flip the data to re-detect from right to left and get the first two peaks
    
    % YOU LEFT OFF TO START HERE. RUN THIS AND MAKE SURE THAT THE DTs of
    % the HEART BEATS CAN BE SAVED THEN RUN THE FULL FILE OVERNIGHT.

    % flip x1_1
    for j = 1:length(x1_1)
        x2_1(j,1) = x1_1(end-j+1);
    end
    
    % flip s1_1
    s2_1 = fliplr(s1_1);
    
    
    if Ini ==0
        [peak_right,P] = detFirstTwoPeakdiff(param.L,s2_1,x2_1);
        
        [peak_right,noPeakDet] = firstTwoPeak(peak_right,P);
        
        if(noPeakDet)
            disp('The first two peak are not clearly detected')
            figure
            plot(x2_1(1:5000))
            peak_right = input('please input the first two peaks:e.x.:[120 200]');
        end
        clear peak_2 P noPeakDet
    else 
        figure
        plot(x2_1(1:1000))

        % Use findpeaks to find indices of local maxima
        PeakThreshold = input('Please input the threshold for the first two peaks: ');
        [pks, locs] = findpeaks(x2_1(1:1000),'MinPeakHeight',PeakThreshold)
        % peak_right = locs(1:2)'
        peak_right = input('please input the first two peaks (e.x.[120 200]): ');
        close all
    end

    %% detect by the differenced data from right to left
    
    T(1) = peak_right(2)-peak_right(1);
    
    % results from right to left sequence
    [peak_right,prob_right,interval_right] = MatchDetection2(peak_right,T,param,x2_1,s2_1);
    
    % update the median interval after the second time detection
    param.medianInter1 = median(interval_right);
    
    %% combine the two results
    
    % combine the left-right & right-left result
    [peakCom,probCom] = compareTwoSetPeaks(peak_left,peak_right,prob_left,prob_right,s1_1,x1_1,param);

    %% Visualization of the result

    % original data and peak
    peak = peakCom*2 - 14; % peak in original data
    probability = probCom; % probability 
    figure
    plot(x)
    hold on
    y = x(peak);
    plot(peak,y,'*');
    legend('original data','Detected peak')
    title('Data and peaks') 
    
    % differenced data and peaks
    figure
    plot(x1_1)
    hold on 
    y = x1_1(peakCom);
    plot(peakCom,y,'*')
    title('Difference data and peaks')
    
    % %Histogram of the interval
    figure
    histogram(peak(2:end)-peak(1:end-1));
    title('Histogram of the interval')

    % %% Save date of the result peak and probability for each peak
    % date = datestr(now);
    % save(strcat(L2_dir,dep_ID,'_detectedPeak.mat'),'date','peak','probability');
    % 
    %% Save datetimes of peaks and probabilities
    
    og_idx = peak+start_idx-1;

    df_HeartBeats = cell2table(cell(length(peak),4));
    df_HeartBeats.Properties.VariableNames = {'DateTime','idx','og_idx','probability'};
    
    df_HeartBeats.DateTime = L1_data.DateTime(peak);
    df_HeartBeats.idx = peak';
    df_HeartBeats.og_idx = og_idx';
    df_HeartBeats.probability = probability';

    writetable(df_HeartBeats,strcat(L2_dir,'/',dep_ID,'_L2.csv')); 

end
    
    %% This is all stuff from Melinda's code (below)
    
    IBI = [0,diff(peak)];
    
    %% RESULTS TABLE: Peaks Meta Data - peak_index, peak_prob, instantaneous_IBI_bpm
    % First, Expand indices to reflect trim in beginning (so that peak indices
    % match original data)
    
    hz2ms = 1000/fs; % For 600 Hz, each row represents 1.66666666667 ms
    msInMinute = 60000; % 60000 ms in 1 minute
    
    full_peakix = peak+start-1;
    
    df_allpeaks = cell2table(cell(length(peak),4));
    df_allpeaks.Properties.VariableNames = {'peaks_ix','full_peaks_ix','peak_probability','IBI_bpm'};
    df_allpeaks.peaks_ix = peak';
    df_allpeaks.full_peaks_ix = full_peakix';
    df_allpeaks.peak_probability = probability';
    df_allpeaks.IBI_bpm = (msInMinute./(IBI*hz2ms))'; 
                                              
                                                 
    %% RESULTS TABLE: Full 600 Hz Resolution Vectors of Peaks, Probability, and Instantaneous IBI (basically same thing as Peaks Meta Data, just in full)
    peaksfull = zeros(height(m_full),3);
    peaksfull = array2table(peaksfull);
    peaksfull.Properties.VariableNames = {'peak','peak_prob','IBI_bpm'};
    peaksfull.peak(full_peakix) = 1;
    peaksfull.peak_prob(full_peakix) = probability;
    peaksfull.IBI_bpm(full_peakix) = 60000./(IBI*hz2ms);
    
    peaksfull.peak_prob(peaksfull.peak_prob==0) = NaN;
    peaksfull.IBI_bpm(peaksfull.IBI_bpm==0) = NaN;
    
    %% RESULTS TABLE: Summarize Heart Rate Metrics in 30-second windows: 
    % Save Table of: 
    % In 30-s windows: 
    % 1. DateTime (mid ix1 and ix2)
    % 2. ix1
    % 3. ix2
    % 4. Median_IBI_bpm     % median instantaneous IBI
    % 5. Calculated_bpm "Classic Heart Rate Metric" % num beats in window/time
    % 6. Median Probability
    % 7. Min Probability
    % 8. Percent Probability < .6
    nsec = 30; % number of seconds in window
    w = nsec*fs;
    winvec = 1:w:height(peaksfull);
    div1=60/nsec;
    nrow = length(1:length(winvec)-1);
    
    out1 = NaT(nrow,1);     % 1. DateTime
    out2 = NaN(nrow,1);     % 2. ix1
    out3 = NaN(nrow,1);     % 3. ix2
    out4 = NaN(nrow,1);     % 4. med_instIBI
    out5 = NaN(nrow,1);     % 5. calcIBI
    out6 = NaN(nrow,1);     % 6. med_peakProb
    out7 = NaN(nrow,1);     % 7. min_peakProb
    out8 = NaN(nrow,1);     % 8. perc_lowProb
    
    
     for j = 1:length(winvec)-1
          ixs = winvec(j):winvec(j+1)-1;
          nbeats = sum(peaksfull.peak(ixs));
          nr_dt = ixs(1)+w/2;
          
          out1(j) = start_time + milliseconds(nr_dt*hz2ms);
          out2(j) = ixs(1);
          out3(j) = ixs(end);
          out4(j) = nanmedian(peaksfull.IBI_bpm(ixs));
          out5(j) = nbeats*div1;
          out6(j) = nanmedian(peaksfull.peak_prob(ixs));
          out7(j) = nanmin(peaksfull.peak_prob(ixs));
          out8(j) = length(find(peaksfull.peak_prob(ixs)<.6))/nbeats;
    
     end
    heartrate_summ_df = [out2,out3,out4,out5,out6,out7,out8];
    heartrate_summ_df = array2table(heartrate_summ_df) ;
    heartrate_summ_df.Properties.VariableNames = {'ix1','ix2','med_instIBI','calcHeartBeat','med_peakProb','min_peakProb','perc_lowProb'};
    heartrate_summ_df.DateTime = out1;
    
    %% Save Tables:
    writetable(df_allpeaks,strcat(dropdir,'indices_peaks/',birdi,'_peaks_index_df.txt'),'Delimiter',',') % Peak Index Data Frame 
    writetable(peaksfull, strcat(dropdir,'peaks_fullres/',birdi,'_peaks_fullres_df.txt'),'Delimiter',',')  % Full Resolution Mat with Peaks, Prob, Instantaneous IBI: 'peak','peak_prob','IBI_bpm'
    writetable(heartrate_summ_df, strcat(dropdir,'heart-rate_summ_30s/',birdi,'_heartrate_summ_df.txt'),'Delimiter',',') % Heart Beat Metrics Summarized in 30second windows: 'ix1','ix2','med_instIBI','calcIBI','med_peakProb','min_peakProb','perc_lowProb','DateTime'
    
    % %Histogram of the interval
    h = histogram(df_allpeaks.IBI_bpm,50)
    title('Histogram of IBI')
    saveas(h, strcat(dropdir,'figures/histogram_IBI/',birdi,'_hist-IBI.png'))
    clear h
    
    % %Histogram of the probability
    h = histogram(df_allpeaks.peak_probability)
    title('Histogram of Peak Probability')
    saveas(h, strcat(dropdir,'figures/histogram_prob/',birdi,'_hist-prob.png'))
    clear h








