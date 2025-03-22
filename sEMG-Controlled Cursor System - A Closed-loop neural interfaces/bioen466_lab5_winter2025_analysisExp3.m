
%%%%% This script provides a guided outline for analyzing your experimental data collected
%%%%% for Experiment 3 (quantifying task performance in a closed-loop EMG OR Voice interface)
%%%%% Written by A.L. Orsborn, v200216, v210220
%%%%%
%%%%%
%%%%% All lines where you have to fill in information is tagged with a comment including "FILLIN". Use this flag to find everything you need to modify.
%%%%% all figures that need to be included in comprehension questions are
%%%%% flagged with %INCLUDE THIS FIGURE IN COMPREHENSION QUESTIONS

% we will first load a data file and test our pre-processing and calculations on one file. Once that is complete, we can extend our analysis to all data to examine trends.
%% Cell 1: defining constants

%define task constants
CENTER_ON_CODE = 1;
ENTER_CENTER_CODE = 2;
GOCUE_CODE = 3;
ENTER_TARGET_CODE = 5;
SUCCESS_CODE = 6;
FAIL_CODE = 7;

TARG_CODE_OFFSET = 10;
REACH_TIMEOUT_ERROR_CODE = 8;
CENTER_HOLD_ERROR_CODE = 9;
TARGET_HOLD_ERROR_CODE = 10;

%% Cell 2: Load an example file and run task metric calculations

