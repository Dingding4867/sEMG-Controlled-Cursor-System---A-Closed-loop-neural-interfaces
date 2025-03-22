%%%%% This script provides an outline for implementing real-time EMG 1-D
%%%%% cursor control task, lab5 experiments 2 and 3a/3b.

%we will use EMG activity to control the movements of a cursor.
%the exact mapping will vary a bit between experiments. See lab manual for
%details.

%%%%% Written by A.L. Orsborn, v200216, v210220
%%%%%
%%%%%
%%%%% All lines where you have to fill in information is tagged with a comment including "FILLIN". Use this flag to find everything you need to modify.
%%%%% all figures that need to be included in comprehension questions are
%%%%% flagged with %INCLUDE THIS FIGURE IN COMPREHENSION QUESTIONS

%(note: there are NO figures required from this script)
%% cell 1: defining loop constants, setting up workspace

%loop time-interval (i.e. bin-size)
DELTA_T = 0.05;

MAX_RUN_LENGTH = floor(1*60*1000/DELTA_T); %time to run loop in samples
PLOT_LENGTH    = floor(1*20/DELTA_T); %time duration to plot in samples

NUM_CHANNELS = 2; %# channels streaming

BASELINE_ESTIMATE_LENGTH = floor(1*10/DELTA_T); %length to wait to estimate emg scaling in samples
ch_offsets = zeros(NUM_CHANNELS,1); %dc offset in channels, initialize to 0 for each channel
ch_scale   = ones(NUM_CHANNELS,1); %linear scaling of channels, initialize to 1 for each channel
EMG_SCALE  = 50; %scale range of EMG (once normalized)

%base matlab directory on your computer
%(where you installed streaming utility software)
MATLAB_DIR = 'C:\Users\harry\Desktop\EE BIOEN 466\Streaming Tools for lab 5\'; %FILLIN

addpath(genpath(MATLAB_DIR)) %add those tools to the path

LOOP_TIME_FF = 0.001; %'fudge factor' for loop time


%tag for saving files. May want to change across experiments. 
FILE_SAVE_STRING = 'EMG_1D_centerOut_vel_';
%% cell 2: defining EMG -> cursor 'decoder'

NUM_DIMS     = 1; %# dimensions we'll be controlling
NUM_STATES   = NUM_DIMS*2 + 1; %# states in our KF.

%define the state-transition matrix (see lab manual)
%for experiment 2, define position as integral of velocity
A = [1, DELTA_T, 0; % this row control position
     0, 0.9,     0; % velosity biger than 0
     0, 0,       1];%FILLIN

%define state covariance matrix (see lab manual)
%for experiment 2, set velocity covariance only (perfect vel -> pos
%transition)
W = [0,   0,   0;
     0, 0.9,   0;
     0,   0,   0]; %FILLIN
%  diaganou - top left to bottom right
%define observation matrix (see lab manual)
H = [0, 1, 0;   % EMG1 contributes to +X velocity
     0, -1, 0]; % EMG2 contributes to -X velocity%FILLIN
% to neral data, 
%define observation covariance (see lab manual)
Q = [0.2, 0;
     0, 0.2];%FILLIN

%% cell 3: defining task-related constants
% You do not need to modify anything in this.
% please do not touch.

%%%%% target positions/sizes, screen size
CENTER_POS   = [0; 0]; %position of center target
REACH_DIST   = 6;      %distance of peripheral targets
TARG_ANGLES  = [0 180]; %orientation of targets around a circle
TARG_POS     = REACH_DIST.*[cosd(TARG_ANGLES); sind(TARG_ANGLES)] + CENTER_POS; %x-y positions of targets

%get 'master list' of all targets (including the center target as 1st one)
TARG_POS = [CENTER_POS TARG_POS];
NUM_TARG = size(TARG_POS,2);
TARG_RAD = 0.7*ones(1,NUM_TARG);

%get circles for plotting targets
TARG_CIRCLES = makeTargetCircles(TARG_POS, TARG_RAD);
SCREEN_SIZE = 10;
TASK_DISPLAY_LIMS = [-10 10 -10 10];
%%%%%%%%%%

%%%%% task timing
HOLD_TIME        = .5; %duration of center/target holds in seconds
REACH_TIME_LIMIT = 5; %max time to hit target in seconds
ITI              = 0.5; %inter-trial interval in seconds
%%%%%

