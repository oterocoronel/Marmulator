classdef SessionStimulusPlayer < handle
    % Only the current movie/image is open. AV and V share the same file.
    properties
        win
        audio
        sampleRate
        movie = []
        texture = []
        trial
        started = false
        audioStarted = false
        audioStart = NaN
        moviePTS = []
        visualSize = [1 1]
        normalizationSize = [1 1]
        sourceRect = []
    end
    properties (Access = private)
        previewWindow = []
        previewTexture = []
        previewBuffer = []
        previewSize = []
        previewFrameRect = []
        previewDirty = true
        movieCropCache
    end
    methods
        function obj = SessionStimulusPlayer(win,audio,sampleRate)
            obj.win = win; obj.audio = audio; obj.sampleRate = sampleRate;
            obj.movieCropCache = containers.Map('KeyType','char','ValueType','any');
        end
        function prepare(obj,trial)
            obj.stop();
            obj.trial = trial;
            obj.started = false; obj.audioStarted = false;
            obj.audioStart = NaN; obj.moviePTS = [];
            obj.visualSize = [1 1]; obj.normalizationSize = [1 1]; obj.sourceRect = [];
            if ~isempty(trial.visual_file)
                if strcmp(trial.kind,'movie')
                    % Decode RGBA with sound disabled; all sound uses PsychPortAudio.
                    [obj.movie,~,~,w,h] = Screen('OpenMovie',obj.win,trial.visual_file,0,1,6,4);
                    obj.sourceRect = [0 0 w h];
                    obj.normalizationSize = [w h];
                    if trial.has_alpha
                        duration = trial.duration_s;
                        if isfield(trial,'scheduled_duration_s'), duration = trial.scheduled_duration_s; end
                        [obj.sourceRect,obj.normalizationSize] = obj.movieForegroundGeometry( ...
                            trial.visual_file,obj.sourceRect,trial.media_start_s,duration);
                    end
                    obj.visualSize = obj.sourceRect(3:4)-obj.sourceRect(1:2);
                    Screen('SetMovieTimeIndex',obj.movie,trial.media_start_s);
                    [obj.texture,pts] = Screen('GetMovieImage',obj.win,obj.movie,1,trial.media_start_s);
                    assert(obj.texture>0,'Marmulator:EmptyMovie','No first frame in %s.',trial.visual_file);
                    obj.moviePTS = pts;
                    Screen('SetMovieTimeIndex',obj.movie,trial.media_start_s);
                else
                    [rgb,map,alpha] = imread(trial.visual_file);
                    if ~isempty(map), rgb = uint8(255*ind2rgb(rgb,map)); end
                    if size(rgb,3)==1, rgb = repmat(rgb,1,1,3); end
                    if ~isempty(alpha), rgb(:,:,4) = alpha; end
                    obj.visualSize = [size(rgb,2) size(rgb,1)];
                    obj.sourceRect = [0 0 obj.visualSize];
                    if ~isempty(alpha)
                        foregroundRect = session_foreground_rect(alpha);
                        if ~isempty(foregroundRect), obj.sourceRect = foregroundRect; end
                    end
                    obj.visualSize = obj.sourceRect(3:4)-obj.sourceRect(1:2);
                    obj.normalizationSize = obj.visualSize;
                    obj.texture = Screen('MakeTexture',obj.win,rgb);
                end
            end
            if ~isempty(trial.audio_file)
                samples = session_audio_samples(trial,obj.sampleRate);
                PsychPortAudio('FillBuffer',obj.audio,samples');
            end
        end
        function start(obj,onset)
            if obj.started, return; end
            if ~isempty(obj.movie), Screen('PlayMovie',obj.movie,1,0,0); end
            if ~isempty(obj.trial.audio_file)
                PsychPortAudio('Start',obj.audio,1,onset,0);
                obj.audioStarted = true;
            end
            obj.started = true;
        end
        function rect = draw(obj,win,ctrlWin,bounds,scale)
            if ~isempty(obj.movie) && obj.started
                [tex,pts] = Screen('GetMovieImage',win,obj.movie,0);
                if tex>0
                    if ~isempty(obj.texture), Screen('Close',obj.texture); end
                    obj.texture = tex;
                    obj.previewDirty = true;
                    obj.moviePTS(end+1) = pts;
                end
            end
            % Fit average movie foreground (or the image crop) without distortion.
            % The fixed movie crop can exceed the target as the foreground grows.
            % Movie EOF holds the last frame until offset.
            sizePx = bounds(3:4)-bounds(1:2);
            fit = min(sizePx./obj.normalizationSize);
            sizePx = obj.visualSize*fit;
            center = (bounds(1:2)+bounds(3:4))/2;
            rect = [center-sizePx/2 center+sizePx/2];
            if ~isempty(obj.texture)
                Screen('DrawTexture',win,obj.texture,obj.sourceRect,rect);
                if ~isempty(ctrlWin)
                    previewRect = obj.updatePreview(ctrlWin,rect*scale);
                    if ~isempty(previewRect)
                        Screen('DrawTexture',ctrlWin,obj.previewTexture,[],previewRect);
                    end
                end
            end
            if obj.trial.show_fixation_marker
                color = 255;
                if strcmp(obj.trial.background,'white'), color = 0; end
                Screen('DrawDots',win,center,10,color,[],1);
                if ~isempty(ctrlWin)
                    Screen('DrawDots',ctrlWin,center*scale,10*scale,color,[],1);
                end
            end
        end
        function stop(obj)
            if obj.audioStarted
                status = PsychPortAudio('GetStatus',obj.audio);
                obj.audioStart = status.StartTime;
                PsychPortAudio('Stop',obj.audio,0);
                obj.audioStarted = false;
            end
            if ~isempty(obj.movie)
                Screen('PlayMovie',obj.movie,0);
                Screen('CloseMovie',obj.movie); obj.movie = [];
            end
            if ~isempty(obj.texture), Screen('Close',obj.texture); obj.texture = []; end
            obj.closePreview();
        end
        function delete(obj)
            try, obj.stop(); catch, end
        end
    end
    methods (Access = private)
        function [rect,meanSize] = movieForegroundGeometry(obj,path,fullRect,startTime,duration)
            % Cache per-frame bounds so timing edits need no further decoding.
            % Crop and scale stay fixed throughout the selected presentation.
            info = dir(path);
            if isKey(obj.movieCropCache,path)
                cached = obj.movieCropCache(path);
                if cached.bytes==info.bytes && cached.datenum==info.datenum
                    [rect,meanSize] = session_movie_geometry( ...
                        cached.rects,cached.pts,startTime,duration,fullRect);
                    return
                end
            end
            Screen('SetMovieTimeIndex',obj.movie,0);
            rects = zeros(0,4); pts = zeros(0,1); hasTransparency = false;
            while true
                % Paused playback steps through every frame without real-time waits.
                [tex,frameTime] = Screen('GetMovieImage',obj.win,obj.movie,1);
                if tex<=0, break; end
                frameCleanup = onCleanup(@()Screen('Close',tex));
                rgba = Screen('GetImage',tex,[],[],[],4);
                assert(size(rgba,3)==4,'Marmulator:LostMovieAlpha', ...
                    'Decoder discarded alpha in %s. Install GStreamer VP9 alpha support before running.',path);
                alpha = rgba(:,:,4);
                hasTransparency = hasTransparency || any(alpha(:)<255);
                frameRect = session_foreground_rect(alpha);
                if isempty(frameRect), frameRect = [0 0 0 0]; end
                rects(end+1,:) = frameRect; %#ok<AGROW>
                pts(end+1,1) = frameTime; %#ok<AGROW>
                clear frameCleanup
            end
            assert(~isempty(pts),'Marmulator:EmptyMovie','No frames in %s.',path);
            assert(hasTransparency,'Marmulator:LostMovieAlpha', ...
                'Decoder discarded alpha in %s. Install GStreamer VP9 alpha support before running.',path);
            obj.movieCropCache(path) = struct('bytes',info.bytes,'datenum',info.datenum, ...
                'rects',rects,'pts',pts);
            [rect,meanSize] = session_movie_geometry(rects,pts,startTime,duration,fullRect);
        end
        function copyRect = updatePreview(obj,ctrlWin,rect)
            % Separate X screens need textures created in their own GL context.
            % Copy the current decoded frame, rather than opening a second movie.
            % Downsample on the subject GPU before readback to limit transfer cost.
            % Render at the actual preview pixel positions, including fractional
            % edges, then transfer 1:1. Rounding and rescaling twice aliases dots.
            viewport = Screen('Rect',ctrlWin);
            copyRect = [max(floor(rect(1:2)),viewport(1:2)) ...
                min(ceil(rect(3:4)),viewport(3:4))];
            targetSize = copyRect(3:4)-copyRect(1:2);
            if any(targetSize<=0), copyRect = []; return; end
            frameRect = rect-[copyRect(1:2) copyRect(1:2)];
            if ~isequal(obj.previewWindow,ctrlWin) || ~isequal(obj.previewSize,targetSize)
                obj.closePreview();
                obj.previewWindow = ctrlWin; obj.previewSize = targetSize;
                obj.previewBuffer = Screen('OpenOffscreenWindow',obj.win,[0 0 0 0], ...
                    [0 0 targetSize],32);
                % Copy straight RGBA; blending here would apply alpha twice.
                Screen('BlendFunction',obj.previewBuffer,'GL_ONE','GL_ZERO');
            end
            if ~isequal(obj.previewFrameRect,frameRect)
                obj.previewFrameRect = frameRect; obj.previewDirty = true;
            end
            if obj.previewDirty
                Screen('FillRect',obj.previewBuffer,[0 0 0 0]);
                Screen('DrawTexture',obj.previewBuffer,obj.texture,obj.sourceRect,frameRect);
                rgba = Screen('GetImage',obj.previewBuffer,[],[],[],4);
                if ~isempty(obj.previewTexture), Screen('Close',obj.previewTexture); end
                obj.previewTexture = Screen('MakeTexture',ctrlWin,rgba);
                obj.previewDirty = false;
            end
        end
        function closePreview(obj)
            if ~isempty(obj.previewTexture), Screen('Close',obj.previewTexture); end
            if ~isempty(obj.previewBuffer), Screen('Close',obj.previewBuffer); end
            obj.previewTexture = []; obj.previewBuffer = [];
            obj.previewWindow = []; obj.previewSize = []; obj.previewFrameRect = [];
            obj.previewDirty = true;
        end
    end
end
