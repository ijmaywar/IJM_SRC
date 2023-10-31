 clear all;
 % Author : Chen Cui
 % Data : 02/2021
 % This code is used to detect the heart beat
 % IMPORTANT : When running the main function, this function requires 
 % the chronux toolbox to be on the search path.
 % To improve the accuracy of detection, you can choose to INPUT the initialization
 % of the detection.Set the Ini = 1 to input by hand, otherwise set Ini = 0; 
 % Defult Ini = 0, detect the first two peaks auto.IF Ini =1, you need to iput twice.

 %% Set environment
 addpath(genpath("~/Dropbox/Academia/SUNY/Project_Components/BIRD_ISLAND/Analyses/Functions_Toolboxes/Matlab/SensorFunctionToolboxes/"))
 addpath(genpath("~/Dropbox/Academia/SUNY/Project_Components/BIRD_ISLAND/Analyses/Functions_Toolboxes/Matlab/ECG_ChenChui/chronux_2_12/"))
 addpath(genpath("~/Dropbox/Academia/SUNY/Project_Components/BIRD_ISLAND/Analyses/Energetics/ECG_to_HeartBeat/ECG-Bayes-Filter_ChenChui/"))
 datadir = '/Volumes/GoogleDrive/My Drive/Thorne Lab/THORNE_LAB/Data/Conners_Bird_Island/2019_2020/Tag_Data/L0_raw-data/Neurologgers/L0_1_Raw_Decompressed_txt/2_EEG/';
 dropdir = '/Volumes/GoogleDrive/My Drive/Thorne Lab/THORNE_LAB/Data/Conners_Analysis/ECG_HeatRate/extract_heart_rate/2021_04_20/';
 %% load data
 
 cd(datadir)
 files=dir('*.txt');
 
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% Routine needed to clear ghost files if working in Seagate Hard Drive
% Ignore except in very specific cases where ghost files are created and
% then read by the function dir.
skipx=[];
for k = 1:length(files)
skipx(k)=~startsWith(files(k).name,'._','IgnoreCase',true);
end

files = files(find(skipx));
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

%% Import Meta Data
% Import Neurologger Start Times:
meta_t = readtable('/Volumes/GoogleDrive/My Drive/Thorne Lab/THORNE_LAB/Data/Conners_Bird_Island/2019_2020/Tag_Data/L1_cleaned-data/ACC_Neurologgers_L1_1_Analysis_Ready/L1_1_Analysis_Ready_Trimmed_StartTimes.txt');
% These have the original time AND the time associated with the trimmed analysis-Ready sensor files. We will use the original time here. 

meta_start_ix = readtable('/Volumes/GoogleDrive/My Drive/Thorne Lab/THORNE_LAB/Data/Conners_Analysis/ECG_HeatRate/meta/2019-2020_HRL_start-detection-times.txt');

%% Set Global Parameters

%% load template, template is extracted from the high SNR data .
 load('meanbeat');

 %% Set global parameters 
 % change Ini = 1 to input the initialization by hand
 % IF the detection performance is not good, change the Ini = 1 to improve
 % the performance
 
 % MGC - First I am going to use Ini = 0 for all birds in a loop. If
 % detection is not good for some birds, I will repeat, using Ini = 1. 
  Ini = 0;
 
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

  % the low probbility peaks that you want to delete
  param.probthres = 0.2; 

% f_size= extractfield(files,'bytes');
% xvec = 1:length(files);
% newarry = [xvec',f_size'];
% sorted_arry = sortrows(newarry,2);
% ix_ordered = sorted_arry(:,1);
% files(ix_ordered).name

%% Run bayesian model peak finder in loop

% For GHAL_42, file is too big and maxes out my memory within loop (size of
% GB in memory grows to more than 5x the original size of file). To get
% around this, I am going to chop GHAL_42's file into smaller 1GB chunks
% for processing. Then I will stitch them back together. Note: when reading
% in a full file, readtable I've found to actually be faster than textscan.
% Alternatively, Tziporah - you may want to explore saving all the EEG data
% as .mat files - this should optimize the reading and writing process and
% you can use the matfile.m function to convert .mat to a matfile allowing
% you to read only portions of it in at a time (or the whole thing). For a
% >5GB file, the .matfile object is only 500 MB


