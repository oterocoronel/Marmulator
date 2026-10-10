function estimate = session_duration_estimate(config, repeats, assumed_isi_s)
% Estimated time from first stimulus onset to final stimulus offset.
% ISI is the whole offset-to-onset gap (including fixation/reward waits).
validateattributes(repeats,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(assumed_isi_s,{'numeric'},{'scalar','nonnegative','finite'});
plan = session_plan(config,1,false);
estimate.presentations_per_pass = numel(plan);
estimate.presentations = numel(plan)*repeats;
estimate.min_duration_s = min([plan.duration_s]);
estimate.max_duration_s = max([plan.duration_s]);
estimate.stimulus_duration_s = sum([plan.duration_s])*repeats;
estimate.intervals = max(0,estimate.presentations-1);
estimate.isi_duration_s = estimate.intervals*assumed_isi_s;
estimate.total_duration_s = estimate.stimulus_duration_s+estimate.isi_duration_s;
estimate.plan = plan;
end
