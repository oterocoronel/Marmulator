function varargout = flexible_2p(action, varargin)
% Flexible 2p stimulus settings and calculations. No hardware is opened here.
% Keep the task-specific functions together; engine.m owns trial progression.
switch action
    case 'catalog', [varargout{1:nargout}] = load_stimulus_catalog(varargin{:});
    case 'discover', [varargout{1:nargout}] = discover_session_stimuli(varargin{:});
    case 'plan', [varargout{1:nargout}] = session_plan(varargin{:});
    case 'trial', [varargout{1:nargout}] = session_trial(varargin{:});
    case 'estimate', [varargout{1:nargout}] = session_duration_estimate(varargin{:});
    case 'audio', [varargout{1:nargout}] = session_audio_samples(varargin{:});
    case 'fixation', [varargout{1:nargout}] = session_fixation_fraction(varargin{:});
    case 'foreground', [varargout{1:nargout}] = session_foreground_rect(varargin{:});
    case 'movie_geometry', [varargout{1:nargout}] = session_movie_geometry(varargin{:});
    case 'defaults', [varargout{1:nargout}] = defaults(varargin{:});
    case 'scan_folders', [varargout{1:nargout}] = scan_folders(varargin{:});
    case 'surround', [varargout{1:nargout}] = surround(varargin{:});
    otherwise, error('Marmulator:SessionAction','Unknown flexible 2p action: %s',action);
end
end


function config = load_stimulus_catalog(root)
% Load folder definitions and discover their current contents.
assert(isfolder(root),'Marmulator:StimulusRoot','Stimulus folder does not exist: %s',root);
[ok,attributes] = fileattrib(root);
assert(ok,'Marmulator:StimulusRoot','Cannot read stimulus folder: %s',root);
root = attributes.Name;
catalog = fullfile(root, 'stimulus_catalog.json');
if isfile(catalog)
    config = jsondecode(fileread(catalog));
    assert(config.version == 2, 'Marmulator:CatalogVersion', ...
        'Use a version 2 stimulus catalog or choose a folder without a catalog.');
else
    config = struct('groups',scan_folders(root));
end
config = defaults(config);
config.root = root;
config.enabled = true;
config = discover_session_stimuli(config);
end

function config = discover_session_stimuli(config)
% Folder contents define the session. The inventory only caches movie headers.
config = defaults(config);
headers = containers.Map('KeyType','char','ValueType','any');
inventory_time = -Inf;
inventory = fullfile(config.root,'stimulus_inventory.json');
if isfile(inventory)
    inventory_info = dir(inventory); inventory_time = inventory_info.datenum;
    data = jsondecode(fileread(inventory));
    for k = 1:numel(data.media), headers(data.media(k).file) = data.media(k); end
end
items = struct('id',{},'label',{},'set_name',{},'kind',{},'visual_file',{}, ...
    'audio_file',{},'duration_s',{},'has_alpha',{},'tone_hz',{},'enabled',{});
for g = config.groups(:)'
    folder = fullfile(config.root,g.folder);
    files = dir(fullfile(folder,g.pattern));
    files = files(~[files.isdir]);
    [~,order] = sort({files.name}); files = files(order);
    for file = files(:)'
        path = fullfile(folder,file.name);
        relative = fullfile(g.folder,file.name);
        [~,label] = fileparts(file.name);
        item = struct('id',relative,'label',label,'set_name',g.name,'kind',g.kind, ...
            'visual_file',path,'audio_file','','duration_s',0,'has_alpha',g.has_alpha, ...
            'tone_hz',-1,'enabled',true);
        if strcmp(g.kind,'audio')
            item.visual_file = ''; item.audio_file = path;
            info = audioinfo(path); item.duration_s = info.Duration;
            if strcmp(label,'white_noise')
                item.tone_hz = 0;
            elseif startsWith(label,'tone_')
                hz = sscanf(label,'tone_%fHz');
                if ~isempty(hz) && hz>0
                    % Recover the exact half-octave value from its rounded filename.
                    k = round(2*log2(hz/440)); exact = 440*2^(k/2);
                    if abs(hz-exact)<.001, hz=exact; end
                    item.tone_hz = hz;
                end
            end
        elseif strcmp(g.kind,'movie')
            if isKey(headers,relative)
                header = headers(relative);
                if (~isfield(header,'file_bytes') || header.file_bytes==file.bytes) && file.datenum<=inventory_time
                    item.duration_s = header.visual_duration_s;
                    item.has_alpha = header.alpha;
                end
            end
            if item.duration_s<=0
                reader = VideoReader(path);
                item.duration_s = reader.Duration;
            end
            if strcmp(g.timing,'chair')
                identity = regexprep(label,'_(rgba|masked)$','');
                audio = fullfile(folder,[identity '_denoised.wav']);
                if ~isfile(audio)
                    source = fullfile(config.root,'videos_AV','chair_exported_4set', ...
                        'wav_denoised',[identity '_denoised.wav']);
                    assert(isfile(source),'Marmulator:MissingAudio', ...
                        'No matching denoised WAV for %s.',path);
                    audio = source; % Read the existing sidecar; never modify stimulus folders.
                end
                item.audio_file = audio;
            end
        end
        items(end+1) = item; %#ok<AGROW>
    end
