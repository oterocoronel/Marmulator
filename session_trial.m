function trial = session_trial(config, item, modality)
% Resolve one trial from current GUI settings. Empty means excluded.
trial = [];
gidx = find(strcmp({config.groups.name}, item.set_name), 1);
iidx = find(strcmp({config.items.id}, item.id), 1);
if isempty(gidx) || isempty(iidx) || ~config.groups(gidx).enabled || ~config.items(iidx).enabled
    return
end
g = config.groups(gidx);
h = config.shared;
assert(ismember(modality, {'AV','A','V'}), 'Marmulator:Modality', 'Choose AV, A, or V.');
assert(isfinite(config.reward_fraction) && config.reward_fraction >= 0 && ...
    config.reward_fraction <= 1, 'Marmulator:RewardFraction', 'Fixation percentage must be 0 to 100.');
modes = strsplit(g.modality, ',');
if ~ismember(modality, modes), return; end
assert(all(isfinite([h.duration_s h.stim_width_deg h.stim_height_deg ...
    h.fixation_width_deg h.fixation_height_deg h.offset_x_deg h.offset_y_deg])) && ...
    h.duration_s > 0 && all([h.stim_width_deg h.stim_height_deg ...
    h.fixation_width_deg h.fixation_height_deg] > 0), ...
    'Marmulator:SessionGeometry', 'Shared duration, stimulus sizes and fixation sizes must be positive.');
assert(all([h.stim_width_deg h.stim_height_deg h.fixation_width_deg h.fixation_height_deg] < 180), ...
    'Marmulator:SessionGeometry', 'Angular sizes must be less than 180 degrees.');
assert(all(abs([h.offset_x_deg h.offset_y_deg])<90), ...
    'Marmulator:SessionGeometry','Offsets must be between -90 and 90 degrees.');
trial = item;
trial.modality = modality;
trial.visual_file = item.visual_file;
trial.audio_file = item.audio_file;
if strcmp(modality, 'A'), trial.visual_file = ''; end
if strcmp(modality, 'V'), trial.audio_file = ''; end
assert(~isempty(trial.visual_file) || strcmp(modality, 'A'), ...
    'Marmulator:MissingVisual', '%s has no visual file.', item.label);
assert(~isempty(trial.audio_file) || strcmp(modality, 'V'), ...
    'Marmulator:MissingAudio', '%s has no sound; use V for silent movies or images.', item.label);
for key = {'visual_file','audio_file'}
    path = trial.(key{1});
    assert(isempty(path) || isfile(path), 'Marmulator:MissingStimulus', 'Missing stimulus: %s', path);
end
trial.requested_duration_s = h.duration_s;
trial.duration_s = h.duration_s;
trial.native_duration_s = item.duration_s;
trial.media_start_s = 0;
trial.duration_policy = g.timing;
switch g.timing
    case 'chair'
        assert(item.duration_s>0,'Marmulator:NativeDuration','Unknown chair clip duration.');
        trial.duration_s = max(h.duration_s,item.duration_s);
        assert(ismember(config.chair_duration_mode,{'full','cap'}), ...
            'Marmulator:ChairDuration','Choose full chair duration or a maximum.');
        if strcmp(config.chair_duration_mode,'cap')
            validateattributes(config.chair_max_duration_s,{'numeric'},{'scalar','positive','finite'});
            trial.duration_s = min(trial.duration_s,config.chair_max_duration_s);
            trial.requested_duration_s = config.chair_max_duration_s;
        end
        trial.duration_policy = ['chair_' config.chair_duration_mode];
    case 'actions'
        validateattributes(config.actions_duration_s,{'numeric'},{'scalar','positive','finite'});
        trial.duration_s = config.actions_duration_s;
        trial.requested_duration_s = config.actions_duration_s;
        trial.media_start_s = max(0,(item.duration_s-trial.duration_s)/2);
    case 'shared'
        % Images, tones, dots and gratings all use the one shared duration.
    otherwise
        error('Marmulator:DurationPolicy','Unknown timing policy: %s',g.timing);
end
trial.stim_size_deg = [h.stim_width_deg h.stim_height_deg];
trial.fixation_size_deg = [h.fixation_width_deg h.fixation_height_deg];
trial.offset_deg = [h.offset_x_deg h.offset_y_deg];
trial.show_fixation_marker = strcmp(modality,'A');
trial.reward_fraction = config.reward_fraction;
trial.background = 'gray';
if isfield(config,'background'), trial.background = config.background; end
assert(ismember(trial.background,{'gray','black','white'}), ...
    'Marmulator:SessionBackground','Choose a gray, black or white background.');
end
