%% Clear variables
clearvars

%% User Inputted Values

location = 'Midway'; % Options: 'Bird_Island', 'Midway'
szn = '2022_2023';
AuxType = "Technosmart"; % Options: "Technosmart", "NRL"

%% Set directory paths
GD_dir = '/Users/ian/Library/CloudStorage/GoogleDrive-ian.maywar@stonybrook.edu/My Drive/Thorne Lab Shared Drive/Data/Albatross/';
Acc_dir = strcat(GD_dir, 'L1/', location, '/Tag_Data/Acc/Acc_',AuxType,'/', szn, '/');
GLS_dir = strcat(GD_dir, 'L1/', location, '/Tag_Data/Immersion/GLS/', szn, '/');
write_dir = strcat(GD_dir, 'L4/', location, '/Tag_Data/Acc/',szn,'/');

cd(Acc_dir);
acc_files = dir('*.csv');

% Define onwaterBaseline (times 2 in MATLAB code)
onwaterBaseline = 2.5e-04;

%%
for i = 1:length(acc_files)
    %%
    current_bird = extractBefore(acc_files(i).name,length(acc_files(i).name)-10);
    
    %%
    m = readtable(acc_files(i).name);
    mean_Az = mean(rmmissing(m.Az));

    %% Break up m into continuous chunks
    
    % Find indices where NaN values occur
    cont_indices = ~isnan(m.Az)';
    
    % Calculate the differences between consecutive indices where NaN occurs
    diff_cont_indices = diff([0, cont_indices, 0]);
    
    % Find the starting and ending indices of continuous segments without NaN
    start_indices = find(diff_cont_indices == 1);
    end_indices = find(diff_cont_indices == -1) - 1;
        
    %% Loop thru continuous chunks
    for j = 1:numel(start_indices)
        m_chunk = m(start_indices(j):end_indices(j),:);
        center_Az = m_chunk.Az - mean_Az;
        pp_Az = bandpass(center_Az,[2,4.5],25);
        Mvar_Az = movvar(pp_Az,2*(60*25));
        logic_mAvg = Mvar_Az<=onwaterBaseline*2;
        breaks = reshape(find(diff([0;logic_mAvg;0])~=0),2,[]);
        
        % If breaks is empty, the bird is never on-water
        if ~isempty(breaks)

            % If the last break occurs when the data end, fix the last index
            if breaks(2,width(breaks)) == height(m_chunk)+1
                breaks(2,width(breaks)) = height(m_chunk);
            end
    
            current_dt_break = array2table(m_chunk.DateTime(breaks)','VariableNames',{'Start_water_dt','Stop_water_dt'});
            if j==1
                dt_breaks = current_dt_break;
            else
                dt_breaks = vertcat(dt_breaks,current_dt_break);
            end

        end
    end

    %%
    writetable(dt_breaks, strcat(write_dir,current_bird,'_Acc_L4_OWB.csv'));

end
