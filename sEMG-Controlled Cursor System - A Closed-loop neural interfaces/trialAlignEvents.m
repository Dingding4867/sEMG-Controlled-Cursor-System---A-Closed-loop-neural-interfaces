function [trial_events, trial_event_times] = trialAlignEvents(events, times, align_event_code, num_events_before, num_events_after)

%[trial_events, trial_event_times] = trialAlignEvents(events, times, align_event_code, num_events_before, num_events_after)   
%(A. Orsborn, created 4-22-10, updated: 12/26/19)
%trial-aligns event-codes and event times
%
%input:
%       events            - event-codes (#events x 1) 
%       times             - times of events (#events x 1). 
%       align_event_code  - event code to align to (scalar) 
%       num_events_before - # event codes before alignment-event included in sorted events
%       num_events_after  - # event codes after alignment_event included in sorted events
%                 Note: if num_events_before and num_events_after are not
%                 available, trial will be considered invalid. 
%output:
%       trial_events     - trial-aligned event matrix (#trials x num_events_before + num_events_after+1)
%       trial_eventTimes - trial-aligned event-times matrix (#trials x num_events_before + num_events_after+1)



%find alignment events
trial_ind = find (events == align_event_code);

%remove incomplete trials (where # events before/after not available)
while any(trial_ind - num_events_before <= 0)
    trial_ind = trial_ind (2:end);
end
while any(trial_ind + num_events_after >= length(events))
    trial_ind = trial_ind(1:end-1);
end

nTr       = length(trial_ind);
tr_ind_S  = trial_ind - num_events_before;
tr_length = num_events_after + num_events_before + 1;

%initialize trial-aligned matrices
trial_events     = zeros (nTr, tr_length); %initialize EVENT DATA
trial_event_times = zeros (nTr, tr_length);

%get trial events
for i = 1:nTr
    trial_events (i,:)      = events(tr_ind_S(i) : tr_ind_S(i)+tr_length-1);
    trial_event_times (i,:) = times (tr_ind_S(i) : tr_ind_S(i)+tr_length-1);
end