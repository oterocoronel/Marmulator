function tests = test_session_engine
tests = functiontests(localfunctions);
end
function setupOnce(testCase)
% Temporary fakes avoid opening displays, playing sound or contacting hardware.
% They live outside the repository so startup's genpath cannot expose them.
base = fileparts(fileparts(mfilename('fullpath')));
folder = tempname; mkdir(folder);
testCase.TestData.base = base;
testCase.TestData.folder = folder;
testCase.TestData.oldDir = pwd;
writeFake(folder,'Screen',[
"function varargout=Screen(command,varargin)"
"global MARMULATOR_TEST; s=MARMULATOR_TEST; out={};"
"switch lower(command)"
"case 'rect', out={[0 0 2560 1600]};"
"case 'openwindow', s.handle=s.handle+1; out={s.handle,[0 0 2560 1600]};"
"case 'getflipinterval', out={.01};"
"case 'nominalframerate', out={100};"
"case 'flip'"
"if varargin{1}==1"
"s.clock=s.clock+.01;"
"if s.drawn, s.subjectFrames=s.subjectFrames+1; s.drawn=false; end"
"if s.dropOnce && s.subjectFrames==3, s.clock=s.clock+.02; s.dropOnce=false; end"
"end; out={s.clock};"
"case 'drawtexture', if varargin{1}==1, s.drawn=true; end"
"case 'drawdots'"
"if varargin{1}==1, s.drawn=true; s.markerDraws=s.markerDraws+1; color=varargin{4}; s.markerColors(end+1)=color(1); end"
"case 'setmovietimeindex', s.lastSeek=varargin{2}; s.movieSeeks(end+1)=s.lastSeek; s.movieFrame=false;"
"case {'maketexture','openmovie'}, s.handle=s.handle+1; out={s.handle,.02,40,64,64,1};"
"case 'getmovieimage'"
"if numel(varargin)>=4 && varargin{4}>=0, s.lastSeek=varargin{4}; end"
"if ~s.movieFrame, s.handle=s.handle+1; out={s.handle,s.lastSeek}; s.movieFrame=true; else, out={-1,0}; end"
"case 'closemovie', s.movieFrame=false;"
"case 'getimage', rgba=uint8(ones(2,2,4)*255); rgba(1,1,4)=0; out={rgba};"
"otherwise, out={0};"
"end"
"MARMULATOR_TEST=s; varargout=out(1:nargout);"
"end"]);
writeFake(folder,'PsychImaging',[
"function varargout=PsychImaging(command,varargin)"
"if strcmp(command,'OpenWindow'), [varargout{1:nargout}]=Screen('OpenWindow',varargin{:}); end"
"end"]);
writeFake(folder,'PsychPortAudio',[
"function varargout=PsychPortAudio(command,varargin)"
"global MARMULATOR_TEST; out={0};"
"switch command"
"case 'GetDevices', out={struct('DeviceName','fake','DeviceIndex',0)};"
"case 'Open', MARMULATOR_TEST.sampleRate=varargin{4}; out={99};"
"case 'CreateBuffer', out={1};"
"case 'GetStatus', out={struct('Active',false,'StartTime',MARMULATOR_TEST.clock)};"
"case 'FillBuffer', if ~isscalar(varargin{2}), MARMULATOR_TEST.audioFills=MARMULATOR_TEST.audioFills+1; end"
"end"
"varargout=out(1:nargout);"
"end"]);
writeFake(folder,'IOPort',[
"function varargout=IOPort(command,varargin)"
"global MARMULATOR_TEST; if strcmp(command,'Write'), MARMULATOR_TEST.commands{end+1}=varargin{2}; end"
"varargout=cell(1,nargout);"
"end"]);
writeFake(folder,'GetSecs',["function value=GetSecs";"global MARMULATOR_TEST; value=MARMULATOR_TEST.clock;";"end"]);
writeFake(folder,'GetMouse',["function [x,y]=GetMouse(varargin)";"global MARMULATOR_TEST; x=MARMULATOR_TEST.gaze(1); y=MARMULATOR_TEST.gaze(2);";"end"]);
writeFake(folder,'KbName',["function code=KbName(key)";"keys={'ESCAPE','ESC','r','b','v','t'}; code=find(strcmp(keys,key),1); if isempty(code), code=1; end";"end"]);
writeFake(folder,'KbCheck',["function [down,t,keys]=KbCheck(varargin)";"global MARMULATOR_TEST; down=false; t=GetSecs; keys=false(1,256);"
"if MARMULATOR_TEST.escape && MARMULATOR_TEST.subjectFrames>=2, down=true; keys(1)=true; end";"end"]);
for name = {'AssertOpenGL','PsychJavaSwingCleanup','InitializePsychSound','ShowCursor','HideCursor','WaitSecs','sca','logData_bysession'}
    writeFake(folder,name{1},["function "+name{1}+"(varargin)";"end"]);
