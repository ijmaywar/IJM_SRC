%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Prep Technosmart Acc data for analysis:
%
% M. Conners, I. Maywar
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%% NOTE: This code ignores the mag data since we are not using it from
%%%% the 2019-2020 AGM tags. If need to prep AGM data for analysis, then
%%%% this requires another intermediate step of calibrating the
%%%% magnetometer data. Summary: MAG DATA HERE NOT CALIBRATED

% STEPS in this code:
%
% 1. Check for upside-down tag placements - for Technosmart tags, there
% should be none, but including this to have a conservative check. 
%
% 3. Check time intervals for negative time steps and samples not taken at 25 Hz.
% Expand with NAs if necessary
%
% 4. Interpolate P and Temp
%
% 5. Write file

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [m,meta_tbl] = s2_Acc(m,birdid,fullmeta)

    %% Meta

    meta_tbl = table(cell(1,1),cell(1,1),zeros(1,1),cell(1,1),zeros(1,1),zeros(1,1),zeros(1,1),zeros(1,1),zeros(1,1),cell(1,1),zeros(1,1),'VariableNames', {'BirdID','TagType','Z-Mean-G','Z-Orientation','Dur-Days','Num_Breaks','Max_Break_Sec','Last_Row_Deleted','Zeros_Removed','Warning','skip'});                     

    birdmeta = fullmeta(strcmp(fullmeta.Deployment_ID,birdid),:);
    tagtype = birdmeta.Aux_TagType{1};

    meta_tbl.("BirdID")(1,:) = {birdid};
    meta_tbl.("TagType")(1,:) = {tagtype};

    %% 1.
    % -------------------------------------------------------------------------
    % 1. Pre-check to make sure tag was put on correctly 
    % For all birds - do automated check for upside-down tag and automatically correct using euler rotation matrix if necessary:
    % -------------------------------------------------------------------------
    
    z_mean = mean(m.Az, 'omitnan');
    meta_tbl.("Z-Mean-G")(1,:) = z_mean;
    
         if z_mean>0
             meta_tbl.("Z-Orientation")(1,:) = {'Correct'};
             Q = euler2rotmat(pi/180*[0 0 0]); % no flip necessary
         else
             meta_tbl.("Z-Orientation")(1,:) = {'Upside Down'};
             Q = euler2rotmat(pi/180*[0 180 180]); % Forward-Right-Up -> Flip upside down to right side up
    
         end
         
         % Use Q to correct tag frame 
         % Rotate Accelerometer Sensor Frame
         A = [m.Ax, m.Ay, m.Az];
         Av = rotate_vecs(A,Q); % Use Q to rotate A
         m.Ax = Av(:,1); % replace rotated Acc data
         m.Ay = Av(:,2); % replace rotated Acc data
         m.Az = Av(:,3); % replace rotated Acc data
         clear A Av
        
    %% 
    % -------------------------------------------------------------------------
    % 2. SENSOR FRAME ROTATION
    % Rotate Acc and Mag sensor frames to align with each other and the bird frame:
    % -------------------------------------------------------------------------
    
        Acc = [m.Ax, m.Ay, m.Az];% Acc data in ENU (East-North-Up)
    
        m.Ax = Acc(:,1);
        m.Ay = Acc(:,2);
        m.Az = Acc(:,3);
    
        clear Acc
        
        % plott([m.Ax,m.Ay,m.Az],25)
    
    %%
    % -------------------------------------------------------------------------
    % 3. CHECK INTERVALS
    % Check to find instances where interval is not 25 Hz (e.g. in AGM data
    % there are breaks, with some observations being a full second apart etc)
    % Where breaks exist need to expand matrix by adding NaN rows to keep
    % intervals regular. 
    % -------------------------------------------------------------------------
    
    % CONFIRM DATEDATE FORMAT:
    % For some reason a handful of files being read as YYYY-dd-MM instead of
    % YYYY-MM-dd.
    % To find, check if the number of unique months is greater than the
    % number of unique days. if so, need to convert to YYYY-MM-dd.
    if length(unique(day(m.DateTime))) < length(unique(month(m.DateTime))) 
       % First convert to string:
       dts=string(m.DateTime);
       % Then convert to datetime specifying format
       dtfix = datetime(dts,'InputFormat','yyyy-dd-MM HH:mm:ss.SSSSSS'); % say what the format is when converting to datetime
       dtfix.Format = 'yyyy-MM-dd HH:mm:ss.SSSSSS'; % write to make format same as other files
       m.DateTime = dtfix;
    end
    
    
    % Quick meta
    daysdur = days(m.DateTime(end)-m.DateTime(1));
    meta_tbl.("Dur-Days")(1,:) = daysdur;
    
    % Sometimes the last row is messed up
    if m(end,:).Ax == 0 & m(end,:).Ay == 0 & m(end,:).Az == 0 | isnan(m(end,:).Ax) & isnan(m(end,:).Ay) & isnan(m(end,:).Az)
        meta_tbl.("Last_Row_Deleted")(1,:) = 1;
        m(end,:)=[];
    end   

    % Identify irregular intervals:
    out = round(milliseconds(diff(m.DateTime)),6); % round to 6 decimal places
    glitch_idx = find(out~=40);
       
     if ~isempty(glitch_idx)
        meta_tbl.("Num_Breaks")(1,:) = length(glitch_idx);
        glitches = out(glitch_idx);
        meta_tbl.("Max_Break_Sec")(1,:) = max(glitches/1000);
        if ~isempty(glitches(glitches<0))
            meta_tbl.Warning(1,:) = {'Mid-data negative timestep'};
            meta_tbl.skip(1,:) = 1;
            return
        else
            % First, check for errors that would have to be dealt with
            % manually
            for j=1:length(glitch_idx)
                row_buffer = 2; % how many rows in either direction are we looking for zeros?
                rows_before = m(glitch_idx(j)-(row_buffer-1):glitch_idx(j),:);
                if glitch_idx(j)+row_buffer>height(m)
                    rows_after = m(glitch_idx(j)+1:height(m), :);
                else
                    rows_after = m(glitch_idx(j)+1:glitch_idx(j)+row_buffer,:);
                end
                nNArows = (glitches/40)-1;

                % Get rid of the issue where sometimes there are several rows of
                % zero near a glitch. Replace the zeros with NaNs
                which_RB = find(rows_before.Ax==0 & rows_before.Ay==0 & rows_before.Az==0);
                which_RA = find(rows_after.Ax==0 & rows_after.Ay==0 & rows_after.Az==0);
                
                % Before the glitch
                if ~isempty(which_RB)
                    row = glitch_idx(j) - (row_buffer - which_RB(end)); % Locate instance closest to glitch
                    while m.Ax(row)==0 && m.Ay(row)==0 && m.Az(row)==0
                        m.Ax(row) = NaN;
                        m.Ay(row) = NaN;
                        m.Az(row) = NaN;
                        row = row-1;
                    end
                    meta_tbl.Zeros_Removed(1,:) = 1;
                end

                % After the glitch
                if ~isempty(which_RA)
                    row = glitch_idx(j) + which_RA(1); % Locate instance closest to glitch
                    while m.Ax(row)==0 && m.Ay(row)==0 && m.Az(row)==0
                        m.Ax(row) = NaN;
                        m.Ay(row) = NaN;
                        m.Az(row) = NaN;
                        row = row+1;
                    end
                    meta_tbl.Zeros_Removed(1,:) = 1;
                end

                if sum(rem(nNArows,1)) ~= 0
                    meta_tbl.Warning(1,:) = {'Breaks are not consistent with 25 Hz sampling'};
                    meta_tbl.skip(1,:) = 1;
                    return
                end
            end
        end
     end
                    
     % If there are no such errors, fill with NAs
     while ~isempty(glitch_idx)
        nNArows = (out(glitch_idx(1))/40)-1;
        if nNArows==-1 % This means that the glitch is that there was no change in datetime between rows. If so, delete the second row.
            m(glitch_idx(1)+1,:) = [];

        else
            row_before = m(glitch_idx(1),:);
            row_after = m(glitch_idx(1)+1,:);
                
            % append chunk with NAs
            mchunk = m(1:glitch_idx(1),:);
            nachunk = array2table(NaN(nNArows,width(mchunk)));
            nachunk.Properties.VariableNames = mchunk.Properties.VariableNames;
    
            % create fake time vec
            t1 = row_before.DateTime + milliseconds(40);
            t2 = row_after.DateTime - milliseconds(40);
            tfill = t1:milliseconds(40):t2;
            ttfill = tfill';
            nachunk.DateTime=ttfill;
    
            % EXPAND MAT
            exp_chunk = [mchunk;nachunk]; % Append NA chunk
            full_exp_mat = [exp_chunk;m(glitch_idx(1)+1:end,:)]; %
            m = full_exp_mat;
        end

        % Find more glitches
        out = milliseconds(diff(m.DateTime));
        glitch_idx = find(out~=40);
     end
    
    %%
    % -------------------------------------------------------------------------
    % 4. BASIC LINEAR INTERPOLATION OF TEMP AND PRESSURE
    % -------------------------------------------------------------------------
  m.Pressure=fillmissing(m.Pressure,'linear');
  m.Temperature=fillmissing(m.Temperature,'linear');

end
