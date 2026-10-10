function config = discover_session_stimuli(config)
% Folder contents define the session. The inventory only caches movie headers.
headers = containers.Map('KeyType','char','ValueType','any');
inventory = fullfile(config.root,'stimulus_inventory.json');
if isfile(inventory)
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
                if ~isfield(header,'file_bytes') || header.file_bytes==file.bytes
                    item.duration_s = header.visual_duration_s;
                    item.has_alpha = header.alpha;
                end
            end
            if strcmp(g.timing,'chair')
                identity = regexprep(label,'_(rgba|masked)$','');
                audio = fullfile(folder,[identity '_denoised.wav']);
                if ~isfile(audio)
                    source = fullfile(config.root,'videos_AV','chair_exported_4set', ...
                        'wav_denoised',[identity '_denoised.wav']);
                    assert(isfile(source),'Marmulator:MissingAudio', ...
                        'No matching denoised WAV for %s.',path);
                    copyfile(source,audio);
                end
                item.audio_file = audio;
                info = audioinfo(audio);
                item.duration_s = max(item.duration_s,info.Duration);
            elseif item.duration_s<=0
                % New files can be selected without maintaining an ID manifest.
                reader = VideoReader(path);
                item.duration_s = reader.Duration;
            end
        end
        items(end+1) = item; %#ok<AGROW>
    end
end
config.items = items;
end