end
writeFake(folder,'WhiteIndex',["function x=WhiteIndex(varargin)";"x=255;";"end"]);
writeFake(folder,'BlackIndex',["function x=BlackIndex(varargin)";"x=0;";"end"]);
writeFake(folder,'Priority',["function x=Priority(varargin)";"x=0;";"end"]);
addpath(folder,'-begin'); cd(folder);
end
function teardownOnce(testCase)
cd(testCase.TestData.oldDir); rmpath(testCase.TestData.folder);
rmdir(testCase.TestData.folder,'s');
clear global MARMULATOR_TEST
end
function testFixedDurationRegardlessOfGaze(testCase)
inside = runSession(testCase,[1280 800],[]);
outside = runSession(testCase,[-100 -100],[]);
verifyEqual(testCase,inside.calib.n_completed,7);
verifyEqual(testCase,inside.calib.end_t-inside.calib.start_t,.05*ones(1,7),'AbsTol',1e-10);
verifyEqual(testCase,outside.calib.end_t-outside.calib.start_t,.05*ones(1,7),'AbsTol',1e-10);
verifyEqual(testCase,inside.calib.fixation_fraction,ones(1,7));
verifyEqual(testCase,outside.calib.fixation_fraction,zeros(1,7));
verifyTrue(testCase,all(inside.reward.correct_trial));
verifyFalse(testCase,any(outside.reward.correct_trial));
verifyEqual(testCase,inside.settings.ifi_monitor,.01);
verifyEqual(testCase,inside.calib_settings.session_config.reward_fraction,.7);
end
function testLiveEditsAtTrialBoundary(testCase)
output = runSession(testCase,[1280 800],@shorter);
verifyEqual(testCase,output.calib.end_t-output.calib.start_t,.03*ones(1,7),'AbsTol',1e-10);
for t = output.calib.session_trials
    verifyEqual(testCase,t{1}.duration_s,.03);
end
end
function t = shorter(t,~)
t.duration_s=.03;
end
function testLiveExclusion(testCase)
output = runSession(testCase,[1280 800],@excludeArena);
verifyEqual(testCase,output.calib.n_completed,6);
verifyEqual(testCase,sum(output.calib.session_skipped),1);
end
function t = excludeArena(t,~)
if startsWith(t.set_name,'arena/'), t=[]; end
end
function testMissedDisplayFrameDoesNotExtendTrial(testCase)
output = runSession(testCase,[1280 800],[],true,false);
verifyEqual(testCase,output.calib.end_t-output.calib.start_t,.05*ones(1,7),'AbsTol',1e-10);
verifyEqual(testCase,output.calib.fixation_fraction,ones(1,7));
end
function testEscapeAbortsWithoutReward(testCase)
output = runSession(testCase,[1280 800],[],false,true);
verifyEqual(testCase,output.calib.n_completed,0);
verifyTrue(testCase,output.calib.trial_aborted(1));
verifyFalse(testCase,any(output.reward.correct_trial));
verifyNotEmpty(testCase,output.calib.frame_st_t{1});
end
function testOptionalFixationInitiation(testCase)
output = runSession(testCase,[1280 800],[],false,false,true);
verifyTrue(testCase,all(isfinite(output.calib.stim_pre_start)));
verifyTrue(testCase,all(output.calib.stim_pre_end>output.calib.stim_pre_start));
verifyEqual(testCase,output.calib.end_t-output.calib.start_t,.05*ones(1,7),'AbsTol',1e-10);
end
function testAudioMarkerAndCenteredMovieSeek(testCase)
output = runSession(testCase,[1280 800],@whiteBackground);
global MARMULATOR_TEST
verifyGreaterThanOrEqual(testCase,MARMULATOR_TEST.markerDraws,15);
verifyEqual(testCase,MARMULATOR_TEST.markerColors,zeros(size(MARMULATOR_TEST.markerColors)));
for i = 1:numel(output.calib.session_trials)
    t = output.calib.session_trials{i};
    verifyEqual(testCase,t.show_fixation_marker,strcmp(t.modality,'A'));
    if strcmp(t.modality,'A')
        verifyEmpty(testCase,t.visual_source_rect_px);
        verifyEmpty(testCase,t.visual_scale);
    else
        verifyNotEmpty(testCase,t.visual_source_rect_px);
        verifyEqual(testCase,t.visual_scale, ...
            min((t.stim_rect_px(3:4)-t.stim_rect_px(1:2))./t.visual_mean_foreground_size_px),'AbsTol',1e-10);
        verifyEqual(testCase,(t.visual_rect_px(1:2)+t.visual_rect_px(3:4))/2, ...
            (t.fixation_rect_px(1:2)+t.fixation_rect_px(3:4))/2,'AbsTol',1e-10);
    end
    if startsWith(t.set_name,'arena/')
        verifyEqual(testCase,t.media_start_s,(t.native_duration_s-t.duration_s)/2,'AbsTol',1e-9);
        verifyTrue(testCase,any(abs(MARMULATOR_TEST.movieSeeks-t.media_start_s)<1e-9));
        verifyEqual(testCase,output.calib.movie_pts{i}(1),t.media_start_s,'AbsTol',1e-9);
    else
        verifyEqual(testCase,t.media_start_s,0);
    end
