function report = benchmark_mask_rendering(outputFile, frames, repeats, stimDegrees)
% Benchmark actual rig rendering without audio, rewards, triggers or eye IO.
% Opens the configured fullscreen subject display and half-size control view.
% Keeps PTB sync tests enabled. Run while acquisition is idle.
% Example: benchmark_mask_rendering('/tmp/mask_rendering.mat',120,2)
% This isolates rendering; it does not certify timing with acquisition hardware.
if nargin<1, outputFile=fullfile(tempdir,'mask_rendering.mat'); end
if nargin<2, frames=120; end
if nargin<3, repeats=2; end
if nargin<4, stimDegrees=[12 12]; end
validateattributes(frames,{'numeric'},{'scalar','integer','>',10});
validateattributes(repeats,{'numeric'},{'scalar','integer','positive'});
validateattributes(stimDegrees,{'numeric'},{'row','numel',2,'positive','<',180});
base=fileparts(fileparts(mfilename('fullpath'))); addpath(base);
sc=load(fullfile(base,'setup_config.mat'));
root=fullfile(getenv('HOME'),'Stimuli','stimuli_2p');
inventory=jsondecode(fileread(fullfile(root,'stimulus_inventory.json')));
paths={inventory.media.file};
indices=[find(startsWith(paths,'videos_AV/vocalization_phee/'),1), ...
    find(startsWith(paths,'videos_V/arena_exported_5set/rgba/'),1), ...
    find(startsWith(paths,'dots/'),1)];
assert(numel(indices)==3,'Expected chair, arena and dots movie fixtures.');
g=sc.display_geometry;
mask=flexible_2p('surround',g,7.5,2.5,.5);
report=struct('matlab',version,'geometry',g,'frames',frames,'repeats',repeats);
report.stimulus_degrees=stimDegrees;
report.mask_size=size(mask); report.mask_bytes=numel(mask);
times=zeros(1,12);
for k=1:numel(times)
    t=tic; flexible_2p('surround',g,7.5,2.5,.5); times(k)=toc(t);
end
report.mask_build_ms=stats(times(3:end)*1000);
report.runs=struct([]); report.preparation=struct([]);
oldSync=Screen('Preference','SkipSyncTests',0);
oldVerbosity=Screen('Preference','Verbosity',3);
oldVisual=Screen('Preference','VisualDebugLevel',0);
oldPriority=Priority;
cleanup=onCleanup(@()finish(oldSync,oldVerbosity,oldVisual,oldPriority)); %#ok<NASGU>
PsychImaging('PrepareConfiguration');
[win,windowRect]=PsychImaging('OpenWindow',sc.screenid_stim,128,[]);
assert(isequal(windowRect(3:4),g.resolution_px),'Rig display resolution mismatch.');
[ctrl,~]=PsychImaging('OpenWindow',sc.screenid_ctrl,128,windowRect*.5);
Screen('BlendFunction',win,'GL_SRC_ALPHA','GL_ONE_MINUS_SRC_ALPHA');
Screen('BlendFunction',ctrl,'GL_SRC_ALPHA','GL_ONE_MINUS_SRC_ALPHA');
report.gpu=Screen('GetWindowInfo',win);
report.ifi=Screen('GetFlipInterval',win);
report.ctrl_ifi=Screen('GetFlipInterval',ctrl);
report.nominal_hz=[Screen('NominalFrameRate',sc.screenid_stim), ...
    Screen('NominalFrameRate',sc.screenid_ctrl)];
Priority(1);
maskTex=Screen('MakeTexture',win,mask);
maskCtrl=Screen('MakeTexture',ctrl,mask);
center=windowRect(3:4)/2;
maskSize=[size(mask,2),size(mask,1)];
aperture=[center-maskSize/2 center+maskSize/2];
bands=[0 0 windowRect(3) aperture(2); ...
    0 aperture(4) windowRect(3:4); ...
    0 aperture(2) aperture(1) aperture(4); ...
    aperture(3) aperture(2) windowRect(3) aperture(4)]';
sizePx=2*g.viewing_distance_cm*tand(stimDegrees/2).*g.pixels_per_cm;
bounds=[center-sizePx/2 center+sizePx/2];
ifi=report.ifi;
labels={'legacy_subject','session_subject','session_surround', ...
    'session_preview','session_preview_surround'};