end
config.items = items;
end

function trials = session_plan(config, repeats, randomize)
% A randomized complete pass through every selected item/condition per repeat.
% Ordered plans support estimates without changing the experiment's RNG state.
if nargin<3, randomize=true; end
config = defaults(config);
validateattributes(repeats, {'numeric'}, {'scalar','integer','positive','finite'});
trials = struct([]);
for k = 1:numel(config.items)
    item = config.items(k);
    gidx = find(strcmp({config.groups.name}, item.set_name), 1);
    if isempty(gidx) || ~config.groups(gidx).enabled || ~item.enabled, continue; end
    modes = strtrim(strsplit(config.groups(gidx).modality, ','));
    assert(numel(unique(modes))==numel(modes),'Marmulator:DuplicateCondition', ...
        'Each condition can occur only once per set.');
    for m = 1:numel(modes)
        trial = session_trial(config, item, modes{m});
        if ~isempty(trial), trials = [trials trial]; end %#ok<AGROW>
    end
end
assert(~isempty(trials), 'Marmulator:EmptySession', 'Select at least one nonempty stimulus folder.');
base = trials;
trials = struct([]);
for k = 1:repeats
    order = 1:numel(base);
    if randomize, order = randperm(numel(base)); end
    trials = [trials base(order)]; %#ok<AGROW>
end
end

function trial = session_trial(config, item, modality)
% Resolve one trial from current GUI settings. Empty means excluded.
config = defaults(config);
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
modes = strtrim(strsplit(g.modality, ','));
if ~ismember(modality, modes), return; end
assert(all(isfinite([h.duration_s h.stim_width_deg h.stim_height_deg ...
    h.fixation_width_deg h.fixation_height_deg h.initiation_width_deg h.initiation_height_deg ...
    h.offset_x_deg h.offset_y_deg])) && ...
    h.duration_s > 0 && all([h.stim_width_deg h.stim_height_deg ...
    h.fixation_width_deg h.fixation_height_deg h.initiation_width_deg h.initiation_height_deg] > 0), ...
    'Marmulator:SessionGeometry', 'Shared duration, stimulus sizes and fixation sizes must be positive.');