% Define some basic things to make it easy to find your data files.
% We will want to take advantage of systematic naming structure in our data files.
% Your files should have names like [prefix][date][id #].
% Note that our program automatically saves files with date and time in the name.
% We recommend re-naming your files to convert time into a simpler id# e.g. 1, 2, 3...

dataDir = 'C:\Users\harry\Desktop\EE BIOEN 466\Lab5a and 5b'; %FILLIN: the path to where your data is stored

% file_prefix = ''; %FILLIN: the text string that is common among all your data files
% file_type = '';   %FILLIN: the file extension for your data type
% 
% file_date   = ''; %FILLIN: the date string used in your file
% 
% full_file_name = [dataDir file_prefix file_date '_' num2str(file_idnum) file_type];
full_file_name = [dataDir '\' 'Lab 5 a and b_ 04-Mar-2025 16.31.03' '.mat'];

file_names = {'Lab 5 a and b_ 04-Mar-2025 16.31.03', 'Lab 5 b exp3a LAG_100ms_ 04-Mar-2025 16.47.47', ...
    'Lab 5 b exp3a LAG_300ms_ 04-Mar-2025 16.58.14', 'Lab 5 b exp3a LAG_500ms_ 04-Mar-2025 16.53.23',...
    'Lab 5 b exp3b_W and H CHANGED_ 04-Mar-2025 17.13.16'};


%load the task events and event-times from file
load(full_file_name, 'task_events', 'task_event_times');



%trial-sort your events
%align to 'ENTER_CENTER_CODE' to find all possible trial errors (center
%hold, target hold error, reach time-out error)
align_code = ENTER_CENTER_CODE; %FILLIN
num_events_before = 1;
num_events_after = 4;
[trial_events, trial_event_times] = trialAlignEvents(task_events, task_event_times, align_code, num_events_before, num_events_after); %FILLIN (look at function help)


%%%%% compute the % successful trials
trial_success = trial_events(:,6) == 6; %FILLIN: make a vector that = 1 when SUCCESS_CODE happens within a trial (0 otherwise)
trial_fail    = trial_events(:,6) == 7; %FILLIN: make a vector that = 1 when FAIL_CODE happens within a trial (0 otherwise)


%sanity check that a trial is only successful or failed
if  sum(trial_success)+sum(trial_fail) > length(trial_events) %FILLIN: write a one-lie way to check if a trial is flagged as both successful and failed (we want the error message to show if that happens)
    error('Task trial processing is not correct')
end

percent_correct = 100*(sum(trial_success)/(length(trial_events))); %FILLIN: compute percent correct: 100*(# successes)/(total # trials)

%%%%%%



%%%%% compute the reach time (= time enter target - go cue)

num_trials = size(trial_success,1); %number of trials
reach_time = nan(num_trials,1); %initialize reach_time vector [#trials x 1]

for i=1:num_trials %loop through trials
    
    %look for each task event within the trial
    idx_go    = trial_event_times(i,3); %FILLIN: find index when go-cue happens on trial i
    idx_enter = trial_event_times(i,5); %FILLIN: find index when and enters target on trial i
    
    %Both events may not happen in a trial, so only compute reach time if
    %they happen. Otherwise, reach time is not defined
    if  trial_events(i,3)==3 && trial_events(i,5)==5%FILLIN: write a logical statement that is only true when idx_go and idx_enter are found
        
        reach_time(i) = idx_enter-idx_go; %FILLIN: use trial_event_times and the computed indices to compute the reach time for this trial
    end
end

%calculate the mean and standard error of reach time
%recall that reach_time can be a nan. Look at the help for 'nanmean'
mean_reach_time = nanmean(reach_time); %FILLIN: compute mean
ste_reach_time = nanstd(reach_time)/sqrt(num_trials); %FILLIN: compute standard error (std/sqrt(# measurements))


%% cell 3: Now we will load the data for all files, compute metrics, and make plots


% write code to turn the above computation into a loop. You will want to:
% 1) define a list of files to load and associated metadata (e.g. lag)
% 2) Loop over files:
%      load file(i)
%      trial-sort task_events and task_event_times
%      compute percent_correct(i)
%      compute mean_reach_time(i) and ste_reach_time(i)
% 3) Make plots of:
%      percent_correct vs. loop lag %INCLUDE THIS FIGURE IN COMPREHENSION QUESTIONS
%      mean_reach_time vs. loop lag (with error-bars showing the ste) %INCLUDE THIS FIGURE IN COMPREHENSION QUESTIONS
%      percent_correct vs. control variable (position vs. velocity) %INCLUDE THIS FIGURE IN COMPREHENSION QUESTIONS
%      mean_reach_time vs. control variable (with error-bars showing the ste) %INCLUDE THIS FIGURE IN COMPREHENSION QUESTIONS
percent_correct_loop = zeros(1,length(file_names));
mean_reach_time_loop = zeros(1,length(file_names));
ste_reach_time_loop = zeros(1,length(file_names));
for iF= (1:length(file_names))
    %load the task events and event-times from file
    load(file_names{iF}, 'task_events', 'task_event_times');
    align_code = ENTER_CENTER_CODE; %FILLIN
    num_events_before = 1;
    num_events_after = 4;
    [trial_events, trial_event_times] = trialAlignEvents(task_events, task_event_times, align_code, num_events_before, num_events_after); %FILLIN (look at function help)
    
    
    %%%%% compute the % successful trials
    trial_success = trial_events(:,6) == 6; %FILLIN: make a vector that = 1 when SUCCESS_CODE happens within a trial (0 otherwise)
    trial_fail    = trial_events(:,6) == 7; %FILLIN: make a vector that = 1 when FAIL_CODE happens within a trial (0 otherwise)
    
    
    %sanity check that a trial is only successful or failed
    if  sum(trial_success)+sum(trial_fail) > length(trial_events) %FILLIN: write a one-lie way to check if a trial is flagged as both successful and failed (we want the error message to show if that happens)
        error('Task trial processing is not correct')
    end
    
    percent_correct_loop(iF) = 100*(sum(trial_success)/(length(trial_events))); %FILLIN: compute percent correct: 100*(# successes)/(total # trials)
    num_trials = size(trial_success,1); %number of trials
    reach_time = nan(num_trials,1); %initialize reach_time vector [#trials x 1]
    
    for i=1:num_trials %loop through trials
        
        %look for each task event within the trial
        idx_go    = trial_event_times(i,3); %FILLIN: find index when go-cue happens on trial i
        idx_enter = trial_event_times(i,5); %FILLIN: find index when and enters target on trial i
        
        %Both events may not happen in a trial, so only compute reach time if
        %they happen. Otherwise, reach time is not defined
        if  trial_events(i,3)==3 && trial_events(i,5)==5%FILLIN: write a logical statement that is only true when idx_go and idx_enter are found
            
            reach_time(i) = idx_enter-idx_go; %FILLIN: use trial_event_times and the computed indices to compute the reach time for this trial
        end
    end
    
    %calculate the mean and standard error of reach time
    %recall that reach_time can be a nan. Look at the help for 'nanmean'
    mean_reach_time_loop(iF) = nanmean(reach_time); %FILLIN: compute mean
    ste_reach_time_loop(iF) = nanstd(reach_time)/sqrt(num_trials); %FILLIN: compute standard error (std/sqrt(# measurements))
    
end

%      percent_correct vs. loop lag %INCLUDE THIS FIGURE IN COMPREHENSION QUESTIONS
figure;
plot([0,0.1,0.3,0.5], percent_correct_loop(1:4)) %plot cartesian position trajectory
xlabel('cursor lag in sec');
ylabel('percent_correct');
title('percent correct vs. cursor lag');
xlim([-0.1 0.6])
grid on
%      mean_reach_time vs. loop lag (with error-bars showing the ste) %INCLUDE THIS FIGURE IN COMPREHENSION QUESTIONS
figure
errorbar([0,0.1,0.3,0.5], mean_reach_time_loop(1:4), ste_reach_time_loop(1:4)) %plot cartesian position trajectory
xlabel('cursor lag in sec');
ylabel('percent_correct');
title('mean reach time vs. cursor lag error bar');
xlim([-0.1 0.6])
grid on  
    
%      percent_correct vs. control variable (position vs. velocity) %INCLUDE THIS FIGURE IN COMPREHENSION QUESTIONS
figure
plot([0,1], percent_correct_loop([1 5])) %plot cartesian position trajectory
xlabel('control variable: 0 is velosity, 1 is position');
ylabel('percent_correct');
title('percent_correct vs.  control variable');
xlim([-0.2 1.2])
grid on 
    
%      mean_reach_time vs. control variable (with error-bars showing the ste)
figure
errorbar([0,1], mean_reach_time_loop([1 5]),ste_reach_time_loop([1 5])) %plot cartesian position trajectory
xlabel('control variable: 0 is velosity, 1 is position');
ylabel('mean_reach_time in sec');
title('mean_reach_time vs.  control variable error bar');
xlim([-0.2 1.2])
grid on

%%
clc; clear; close all;


omega = linspace(-10, 10, 1000);


X_real = 1/2 * ( (1 - exp(-1j*2*pi*(omega - 1))) ./ (1j*(omega - 1)) ...
                + (1 - exp(-1j*2*pi*(omega + 1))) ./ (1j*(omega + 1)) );


X_re = real(X_real);
X_im = imag(X_real);


figure;
subplot(2,1,1);
plot(omega, X_re, 'b', 'LineWidth', 1.5);
xlabel('\omega');
ylabel('Re\{X(\omega)\}');
title('REAL: Re\{X(\omega)\}');
grid on;


subplot(2,1,2);
plot(omega, X_im, 'r', 'LineWidth', 1.5);
xlabel('\omega');
ylabel('Im\{X(\omega)\}');
title('Imaginary: Im\{X(\omega)\}');
grid on;