%%%%%% # trials and target-list for each trial
NUM_TRIALS         = 20;

REACH_TARGET_LIST = randi(NUM_TARG-1,NUM_TRIALS,1); %randomly pick reach target for each trial

%make sure trial #s match between targets--only works for 2 targets
checkTargets = 1;
if checkTargets
    tr_1_cnt = sum(REACH_TARGET_LIST ==1);
    target_cnt = floor(NUM_TRIALS/2);
    mismatch = floor(NUM_TRIALS/2) - tr_1_cnt;
    if mismatch>0 %more tr2 than tr1
        replace_id = 2;
        target_id = 1;
    else
        replace_id = 1;
        target_id = 2;
    end
    while tr_1_cnt ~= target_cnt
        %grab random replace_id to swap
        replace_list = find(REACH_TARGET_LIST==replace_id);
        tmp = randperm(length(replace_list));
        idx = replace_list(tmp(1));
        
        %swap replace_id --> target_id
        REACH_TARGET_LIST(idx) = target_id;
        tr_1_cnt = sum(REACH_TARGET_LIST==1);
    end
end
trial_cnt = 1; %counter for total # trials completed.

%%%%%%


%%%%%% task states and codes.
STATE_LIST = {'WAIT_INIT', 'HOLD_CENTER', 'REACH', 'HOLD_TARGET', 'SUCCESS', 'FAIL'};
STATE_CODES = [1             2              3          5            6          7];
TARG_CODE_OFFSET = 10;
REACH_TIMEOUT_ERROR_CODE = 8;
CENTER_HOLD_ERROR_CODE = 9;
TARGET_HOLD_ERROR_CODE = 10;

%initialize task state
task_state       = cell(MAX_RUN_LENGTH,1);
task_target      = nan(MAX_RUN_LENGTH,1);
task_state{BASELINE_ESTIMATE_LENGTH} = 'WAIT_INIT';
task_events = [];
task_event_times = [];
current_reach_target = nan;

%flags for display
draw_center = 0;
draw_target = 0;
draw_cursor = 1;

%% cell 4: Real-time loop


