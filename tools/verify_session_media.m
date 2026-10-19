function verify_session_media(root)
% Small windows on both rig displays; no audio/rewards/triggers.
if nargin<1, root = fullfile(getenv('HOME'),'Stimuli','stimuli_2p'); end
base = fileparts(fileparts(mfilename('fullpath')));
sc = load(fullfile(base,'setup_config.mat'));
c = flexible_2p('catalog',root);
oldSync = Screen('Preference','SkipSyncTests',1);
try
    PsychImaging('PrepareConfiguration');
    win = PsychImaging('OpenWindow',sc.screenid_stim,0,[50 50 370 370]);
    ctrl = PsychImaging('OpenWindow',sc.screenid_ctrl,0,[450 50 610 210]);
    Screen('BlendFunction',win,'GL_SRC_ALPHA','GL_ONE_MINUS_SRC_ALPHA');
    Screen('BlendFunction',ctrl,'GL_SRC_ALPHA','GL_ONE_MINUS_SRC_ALPHA');
    reference = Screen('OpenOffscreenWindow',win,0,[0 0 160 160],32);
    Screen('BlendFunction',reference,'GL_SRC_ALPHA','GL_ONE_MINUS_SRC_ALPHA');
    p = SessionStimulusPlayer(win,[],96000);
catch err
    finish(oldSync); rethrow(err);
end
cleanup = onCleanup(@()finish(oldSync,p)); %#ok<NASGU>
% Every selected vocalization, plus one file per other set.
indices = find(ismember({c.items.set_name},{'phee','tisk'}));
for g = 1:numel(c.groups)
    idx = find(strcmp({c.items.set_name},c.groups(g).name),1);
    if ~isempty(idx) && ~strcmp(c.items(idx).kind,'audio'), indices(end+1)=idx; end %#ok<AGROW>
end
for idx = unique(indices)
    g = find(strcmp({c.groups.name},c.items(idx).set_name));
    c.groups(g).enabled = true; c.groups(g).modality = 'V';
    t = flexible_2p('trial',c,c.items(idx),'V');
    p.prepare(t);
    if t.media_start_s>0
        assert(abs(p.moviePTS(1)-t.media_start_s)<.1, ...
            'Action seek missed the requested start: %s',t.label);
    end
    if t.has_alpha
        rgba = Screen('GetImage',p.texture,[],[],[],4);
        assert(min(rgba(:,:,4),[],'all') < 255,'Alpha discarded: %s',t.label);
        % The same transparent frame must show a different chosen background.
        Screen('FillRect',win,[20 40 60]); Screen('FillRect',ctrl,[20 40 60]);
        p.draw(win,ctrl,[0 0 320 320],.5);
        first = Screen('GetImage',win,[],'backBuffer');
        firstCtrl = Screen('GetImage',ctrl,[],'backBuffer');
        Screen('FillRect',win,[100 120 140]); Screen('FillRect',ctrl,[100 120 140]);
        p.draw(win,ctrl,[0 0 320 320],.5);
        second = Screen('GetImage',win,[],'backBuffer');
        secondCtrl = Screen('GetImage',ctrl,[],'backBuffer');
        assert(any(abs(double(first(:))-double(second(:)))>60),'Background did not change through alpha.');
        assert(any(abs(double(firstCtrl(:))-double(secondCtrl(:)))>60),'Preview lost transparency.');
    end
    p.start(GetSecs()+.02);
    for k = 1:5
        Screen('FillRect',win,80); Screen('FillRect',ctrl,80);
        rect = p.draw(win,ctrl,[0 0 320 320],.5);
        assertPreview(p,ctrl,reference,rect*.5,80);
        Screen('Flip',ctrl);
        Screen('Flip',win);
    end
    % Rebuild the preview when the stimulus bounds change, retaining alpha.
    Screen('FillRect',win,80); Screen('FillRect',ctrl,80);
    rect = p.draw(win,ctrl,[40 50 300 290],.5);
    assertPreview(p,ctrl,reference,rect*.5,80);
    p.stop();
    % Only the two displays and the test reference buffer should remain open.
    assert(numel(Screen('Windows'))==3,'Stimulus textures leaked after stop.');
    fprintf('PASS media %s\n',t.label);
end
fprintf('Verified %d stimuli on both displays, including preview pixels, resizing and RGBA.\n',numel(unique(indices)));
g = find(strcmp({c.groups.name},'tones')); c.groups(g).enabled = true;
idx = find(strcmp({c.items.set_name},'tones'),1);
t = flexible_2p('trial',c,c.items(idx),'A'); t.audio_file = ''; % Inspect the marker silently.
for background = {'gray','black','white'}
    t.background = background{1}; p.prepare(t);
    value = 0; if strcmp(t.background,'gray'), value=128; end
    if strcmp(t.background,'white'), value=255; end
    Screen('FillRect',win,value); Screen('FillRect',ctrl,value);
    p.draw(win,ctrl,[0 0 320 320],.5);
    pixels = Screen('GetImage',win,[],'backBuffer');
    preview = Screen('GetImage',ctrl,[],'backBuffer');
    marker = double(pixels(160,160,1));
    assert(abs(marker-value)>100,'A-only fixation marker is not visible.');
    assert(abs(double(preview(80,80,1))-value)>100,'A-only preview marker is not visible.');
    Screen('Flip',ctrl); Screen('Flip',win); p.stop();
    fprintf('PASS A-only fixation marker on %s\n',t.background);
end
end
function assertPreview(player,ctrl,reference,rect,background)
% Draw the subject's texture in its own context as an independent reference.
% Cross-display DrawTexture can silently paint a white rectangle on this rig.
Screen('FillRect',reference,background);
Screen('DrawTexture',reference,player.texture,player.sourceRect,rect);
expected = Screen('GetImage',reference);
actual = Screen('GetImage',ctrl,[],'backBuffer');
assert(std(double(expected(:)))>3,'Reference stimulus has no visible detail.');
error = mean(abs(double(actual(:))-double(expected(:))));
assert(error<3,'Preview differs from the subject frame: mean pixel error %.3f in %s.', ...
    error,player.trial.label);
end
function finish(oldSync,player)
if nargin>1 && isvalid(player), delete(player); end
Screen('CloseAll'); ShowCursor;
Screen('Preference','SkipSyncTests',oldSync);
end