assert(all([h.stim_width_deg h.stim_height_deg h.fixation_width_deg h.fixation_height_deg ...
    h.initiation_width_deg h.initiation_height_deg] < 180), ...
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
        trial.duration_s = item.duration_s; % Chair calls always use the full video.
        trial.requested_duration_s = item.duration_s;
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
trial.initiation_size_deg = [h.initiation_width_deg h.initiation_height_deg];
trial.offset_deg = [h.offset_x_deg h.offset_y_deg];
trial.show_fixation_marker = strcmp(modality,'A');
trial.reward_fraction = config.reward_fraction;
trial.surround = config.surround;
validateattributes(trial.surround.inner_radius_deg,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(trial.surround.fade_width_deg,{'numeric'},{'scalar','real','finite','positive'});
assert(trial.surround.inner_radius_deg+trial.surround.fade_width_deg<90, ...
    'Marmulator:SurroundSize','Clear radius plus fade width must be less than 90 degrees.');
trial.background = 'gray';
end

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

function samples = session_audio_samples(trial,fs)
% Stereo samples prepared before stimulus onset; no audio work in the frame loop.
[samples,fileFs] = audioread(trial.audio_file);
assert(fileFs == fs, 'Marmulator:AudioSampleRate', ...
    'Stimulus audio must be %d Hz: %s is %d Hz.',fs,trial.audio_file,fileFs);
n = max(1,round(trial.duration_s*fs));
if trial.tone_hz<0 && trial.media_start_s>0
    first = min(size(samples,1)+1,1+round(trial.media_start_s*fs));
    samples = samples(first:end,:);
end
if trial.tone_hz > 0
    assert(trial.tone_hz < fs/2,'Marmulator:Nyquist','Tone is above Nyquist.');
    samples = sqrt(2)*.1*sin(2*pi*trial.tone_hz*(0:n-1)'/fs);
elseif trial.tone_hz == 0 && n>size(samples,1)
    % Repeat the exact deterministic white-noise file for longer presentations.
    samples = repmat(samples,ceil(n/size(samples,1)),1);
end
samples = samples(1:min(n,size(samples,1)),:);
% Prevent a click at a custom crop. Vocalizations end naturally when shorter.
nr = min(round(.005*fs),floor(size(samples,1)/2));
if nr > 1
    ramp = .5-.5*cos(pi*(0:nr-1)'/(nr-1));
    samples(1:nr,:) = samples(1:nr,:).*ramp;
    samples(end-nr+1:end,:) = samples(end-nr+1:end,:).*flipud(ramp);
end
if size(samples,2)==1, samples = repmat(samples,1,2); end
assert(size(samples,2)==2,'Marmulator:AudioChannels','Use mono or stereo stimulus audio.');
end

function [fraction, accumulated_s] = session_fixation_fraction(frame_onsets, inside, stimulus_off)
% Weight each displayed interval by its measured duration, including misses.
% NaN/invalid gaze is outside, rather than removed from the denominator.
times = [frame_onsets(:); stimulus_off];
weights = diff(times);
assert(numel(inside) == numel(weights) && all(isfinite(times)) && ...
    all(weights >= 0), 'Marmulator:FixationTimes', 'Invalid fixation interval timestamps.');
accumulated_s = sum(weights .* (inside(:) == 1));
if isempty(weights) || sum(weights) <= 0
    fraction = 0;
else
    fraction = accumulated_s / sum(weights);
end
end

function rect = session_foreground_rect(alpha)
% Minimal nonzero-alpha bounds in Screen's [left top right bottom] coordinates.
% Only outer padding is excluded; transparent gaps inside the bounds remain.
% Empty means the frame has no foreground.
foreground = alpha > 0;
rows = find(any(foreground,2));
cols = find(any(foreground,1));
rect = [];
if ~isempty(rows) && ~isempty(cols)
    rect = [cols(1)-1 rows(1)-1 cols(end) rows(end)];
end
end

function [rect,meanSize] = session_movie_geometry(frameRects,pts,startTime,duration,fullRect)
% Fixed crop and mean foreground size over the presented movie interval.
% Weight by frame visibility time, including a final frame held beyond EOF.
% Blank frames have zero foreground size and do not enlarge the crop.
pts = pts(:);
stopTime = startTime+duration;
starts = pts; starts(1) = min(starts(1),startTime);
ends = [pts(2:end); stopTime];
weights = max(0,min(ends,stopTime)-max(starts,startTime));
sizes = frameRects(:,3:4)-frameRects(:,1:2);
visible = weights>0 & all(sizes>0,2);
rect = fullRect;
meanSize = fullRect(3:4)-fullRect(1:2);
if any(visible)
    rect = [min(frameRects(visible,1:2),[],1) max(frameRects(visible,3:4),[],1)];
    meanSize = sum(sizes.*weights,1)/sum(weights);
end
end

function config = defaults(config)
% Fill new settings when loading older session JSON; preserve its reward rule.
if nargin<1, config=struct(); end
base = struct('version',2,'enabled',true,'reward_fraction',.7, ...
    'background','gray','actions_duration_s',4,'estimated_isi_s',.5);
base.shared = struct('duration_s',1.5,'stim_width_deg',12,'stim_height_deg',12, ...
    'fixation_width_deg',6,'fixation_height_deg',6,'initiation_width_deg',3, ...
    'initiation_height_deg',3,'offset_x_deg',0,'offset_y_deg',0);
base.surround = struct('enabled',false,'inner_radius_deg',7.5,'fade_width_deg',2.5);
base.run = struct('repeats',1,'inter_trial_interval_s',.5, ...
    'require_fixation',true,'fixation_before_s',.2,'fixation_timeout_s',Inf);
config = fill_defaults(config,base);
config.background = 'gray';
config.run.fixation_timeout_s = Inf;
config = rmfield(config,intersect(fieldnames(config),{'chair_duration_mode','chair_max_duration_s'}));
if isfield(config.run,'wait_for_2p'), config.run=rmfield(config.run,'wait_for_2p'); end
end

function value = fill_defaults(value,base)
for key = fieldnames(base)'
    name = key{1};
    if ~isfield(value,name)
        value.(name) = base.(name);
    elseif isstruct(base.(name))
        value.(name) = fill_defaults(value.(name),base.(name));
    end
end
end

function groups = scan_folders(root)
% Use prepared exports in each subfolder, without moving or converting media.
% Prefer one refined image variant and RGBA movies over alternate exports.
files = dir(fullfile(root,'**','*'));
files = files(~[files.isdir]);
folders = unique([{files.folder} {root}]);
groups = struct('name',{},'enabled',{},'modality',{},'timing',{}, ...
    'folder',{},'pattern',{},'kind',{},'has_alpha',{});
for f = 1:numel(folders)
    folder = folders{f}; relative = erase(folder,[root filesep]);
    if strcmp(folder,root), relative=''; end
    % These contain master/alternate exports, rather than the selected set.
    if contains(relative,'chair_exported_4set'), continue; end
    [~,leaf] = fileparts(folder);
    if ismember(leaf,{'masked','seeds'}) && isfolder(fullfile(fileparts(folder),'rgba')), continue; end
    names = {files(strcmp({files.folder},folder)).name};
    patterns = {'*_RGBA_sourcecolor_refinedmask.png','*_RGBA_bg-original_refined.png','*.png'};
    for k = 1:numel(patterns)
        if ~isempty(dir(fullfile(folder,patterns{k})))
            groups(end+1) = make_group(relative,relative,patterns{k},'image','shared','V',true); %#ok<AGROW>
            break
        end
    end
    for ext = {'.mkv','.avi','.mp4','.mov'}
        movies = names(endsWith(names,ext{1},'IgnoreCase',true));
        if isempty(movies), continue; end
        rgba = movies(contains(movies,'_rgba'));
        if ~isempty(rgba), movies=rgba; pattern=['*_rgba' ext{1}]; else, pattern=['*' ext{1}]; end
        timing='shared'; mode='V';
        if contains(relative,'vocalization'), timing='chair'; mode='AV'; end
        isAlpha = contains(relative,'rgba') || ~isempty(rgba);
        actions = regexp(movies,'_a-(.*?)_c-','tokens','once');
        actions = actions(~cellfun(@isempty,actions));
        if ~isempty(actions) && ~strcmp(timing,'chair')
            labels = unique(cellfun(@(x)x{1},actions,'UniformOutput',false));
            for a = 1:numel(labels)
                groups(end+1) = make_group(['arena/' labels{a}],relative, ...
                    ['*_a-' labels{a} '_*' ext{1}],'movie','actions',mode,isAlpha); %#ok<AGROW>
            end
        else
            groups(end+1) = make_group([relative ext{1}],relative,pattern,'movie',timing,mode,isAlpha); %#ok<AGROW>
        end
    end
    if ~isempty(names) && ~any(endsWith(names,{'.mkv','.avi','.mp4','.mov'},'IgnoreCase',true)) && ...
            any(endsWith(names,'.wav','IgnoreCase',true))
        groups(end+1) = make_group(relative,relative,'*.wav','audio','shared','A',false); %#ok<AGROW>
    end
end
assert(~isempty(groups),'Marmulator:EmptyFolders','No supported stimulus files in %s.',root);
end

function g = make_group(name,folder,pattern,kind,timing,mode,alpha)
if isempty(name), name='root'; end
% Match the existing default: selected chair calls only, others opt in.
g = struct('name',name,'enabled',strcmp(timing,'chair'),'modality',mode, ...
    'timing',timing,'folder',folder,'pattern',pattern,'kind',kind,'has_alpha',alpha);
end

function mask = surround(geometry, inner_radius_deg, fade_width_deg, background_level)
% Black alpha mask. Angles specify a clear radius and a radial transition.
validateattributes(inner_radius_deg,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(fade_width_deg,{'numeric'},{'scalar','real','finite','positive'});
outer_radius_deg = inner_radius_deg+fade_width_deg;
assert(outer_radius_deg<90,'Marmulator:SurroundSize','Outer radius must be less than 90 degrees.');
pixels_per_cm = geometry.resolution_px ./ geometry.size_cm;
distance_cm = geometry.viewing_distance_cm;
validateattributes(pixels_per_cm,{'numeric'},{'row','numel',2,'real','finite','positive'});
validateattributes(distance_cm,{'numeric'},{'scalar','real','finite','positive'});
radius_px = ceil(distance_cm*tand(outer_radius_deg)*pixels_per_cm);
[x,y] = meshgrid((.5:2*radius_px(1)-.5)-radius_px(1), ...
    (.5:2*radius_px(2)-.5)-radius_px(2));
radius_deg = atand(hypot(x/pixels_per_cm(1),y/pixels_per_cm(2))/distance_cm);
fade = max(0,min(1,(outer_radius_deg-radius_deg)/fade_width_deg));
fade = fade.^3 .* (10-15*fade+6*fade.^2);
% Preserve the existing smooth lightness fade (nominal display gamma 2.2).
gamma=2.2; background_level=max(background_level,eps);
luminance=background_level^gamma; kappa=(29/3)^3;
if luminance>(6/29)^3, lightness=116*luminance^(1/3)-16; else, lightness=kappa*luminance; end
lightness=lightness*fade; luminance=((lightness+16)/116).^3;
dark=lightness<=8; luminance(dark)=lightness(dark)/kappa;
gain=max(0,min(1,luminance.^(1/gamma)/background_level));
gain(radius_deg<=inner_radius_deg)=1; gain(radius_deg>=outer_radius_deg)=0;
mask=zeros(2*radius_px(2),2*radius_px(1),4,'uint8');
mask(:,:,4)=uint8(round(255*(1-gain)));
end