for itemIndex=indices
    media=inventory.media(itemIndex);
    trial=struct('kind','movie','visual_file',fullfile(root,media.file), ...
        'audio_file','','has_alpha',~startsWith(media.file,'dots/'), ...
        'media_start_s',0,'duration_s',frames*ifi, ...
        'show_fixation_marker',false,'background','gray');
    player=SessionStimulusPlayer(win,[],96000);
    playerCleanup=onCleanup(@()delete(player));
    t=tic; player.prepare(trial); cold=toc(t);
    t=tic; player.prepare(trial); warm=toc(t);
    prep=struct('file',media.file, ...
        'first_s',cold,'cached_s',warm,'source_rect',player.sourceRect, ...
        'normalization_size',player.normalizationSize);
    if isempty(report.preparation), report.preparation=prep;
    else, report.preparation(end+1)=prep; end
    player.stop();
    fprintf('PREP %s: first %.3f s, cached %.3f s\n',media.file,cold,warm);
    save(outputFile,'report');
    for rep=1:repeats
        % Alternate traversal direction to reduce order and warm-up bias.
        order=1:5; if mod(rep,2)==0, order=5:-1:1; end
        for mode=order
            legacy=mode==1; usePreview=mode>=4;
            useMask=ismember(mode,[3 5]);
            if legacy
                movie=Screen('OpenMovie',win,trial.visual_file,0,1,2,4);
                texture=Screen('GetMovieImage',win,movie,1,0);
                assert(texture>0,'No first movie frame.');
                Screen('SetMovieTimeIndex',movie,0);
                Screen('PlayMovie',movie,1,0,0);
            else
                player.prepare(trial); player.start(GetSecs()+ifi);
            end
            Screen('FillRect',win,128); vbl=Screen('Flip',win);
            compute=zeros(frames,1); intervals=compute; missed=compute;
            flipEnd=compute; pts=nan(frames,1);
            for frame=1:frames
                t0=GetSecs;
                Screen('FillRect',win,128);
                if usePreview, Screen('FillRect',ctrl,128); end
                if legacy
                    [next,pt]=Screen('GetMovieImage',win,movie,0);
                    if next>0, Screen('Close',texture); texture=next; pts(frame)=pt; end
                    Screen('DrawTexture',win,texture,[],bounds);
                else
                    control=[]; if usePreview, control=ctrl; end
                    player.draw(win,control,bounds,.5);
                end
                if useMask
                    if usePreview
                        Screen('FillRect',ctrl,0,bands*.5);
                        Screen('DrawTexture',ctrl,maskCtrl,[],aperture*.5);
                    end
                end
                if usePreview
                    % Matches engine's nonblocking operator flip.
                    Screen('Flip',ctrl,0,0,1);
                end
                if useMask
                    Screen('FillRect',win,0,bands);
                    Screen('DrawTexture',win,maskTex,[],aperture);
                end
                compute(frame)=GetSecs-t0;
                previous=vbl;
                [vbl,~,flipEnd(frame),missed(frame)]=Screen('Flip',win,vbl+ifi/2);
                intervals(frame)=vbl-previous;
            end
            if legacy
                moviePts=pts(isfinite(pts));
                Screen('PlayMovie',movie,0); Screen('CloseMovie',movie); Screen('Close',texture);
            else
                moviePts=player.moviePTS; player.stop();
            end
            % Exclude the first ten refreshes from steady-state statistics.
            measured=11:frames;
            run=struct('file',media.file,'mode',labels{mode},'repeat',rep, ...
                'compute_ms',stats(1000*compute(measured)), ...
                'interval_ms',stats(1000*intervals(measured)), ...
                'missed_deadlines',sum(missed(measured)>0), ...
                'long_intervals',sum(intervals(measured)>1.5*ifi), ...
                'all_missed_deadlines',sum(missed>0), ...
                'all_long_intervals',sum(intervals>1.5*ifi), ...
                'frame_count',numel(measured),'movie_frames',numel(moviePts), ...
                'pts_large_gaps',sum(diff(moviePts)>1.5/media.fps), ...
                'movie_pts',moviePts,'raw_compute_s',compute, ...
                'raw_interval_s',intervals,'raw_missed_s',missed, ...
                'raw_flip_end_s',flipEnd);
            if isempty(report.runs), report.runs=run;
            else, report.runs(end+1)=run; end
            fprintf('%s rep %d %s: compute p50/p95 %.3f/%.3f ms, late %d/%d, long %d\n', ...
                media.file,rep,run.mode,run.compute_ms.median, ...
                run.compute_ms.p95,run.missed_deadlines,run.frame_count,run.long_intervals);
            save(outputFile,'report');
        end
    end
    clear playerCleanup
end
report.completed=true; save(outputFile,'report');
end

function s=stats(values)
values=sort(values(:)); n=numel(values);
s=struct('median',median(values),'p95',values(max(1,ceil(.95*n))), ...
    'maximum',max(values));
end

function finish(sync,verbosity,visual,priority)
Screen('CloseAll'); ShowCursor; Priority(priority);
Screen('Preference','SkipSyncTests',sync);
Screen('Preference','Verbosity',verbosity);
Screen('Preference','VisualDebugLevel',visual);
end