%%%%%%%%%%%%% initialize variables
%emg inputs and plotting
emg_inputs   = zeros(NUM_CHANNELS, MAX_RUN_LENGTH); %FILLIN. streamed emg inputs, [# channels x time you will run your loop]
elapsed_time = nan(1, MAX_RUN_LENGTH); %FILLIN. time it takes loop to execute [time you will run your loop x 1]
emg_plot     = zeros(NUM_CHANNELS, PLOT_LENGTH); %FILLIN: running buffer for data to plot, [# channels x time points you will plot]

% variables for the kalman filter
X_hat    = zeros(NUM_STATES,MAX_RUN_LENGTH);  %FILLIN. predicted state [#states x time you will run loop]
X_hatAP  = zeros(NUM_STATES,MAX_RUN_LENGTH);  %FILLIN. a-priori estimates of state [#states x time you will run loop]

P_AP     = zeros(NUM_STATES, NUM_STATES, MAX_RUN_LENGTH);  %FILLIN. apropri estimates of covariance. [size of covariance matrix x time your loop will run] (3-dimensional)
P        = zeros(NUM_STATES, NUM_STATES, MAX_RUN_LENGTH);  %FILLIN. a-posterior estimate of covariance. [size of covariance matrix x time your loop will run] (3-dimensional)
K        = zeros(NUM_STATES, NUM_CHANNELS, MAX_RUN_LENGTH);  %FILLIN. kalman gain [size of Kalman gain x time your loop will run] (3-dimensional)

%Set X_hat @ first time we will predict to include 'offset' state
X_hat(:,BASELINE_ESTIMATE_LENGTH) = [zeros(NUM_STATES-1,1); 1];

%cursor position
if NUM_DIMS==1
    cursor_pos   = zeros(NUM_DIMS+1, MAX_RUN_LENGTH);
else
    cursor_pos   = zeros(NUM_DIMS, MAX_RUN_LENGTH);
end
%%%%%%%%%%%


%%%% initialize your data socket via lab-streaming-layer
%this is provided in full. nothing to do here, but look at what this does.
disp('Initializing data socket...')

lib = lsl_loadlib();
streams = lsl_resolve_all(lib);
info = streams{1};
inlet = lsl_inlet(info);
inlet.set_postprocessing(15);
inlet.pull_chunk() % The first call to pull_chunk is always empty.
% Pull whatever's available to clear the buffer
for i = 1:10
    [data_chunk,stamps] = inlet.pull_chunk();
end
disp('...done!')
%%%%%%% done initializing socket.



figure %create a figure to plot our streamed data on
ax_task = subplot(3,2,1:4); %axis for plotting our task
ax_emg = subplot(3,2,5:6);  %axis for plotting emg

time_plot = linspace(0, PLOT_LENGTH*DELTA_T, PLOT_LENGTH); %time-axis for EMG plot

%Create a while loop that runs for specified max time OR until you complete
%the # of trials we want to run (NUM_TRIALS). 
%(trials completed are tracked with 'trial_cnt' variable)
i=1;
while i <= MAX_RUN_LENGTH && trial_cnt <= NUM_TRIALS  %FILLIN
    
    %start a clock to keep track of time at this moment in the loop.
    %set this variable to 't0'
    %hint: look at matlab help for 'clock'
    %FILLIN
    t_0 = clock;
    %pull latest data from your buffer
    %store EMG data as 'data_chunk' and time-stamps as 'stamps'
    %hint: look at how we did this above when we cleared the buffer.
    %data_chunk should be [NUM_CHANNELS #time-samples pulled in]
    %stamps should be [1 #time-samples pulled in]
    %FILLIN
    [data_chunk,stamps] = inlet.pull_chunk();
    %update 'emg_inputs' for this loop iteration
    %we will visualize the mean(|EMG|) for each channel, as before
    %But now we will scale the input: ch_scale*( X - ch_offset)
    emg_inputs(:,i) = ch_scale .* (mean(abs(data_chunk), 2) - ch_offsets); %FILLIN
    
    %if we have waited long enough (BASELINE_ESTIMATE_LENGTH),
    %calculate the ch_offsets and ch_scale from the data
    %note: we want to do this ONCE only.
    if i == BASELINE_ESTIMATE_LENGTH%%FILLIN (some equality)
        ch_offsets =  min(emg_inputs(:, 1:BASELINE_ESTIMATE_LENGTH), [], 2); %FILLIN (same as we did in experiment 1b)
        ch_scale   = EMG_SCALE *1./(max(emg_inputs(:, 1:BASELINE_ESTIMATE_LENGTH),[], 2)-ch_offsets); %FILLIN. (same as we did in experiment 1b)
        
        disp('Re-scaling EMG data complete')
    end
    
    %now update emg_plot and time_plot to be a rolling buffer of data for our plot
    %1. time-shift the data by 1 (move all elements LEFT by 1)
    %    hint: look at matlab help for 'circshift'
    emg_plot  = circshift(emg_plot, -1, 2); %FILLIN
    
    %2. put the new data at the end of emg_plot and time_plot
    emg_plot(:,end) = emg_inputs(:,i); %FILLIN
    
    
    %once we've properly conditioned our emg inputs (i.e. waited past
    %baseline-estimation time), start running our KF
    if i>BASELINE_ESTIMATE_LENGTH

        %%%%%%%%% run KF prediction
        %Here, you can paste-in your code from 'runKalmanForward' in lab 4
        %implementation food-for-thought: why do you think we paste-in the
        %code into this script rather than  implementing all those
        %calculations in a function we repeatedly call?
        
        %FILLIN KF CODE HERE. 
        %a priori estimate of x ( X(k|k-1) = A*X(k-1) )
        X_hatAP(:,i) = A * X_hat(:,i-1); %FILLIN
        
        %a priori estimate of x covariance ( P(k) = A*P(k-1)*A' + W )
        P_AP(:,:,i) = A * P(:,:,i-1) * A' + W; %FILLIN
        
        %compute Kalman gain ( K = P_ap*H * inv(H*P_ap*H' + Q) )
        K(:,:,i) = P_AP(:,:,i) * H' * pinv(H * P_AP(:,:,i) * H' + Q); %FILLIN
        
        %compute a posteriori estimate of x (X(k) = X(k|k-1) + K*(Y - H*X(k|k-1))
        Y = emg_inputs;
        X_hat(:,i) =  X_hatAP(:,i) + K(:,:,i) * (Y(:,i) - H * X_hatAP(:,i)); %FILLIN
        
        %update covariance (a posteriori estimate, P = (I - K*H)*P_ap )
        N_states = size(A,1);
        P(:,:,i) = (eye(N_states) - K(:,:,i) * H) * P_AP(:,:,i); %FILLIN
        %%%%%%%%%
        
        %Sometimes our predictions get a bit crazy. To avoid the cursor
        %running off the screen, we will cap X_hat positions to lie on the
        %screen
        X_hat(1:NUM_DIMS,i) = sign(X_hat(1:NUM_DIMS,i)).*min(abs(X_hat(1:NUM_DIMS,i)), repmat(SCREEN_SIZE, NUM_DIMS,1));
        
        
        %%%% update cursor position
        cursor_pos(1:NUM_DIMS,i) = X_hat(1:NUM_DIMS,i);
        if NUM_DIMS == 1
            cursor_pos(2,i) = 0;
        end
        if isnan(cursor_pos(1,i))
            dbstop 
        end
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% task-related control (state-transitions based on where
        %%%%%% cursor is, task requirements etc.)
        % YOU DO NOT NEED TO EDIT ANY OF THIS. DO NOT TOUCH.
        
        %figure out if cursor is in any of the targets (center = targ1)
        inTarg = sqrt( sum((TARG_POS - repmat(cursor_pos(:,i),1,NUM_TARG)).^2,1)) < TARG_RAD;
        
        switch task_state{i-1}
            
            case 'WAIT_INIT'
                %waiting at the center
                draw_center = 1; %center on, cursor on, target off
                draw_cursor = 1;
                draw_target = 0;
                
                task_target(i) = 1; %keep track of target
                
                %check for state transition conditions
                if inTarg(1)
                    task_state{i} = 'HOLD_CENTER';
                    wait_center_clock = 0;
                    disp('WAIT_INIT --> HOLD_CENTER')
                    %log event
                    task_events(end+1)      = STATE_CODES(ismember(STATE_LIST, task_state{i}));
                    task_event_times(end+1) = i*DELTA_T;
                else
                    task_state{i} = task_state{i-1};
                end
                
            case 'HOLD_CENTER'
                %holding at the center
                draw_center = 1;
                draw_cursor = 1;
                draw_target = 0;
                
                task_target(i) = 1; %keep track of target
                
                %check for state transition conditions
                if inTarg(1) && wait_center_clock >= HOLD_TIME %in center long enough
                    task_state{i} = 'REACH';
                    wait_center_clock = 0; %reset clock for center hold
                    wait_reach_clock  = 0; %start a reach clock
                    
                    disp('HOLD_CENTER --> REACH')
                    
                    %log event
                    task_events(end+1)      = STATE_CODES(ismember(STATE_LIST, task_state{i}));
                    task_event_times(end+1) = i*DELTA_T;
                    
                    %draw target from the list
                    current_reach_target = REACH_TARGET_LIST(trial_cnt); %randomly select which target
                    
                    task_events(end+1)      = current_reach_target + TARG_CODE_OFFSET;
                    task_event_times(end+1) = i*DELTA_T;
                    
                elseif ~inTarg(1) && wait_center_clock < HOLD_TIME %left center early
                    task_state{i} = 'FAIL';
                    wait_center_clock = 0; %reset clock
                    wait_iti_clock    = 0; %start clock for inter-trial interval
                    
                    disp('HOLD_CENTER --> FAIL')
                    
                    %log event
                    task_events(end+1)      = STATE_CODES(ismember(STATE_LIST, task_state{i}));
                    task_event_times(end+1) = i*DELTA_T;
                    task_events(end+1)      = CENTER_HOLD_ERROR_CODE;
                    task_event_times(end+1) = i*DELTA_T;
                    
                else
                    %increment counter
                    wait_center_clock = wait_center_clock + DELTA_T;
                    
                    task_state{i} = task_state{i-1};
                end
                
            case 'REACH'
                %holding at the center
                draw_center = 0;
                draw_cursor = 1;
                draw_target = 1;
                
                task_target(i) = current_reach_target+1; %keep track of target
                
                %check for state transition conditions
                if inTarg(task_target(i)) %in reach target
                    task_state{i} = 'HOLD_TARGET';
                    wait_reach_clock = 0; %reset clock for reach
                    wait_target_clock = 0; %start clock for target hold
                    
                    disp('REACH --> HOLD_TARGET')
                    
                    %log event
                    task_events(end+1)      = STATE_CODES(ismember(STATE_LIST, task_state{i}));
                    task_event_times(end+1) = i*DELTA_T;
                elseif wait_reach_clock > REACH_TIME_LIMIT
                    task_state{i} = 'FAIL';
                    wait_reach_clock = 0;
                    wait_iti_clock    = 0;
                    
                    disp('REACH --> FAIL')
                    
                    %log event
                    task_events(end+1)      = STATE_CODES(ismember(STATE_LIST, task_state{i}));
                    task_event_times(end+1) = i*DELTA_T;
                    task_events(end+1)      = REACH_TIMEOUT_ERROR_CODE;
                    task_event_times(end+1) = i*DELTA_T;
                else
                    %increment counter
                    wait_reach_clock = wait_reach_clock + DELTA_T;
                    
                    task_state{i} = task_state{i-1};
                end
            case 'HOLD_TARGET'
                %holding at the center
                draw_center = 0;
                draw_cursor = 1;
                draw_target = 1;
                
                task_target(i) = current_reach_target+1; %keep track of target
                
                %check for state transition conditions
                if inTarg(task_target(i)) && wait_target_clock >= HOLD_TIME %in target long enough
                    task_state{i} = 'SUCCESS';
                    wait_target_clock = 0; %reset clock for center hold
                    wait_iti_clock    = 0;
                    
                    disp('HOLD_TARGET --> SUCCESS')
                    
                    %log event
                    task_events(end+1)      = STATE_CODES(ismember(STATE_LIST, task_state{i}));
                    task_event_times(end+1) = i*DELTA_T;
                    
                    
                elseif ~inTarg(task_target(i)) && wait_target_clock < HOLD_TIME %left target early
                    task_state{i} = 'FAIL';
                    wait_target_clock = 0; %reset clock
                    wait_iti_clock   = 0; %initialize counter for delay between trials
                    
                    disp('HOLD_TARGET --> FAIL')
                    
                    %log event
                    task_events(end+1)      = STATE_CODES(ismember(STATE_LIST, task_state{i}));
                    task_event_times(end+1) = i*DELTA_T;
                    task_events(end+1)      = TARGET_HOLD_ERROR_CODE;
                    task_event_times(end+1) = i*DELTA_T;
                    
                else
                    %increment counter
                    wait_target_clock = wait_target_clock + DELTA_T;
                    
                    task_state{i} = task_state{i-1};
                end
                
            case 'FAIL'
                %failure, blank everything
                draw_center = 0;
                draw_cursor = 1;
                draw_target = 0;
                
                
                %check for state transition conditions
                if wait_iti_clock >= ITI %waited between trials long enough
                    task_state{i} = 'WAIT_INIT';
                    wait_iti_clock    = 0; %reset clock for iti
                    
                    disp('FAIL --> WAIT_INIT')
                    
                    %update trial counter--only if error was not an
                    %initialization error
                    if task_events(end)~=CENTER_HOLD_ERROR_CODE
                        trial_cnt = trial_cnt + 1;
                        disp(['Trial ' num2str(trial_cnt)])
                    end
                    
                    %log event
                    task_events(end+1)      = STATE_CODES(ismember(STATE_LIST, task_state{i}));
                    task_event_times(end+1) = i*DELTA_T;
                else
                    %iterate counter
                    wait_iti_clock = wait_iti_clock + DELTA_T;
                    
                    task_state{i} = task_state{i-1};
                    
                end
                
            case 'SUCCESS'
                %success, blank targets
                draw_center = 0;
                draw_cursor = 1;
                draw_target = 1;
                
                task_target(i) = current_reach_target+1; %keep track of target
                
                %check for state transition conditions
                if wait_iti_clock >= ITI %waited between trials long enough
                    task_state{i} = 'WAIT_INIT';
                    wait_iti_clock    = 0; %reset clock for iti
                    
                    disp('SUCCESS --> WAIT_INIT')
                    
                    %update trial counter
                    trial_cnt = trial_cnt + 1;
                    disp(['Trial ' num2str(trial_cnt)])
                    
                    %log event
                    task_events(end+1)      = STATE_CODES(ismember(STATE_LIST, task_state{i}));
                    task_event_times(end+1) = i*DELTA_T;
                else
                    %iterate counter
                    wait_iti_clock = wait_iti_clock + DELTA_T;
                    
                    task_state{i} = task_state{i-1};
                end
        end %end task-state switch
        %end task-control code.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
    end %end KF and task conditional-execution
    
    
    %%%%%%%%%% plot our task and data
    %1. plot targets (toggled based on task state)
    %you do not need to modify this step of plotting (move to step 2)
    set(gcf, 'currentAxes', ax_task)
    hold off
    %mask targets based on flags to plot or not.
    plot_mask = zeros(NUM_TARG,1);
    plot_mask(1) = draw_center;
    if task_target(i)>1
        plot_mask(task_target(i)) = draw_target;
    end
    for j=1:NUM_TARG
        if plot_mask(j) %only plot if flagged.
            %toggle color based on conditions.
            if inTarg(j) && ~strcmp(task_state{i}, 'SUCCESS')
                plot(TARG_CIRCLES(1,:,j), TARG_CIRCLES(2,:,j), 'b', 'linewidth', 3)
            elseif strcmp(task_state{i}, 'SUCCESS')
                plot(TARG_CIRCLES(1,:,j), TARG_CIRCLES(2,:,j), 'g', 'linewidth', 3)
            else
                plot(TARG_CIRCLES(1,:,j), TARG_CIRCLES(2,:,j), 'r', 'linewidth', 3)
            end
            hold on
        end
    end
    
    %2. draw the cursor at the computed position.
    if draw_cursor
        plot(cursor_pos(1, i), cursor_pos(2, i), 'k.', 'markersize', 20) %FILLIN
        % cursor_pos(1, i)：光标的 x 坐标。
        % cursor_pos(2, i)：光标的 y 坐标。
        % 'k.'：黑色圆点表示光标。
        % 'markersize', 20：设置光标的大小。
    end
    axis square
    hold off
    axis(TASK_DISPLAY_LIMS)
    
    
    %3. plot time_plot vs. emg_plot on the axis we made for EMG
    %   hint: look at help for 'plot' to see how to pass in the axis handle 'ax_emg')
    plot(ax_emg, time_plot, emg_plot, 'linewidth', 2.5) %FILLIN []s with appropriate arguments to pass in
    
    
    drawnow %this command forces matlab to push updates to the figure NOW (rather than after our code finishes running)
    
    %use 'pause' to make our loop execute every DELTA_T seconds
    %We must wait (DELTA_T - LOOP_TIME_FF) - (time our loop took to execute)
    % hint: look at the help for 'etime'
    t_1 = clock;
    Time_diff = etime(t_1,t_0);
    pause((DELTA_T-LOOP_TIME_FF) - Time_diff); %FILLIN
    
    %store execution time of our loop in ms (NOT SECONDS)
    elapsed_time(i) = etime(clock, t_0)*1000; %FILLIN
    
    
    i=i+1; %iterate counter

end



%once done, clean up all the variables (remove any extra nans/zeros) and save data
X_hat = X_hat(:,1:i-1);
X_hatAP = X_hatAP(:,1:i-1);
P_AP = P_AP(:,:,i-1);
P = P(:,:,i-1);
K = K(:,:,i-1);
X_hat = X_hat(:,1:i-1);

elapsed_time = elapsed_time(1:i-1);
emg_inputs = emg_inputs(:,1:i-1);
cursor_pos = cursor_pos(:,i-1);
task_state = task_state(1:i-1);
task_target = task_target(1:i-1);

%create a file name of the form '{FILE_SAVE_STRING}_DD-Mon-YYY HH.MM.SS'
%hint1: look at the help for 'datetime' and 'datestr'
%hint2: windows doesn't like to save files with characters like ':'. You
%can replace them with '.' in a single line (with logical indexing!)
file_name = ['Lab 5 a and b', '_ ', datestr(now),'.mat']; %FILLIN the ()
file_name(file_name == ':') = '.'; %FILLIN [] to replace problematic characters 

%save the full work-space into your file. 
save(file_name)