end
end
function t = whiteBackground(t,~)
t.background = 'white';
end
function output = runSession(testCase,gaze,reader,drop,escape,requireFix)
if nargin<4, drop=false; end
if nargin<5, escape=false; end
if nargin<6, requireFix=false; end
global MARMULATOR_TEST
MARMULATOR_TEST=struct('clock',100,'handle',0,'gaze',gaze,'movieFrame',false,'audioFills',0, ...
    'drawn',false,'subjectFrames',0,'dropOnce',drop,'escape',escape,'commands',{{}}, ...
    'lastSeek',0,'movieSeeks',[],'markerDraws',0,'markerColors',[]);
base=testCase.TestData.base;
c=load_stimulus_catalog(fullfile(getenv('HOME'),'Stimuli','stimuli_2p'));
for k=1:numel(c.groups), c.groups(k).enabled=false; end
for k=1:numel(c.items), c.items(k).enabled=false; end
c.shared.duration_s=.05; c.actions_duration_s=.05;
c.chair_duration_mode='cap'; c.chair_max_duration_s=.05;
% One image, three conditions of one call, one silent movie, tone and noise.
sets={'bodies','phee','arena/grasping','tones'};
for k=1:numel(sets)
    g=find(strcmp({c.groups.name},sets{k}));
    c.groups(g).enabled=true;
    i=find(strcmp({c.items.set_name},sets{k}),1); c.items(i).enabled=true;
    if strcmp(sets{k},'phee'), c.groups(g).modality='AV,A,V'; end
    if strcmp(sets{k},'tones')
        i=find(strcmp({c.items.set_name},'tones') & [c.items.tone_hz]==0);
        c.items(i).enabled=true;
    end
end
sc=load(fullfile(base,'setup_config.mat'));
sc.default_gaze_center_adjust=[0 0]; sc.audio_device_keyword='fake';
sc.save_dir_local=fullfile(testCase.TestData.folder,'Marmulator','local');
sc.save_dir_remote=fullfile(testCase.TestData.folder,'Marmulator','remote');
s=load(fullfile(base,'experiment_params','flexible_stimuli_2p.mat'));
s.inter_stim_interval=10; s.wait_after_reward=0;
profile=fullfile(testCase.TestData.folder,'profile.mat'); save(profile,'-struct','s');
f=figure('Visible','off'); h=uicontrol(f,'Style','text','String','0.000 mL');
cleanup=onCleanup(@()close(f)); %#ok<NASGU>
trigger=struct('ahand',1,'trial_pin',1,'stim_pin',2,'session_pin',3,'sampleCommand_pin',4);
[~,~,file]=engine([],10,'session_engine_test',profile,[],[0 0],1, ...
    2000,500,50,'2026-10-10_12-00-00',true,requireFix,200,10,h,.001,0,300,1, ...
    trigger,[],'test',sc,'automated simulation',[],[],[],false,true,c,reader);
output=load(file);
verifyEqual(testCase,MARMULATOR_TEST.sampleRate,96000);
if ~escape
    verifyEqual(testCase,MARMULATOR_TEST.audioFills,4);
    verifyEqual(testCase,sum(strcmp(MARMULATOR_TEST.commands,'2b1')),output.calib.n_completed);
    verifyEqual(testCase,sum(strcmp(MARMULATOR_TEST.commands,'2c1')),output.calib.n_completed);
    firstTrial=find(strcmp(MARMULATOR_TEST.commands,'2b1'),1);
    trialCommands=MARMULATOR_TEST.commands(firstTrial:end); % exclude the session barcode
    verifyEqual(testCase,sum(strcmp(trialCommands,'2e1')),output.calib.n_completed);
    verifyGreaterThanOrEqual(testCase,sum(strcmp(MARMULATOR_TEST.commands,'2e0')),output.calib.n_completed);
end
end
function writeFake(folder,name,lines)
fid=fopen(fullfile(folder,[name '.m']),'w');
fwrite(fid,strjoin(lines,newline)); fclose(fid);
end