for i = 1:length(files)


m_full= readtable(strcat(datadir,files(i).name));
m_full.Properties.VariableNames = {'EEG'}; 
tmp = split(files(i).name,"_");
birdi=strcat(tmp{1},"_",tmp{2});


%% Match Bird ID and Find Time of Neurologger Start and Index for Trimming File
birdid_chunks=strsplit(birdi,"_");
bird2match=strcat(birdid_chunks{1},birdid_chunks{2});

matchx = find(contains(meta_t.bird,bird2match));
start_time = meta_t.originalstart(matchx);

 %% Trim start so that beginning of signal has a clear heart beat pattern. 
% This is necessary because there is loud interference signal at beginning
% of deployments.

% Match bird_id with row in ID column of metadata
matchx2 = find(contains(meta_start_ix.bird,birdi));
start = meta_start_ix.start(matchx2);

% Trim signal using start index - will not use detection on full dataset,
% but will store indices of peaks related to full dataset for ease of
% synching datasets. Two files also need their ends to be trimmed due to
% loud interference at end of signal. 

if birdi=="BBAL_106"  
   endx = 384230000;
   m = m_full.EEG(start:endx);
elseif birdi=="BBAL_99"    
   endx = 164075000;
   m = m_full.EEG(start:endx); 
else
   m = m_full.EEG(start:end);
end
 


 %% local detrend
x = locdetrend(m,fs,[1 .1]); % This works beautifully - (should also try on pressure timeseries)
 
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
    plot(x1_1(1:5000))
    peak_left = input('please input the first two peaks:e.x.:[120 200]');
end

%% detect by the differenced data from left to right - this is the longest step in the process
tic
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
toc

% This chunk of code takes a long time, for example:
% 5 hours for a 4.3 GB file
% 10.8 hours for a 4.5 GB file (WHOA)
% 9 hours for 4.5 gb 

%% flip the data to re-detect from right to left and get the first two peaks
% flip x1_1
for q = 1:length(x1_1)
    x2_1(q,1) = x1_1(end-q+1);
end
clear q

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
    plot(x2_1(1:5000))
    peak_right = input('please input the first two peaks in the figure:e.x.:[120 200]');
end
%% detect by the differenced data from right to left

tic
T(1) = peak_right(2)-peak_right(1);

% results from right to left sequence
[peak_right,prob_right,interval_right] = MatchDetection2(peak_right,T,param,x2_1,s2_1);

% update the median interval after the second time detection
param.medianInter1 = median(interval_right);
toc
% 11 minutes for 4.33 GB file
% 14 minutes for 4.5 GB file (i = 15)
%% combine the two results

% combine the left-right & right-left result
tic
[peakCom,probCom] = compareTwoSetPeaks(peak_left,peak_right,prob_left,prob_right,s1_1,x1_1,param);
toc
%1.46 hours for 4.33 GB file
% 1.71 hours for 4.5 GB
% 49 min for 4.5 gb
% 2.5 hrs for 4.3 gb

%% Calculate Peaks and Probability, and IBI
peak = peakCom*2 - 14; % peak in original data
probability = probCom; % probability 
IBI = [0,(peak(2:end)-peak(1:end-1))];

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

%% Plot and Save Figures
% original data and peak
% plot(x)
% hold on
% y = x(peak);
% plot(peak,y,'*');
% hold on
% plot(peak,probability,'--bo')
% legend('original data','Detected peak')
% title('Data and peaks') 
% hgsave(strcat(dropdir,'figs_sensor_state/',birdi,'_hmm_optimC_statefig.fig'),'-v7.3')

% differenced data and peaks
figure
plot(x1_1)
hold on 
y = x1_1(peakCom);
plot(peakCom,y,'*')
title('Difference data and peaks')
hold on
plot(peakCom,probCom,'--bo')
hgsave(strcat(dropdir,'figures/differenced_data_and_peaks/',birdi,'_peaks.fig'),'-v7.3')
close all

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

clearvars -except datadir dropdir files meta_t meta_start_ix i s Ini fs param ix_ordered


end