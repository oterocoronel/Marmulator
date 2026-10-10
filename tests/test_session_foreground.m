function tests = test_session_foreground
% Exercise the real loader and draw geometry without displays or sound.
tests = functiontests(localfunctions);
end
function setupOnce(testCase)
folder = tempname; mkdir(folder);
testCase.TestData.folder = folder;
testCase.TestData.oldDir = pwd;
lines = [
"function varargout=Screen(command,varargin)"
"global MARMULATOR_CROP_TEST; s=MARMULATOR_CROP_TEST; out={};"
"switch lower(command)"
"case 'rect', out={[0 0 1280 800]};"
"case 'openmovie'"
"s.handle=s.handle+1; s.frameIndex=1; frame=s.frames{1};"
"out={s.handle,numel(s.frames)/10,10,size(frame,2),size(frame,1)};"
"case 'setmovietimeindex'"
"s.seeks(end+1)=varargin{2}; s.frameIndex=1+round(varargin{2}*10);"
"case 'getmovieimage'"
"if numel(varargin)>=4, s.frameIndex=1+round(varargin{4}*10); end"
"if s.frameIndex>numel(s.frames), out={-1,-1};"
"else"
"s.handle=s.handle+1; s.textures{s.handle}=s.frames{s.frameIndex};"
"out={s.handle,(s.frameIndex-1)/10}; s.frameIndex=s.frameIndex+1;"
"end"
"case 'maketexture'"
"s.handle=s.handle+1; s.textures{s.handle}=varargin{2}; out={s.handle};"
"case 'openoffscreenwindow'"
"s.handle=s.handle+1; r=varargin{3}; s.textures{s.handle}=zeros(r(4),r(3),4,'uint8'); out={s.handle};"
"case 'getimage', s.readbacks=s.readbacks+1; out={s.textures{varargin{1}}};"
"case 'drawtexture'"
"s.draws{end+1}=struct('window',varargin{1},'texture',varargin{2},'source',varargin{3},'dest',varargin{4});"
"case 'close', s.closed(end+1)=varargin{1};"
"end"
"MARMULATOR_CROP_TEST=s; varargout=out(1:nargout);"
"end"];
fid = fopen(fullfile(folder,'Screen.m'),'w');
fwrite(fid,strjoin(lines,newline)); fclose(fid);
addpath(folder,'-begin'); cd(folder);
end
function setup(~)
global MARMULATOR_CROP_TEST
MARMULATOR_CROP_TEST = struct('handle',100,'textures',{{}},'frames',{{}}, ...
    'frameIndex',1,'readbacks',0,'draws',{{}},'closed',[],'seeks',[]);
end
function teardownOnce(testCase)
cd(testCase.TestData.oldDir); rmpath(testCase.TestData.folder);
rmdir(testCase.TestData.folder,'s');
clear global MARMULATOR_CROP_TEST
end
function testMinimalBoundsKeepFaintEdgesAndInternalGaps(testCase)
alpha = zeros(20,30,'uint8');
alpha(4,7) = 1; alpha(18,27) = 255;
verifyEqual(testCase,session_foreground_rect(alpha),[6 3 27 18]);
verifyEqual(testCase,session_foreground_rect(uint8(255)),[0 0 1 1]);
verifyEmpty(testCase,session_foreground_rect(zeros(20,30,'uint8')));
end
function testOffCenterImageFitsForegroundAtFixation(testCase)
alpha = zeros(1000,1000,'uint8'); alpha(301:900,201:900) = 255;
t = imageTrial(testCase,alpha);
p = SessionStimulusPlayer(1,[],96000); cleanup = onCleanup(@()delete(p)); %#ok<NASGU>
p.prepare(t);
verifyEqual(testCase,p.sourceRect,[200 300 900 900]);
verifyEqual(testCase,p.visualSize,[700 600]);
bounds = [100 200 800 900]; % A 700-by-700 requested pixel box.
rect = p.draw(1,[],bounds,1);
verifyEqual(testCase,rect,[100 250 800 850],'AbsTol',1e-10);
global MARMULATOR_CROP_TEST
draw = MARMULATOR_CROP_TEST.draws{end};
verifyEqual(testCase,draw.source,[200 300 900 900]);
verifyEqual(testCase,(rect(1:2)+rect(3:4))/2,[450 550]);
end
function testPaddingDoesNotChangeDisplayedSize(testCase)
p = SessionStimulusPlayer(1,[],96000); cleanup = onCleanup(@()delete(p)); %#ok<NASGU>
alpha = zeros(100,120,'uint8'); alpha(21:80,31:100) = 255;
p.prepare(imageTrial(testCase,alpha)); first = p.draw(1,[],[0 0 700 700],1);
alpha = zeros(300,500,'uint8'); alpha(201:260,401:470) = 255;
p.prepare(imageTrial(testCase,alpha)); second = p.draw(1,[],[0 0 700 700],1);
verifyEqual(testCase,second,first);
end
function testPreviewUsesSameCrop(testCase)
alpha = zeros(100,120,'uint8'); alpha(21:80,31:100) = 255;
p = SessionStimulusPlayer(1,[],96000); cleanup = onCleanup(@()delete(p)); %#ok<NASGU>
p.prepare(imageTrial(testCase,alpha)); rect = p.draw(1,2,[100 200 800 900],.5);
global MARMULATOR_CROP_TEST
draws = MARMULATOR_CROP_TEST.draws;
verifyEqual(testCase,draws{1}.source,[30 20 100 80]);
verifyEqual(testCase,draws{2}.source,draws{1}.source);
verifyEqual(testCase,draws{3}.window,2);
% The copied RGBA pixels land 1:1 in their integer preview footprint.
verifyEqual(testCase,draws{3}.dest,[floor(rect(1:2)*.5) ceil(rect(3:4)*.5)]);
verifyEqual(testCase,draws{2}.dest,rect*.5-[draws{3}.dest(1:2) draws{3}.dest(1:2)]);
end
function testOpaqueAndBlankImagesStayFinite(testCase)
p = SessionStimulusPlayer(1,[],96000); cleanup = onCleanup(@()delete(p)); %#ok<NASGU>
for value = [0 255]
    p.prepare(imageTrial(testCase,repmat(uint8(value),20,30)));
    verifyEqual(testCase,p.sourceRect,[0 0 30 20]);
    verifyEqual(testCase,p.draw(1,[],[0 0 300 300],1),[0 50 300 250]);
end
% Black RGB pixels do not indicate transparency.
t = imageTrial(testCase,[]); p.prepare(t);
verifyEqual(testCase,p.sourceRect,[0 0 30 20]);
end
function testGrayscaleAlpha(testCase)
alpha = zeros(20,30,'uint8'); alpha(4:18,7:27) = 255;
t = imageTrial(testCase,alpha,true);
p = SessionStimulusPlayer(1,[],96000); cleanup = onCleanup(@()delete(p)); %#ok<NASGU>
p.prepare(t);
verifyEqual(testCase,p.visualSize,[21 15]);
global MARMULATOR_CROP_TEST
verifySize(testCase,MARMULATOR_CROP_TEST.textures{p.texture},[20 30 4]);
end
function testMovieCropCoversLaterFramesAndIsFixed(testCase)
global MARMULATOR_CROP_TEST
a = zeros(100,120,4,'uint8'); a(21:60,31:70,4) = 255;
b = zeros(100,120,4,'uint8'); b(41:80,61:100,4) = 255;
MARMULATOR_CROP_TEST.frames = {a,b};
p = SessionStimulusPlayer(1,[],96000); cleanup = onCleanup(@()delete(p)); %#ok<NASGU>
t = movieTrial(testCase); p.prepare(t);
verifyEqual(testCase,p.sourceRect,[30 20 100 80]);
verifyEqual(testCase,p.visualSize,[70 60]);
verifyEqual(testCase,p.normalizationSize,[40 40]);
verifyEqual(testCase,p.moviePTS,0); % Scanning is not logged as presentation.
p.start(0); first = p.draw(1,[],[0 0 700 700],1);
second = p.draw(1,[],[0 0 700 700],1);
verifyEqual(testCase,second,first);
verifyEqual(testCase,p.sourceRect,[30 20 100 80]);
verifyEqual(testCase,MARMULATOR_CROP_TEST.draws{end}.source,p.sourceRect);
% EOF keeps the same crop and final frame.
lastTexture = p.texture;
verifyEqual(testCase,p.draw(1,[],[0 0 700 700],1),second);
verifyEqual(testCase,p.texture,lastTexture);
end
function testMovieSeekAndCropCache(testCase)
global MARMULATOR_CROP_TEST
a = zeros(10,20,4,'uint8'); a(2:6,3:9,4) = 255;
b = zeros(10,20,4,'uint8'); b(4:9,6:15,4) = 255;
MARMULATOR_CROP_TEST.frames = {a,b};
p = SessionStimulusPlayer(1,[],96000); cleanup = onCleanup(@()delete(p)); %#ok<NASGU>
t = movieTrial(testCase); t.media_start_s = .1; p.prepare(t);
verifyEqual(testCase,p.moviePTS,.1);
verifyEqual(testCase,p.sourceRect,[5 3 15 9]);
verifyEqual(testCase,p.normalizationSize,[10 6]);
readbacks = MARMULATOR_CROP_TEST.readbacks;
verifyEqual(testCase,readbacks,2);
p.prepare(t);
verifyEqual(testCase,MARMULATOR_CROP_TEST.readbacks,readbacks);
verifyEqual(testCase,p.moviePTS,.1);
% Changing the presented interval recalculates geometry using cached bounds.
t.media_start_s = 0; t.duration_s = .1; p.prepare(t);
verifyEqual(testCase,p.sourceRect,[2 1 9 6]);
verifyEqual(testCase,p.normalizationSize,[7 5]);
verifyEqual(testCase,MARMULATOR_CROP_TEST.readbacks,readbacks);
% A replaced file must be rescanned even when its path is unchanged.
fid = fopen(t.visual_file,'a'); fwrite(fid,'changed'); fclose(fid);
p.prepare(t);
verifyEqual(testCase,MARMULATOR_CROP_TEST.readbacks,2*readbacks);
end
function testMovieMeanSizeSetsOneScaleAcrossFrames(testCase)
global MARMULATOR_CROP_TEST
small = zeros(30,40,4,'uint8'); small(11:18,16:23,4) = 255;
large = zeros(30,40,4,'uint8'); large(9:20,14:25,4) = 255;
MARMULATOR_CROP_TEST.frames = {small,large};
p = SessionStimulusPlayer(1,[],96000); cleanup = onCleanup(@()delete(p)); %#ok<NASGU>
p.prepare(movieTrial(testCase));
verifyEqual(testCase,p.normalizationSize,[10 10],'AbsTol',1e-12);
rect = p.draw(1,[],[100 200 200 300],1);
scale = (rect(3:4)-rect(1:2))./p.visualSize;
verifyEqual(testCase,scale,[10 10],'AbsTol',1e-12);
verifyEqual(testCase,[8;12]*scale,[80 80;120 120],'AbsTol',1e-12);
verifyEqual(testCase,rect,[90 190 210 310],'AbsTol',1e-12);
end
function testMovieMeanWeightsDisplayedIntervalAndHeldFinalFrame(testCase)
rects = [0 0 8 8; 0 0 12 12; 0 0 100 100];
[rect,meanSize] = session_movie_geometry(rects,[0 .1 .2],0,.2,[0 0 100 100]);
verifyEqual(testCase,rect,[0 0 12 12]);
verifyEqual(testCase,meanSize,[10 10],'AbsTol',1e-12);
[~,meanSize] = session_movie_geometry(rects(1:2,:),[0 .1],0,.4,[0 0 100 100]);
verifyEqual(testCase,meanSize,[11 11],'AbsTol',1e-12);
% Unequal frame times count according to their visibility, as on the display.
[~,meanSize] = session_movie_geometry(rects(1:2,:),[0 .3],0,.4,[0 0 100 100]);
verifyEqual(testCase,meanSize,[9 9],'AbsTol',1e-12);
end
function testMovieTransparentFramesAndOpaqueFirstFrame(testCase)
global MARMULATOR_CROP_TEST
blank = zeros(10,20,4,'uint8');
visible = blank; visible(4:8,6:12,4) = 255;
for frames = {{blank,visible,blank},{blank,blank},{uint8(255*ones(10,20,4)),visible}}
    MARMULATOR_CROP_TEST.frames = frames{1};
    p = SessionStimulusPlayer(1,[],96000);
    cleanup = onCleanup(@()delete(p));
    p.prepare(movieTrial(testCase));
    if isequal(frames{1},{blank,visible,blank})
        verifyEqual(testCase,p.sourceRect,[5 3 12 8]);
    else
        verifyEqual(testCase,p.sourceRect,[0 0 20 10]);
    end
    clear cleanup
end
end
function testOpaqueMovieDoesNotReadBackFrames(testCase)
global MARMULATOR_CROP_TEST
MARMULATOR_CROP_TEST.frames = {uint8(255*ones(10,20,4))};
p = SessionStimulusPlayer(1,[],96000); cleanup = onCleanup(@()delete(p)); %#ok<NASGU>
t = movieTrial(testCase); t.has_alpha = false; p.prepare(t);
verifyEqual(testCase,p.visualSize,[20 10]);
verifyEqual(testCase,p.sourceRect,[0 0 20 10]);
verifyEqual(testCase,MARMULATOR_CROP_TEST.readbacks,0);
end
function testDiscardedMovieAlphaStillFails(testCase)
global MARMULATOR_CROP_TEST
MARMULATOR_CROP_TEST.frames = {uint8(255*ones(10,20,4))};
p = SessionStimulusPlayer(1,[],96000); cleanup = onCleanup(@()delete(p)); %#ok<NASGU>
verifyError(testCase,@()p.prepare(movieTrial(testCase)),'Marmulator:LostMovieAlpha');
end
function t = imageTrial(testCase,alpha,grayscale)
if nargin<3, grayscale = false; end
t = baseTrial(); t.kind = 'image';
t.visual_file = [tempname(testCase.TestData.folder) '.png'];
if isempty(alpha)
    rgb = zeros(20,30,3,'uint8'); rgb(8:12,10:15,:) = 100;
    imwrite(rgb,t.visual_file);
else
    channels = 3; if grayscale, channels = 1; end
    rgb = repmat(uint8(100),size(alpha,1),size(alpha,2),channels);
    imwrite(rgb,t.visual_file,'Alpha',alpha);
end
end
function t = movieTrial(testCase)
t = baseTrial(); t.kind = 'movie';
t.visual_file = [tempname(testCase.TestData.folder) '.mkv'];
fid = fopen(t.visual_file,'w'); fwrite(fid,'fake movie'); fclose(fid);
end
function t = baseTrial()
t = struct('kind','','visual_file','','audio_file','','has_alpha',true, ...
    'media_start_s',0,'duration_s',.2,'show_fixation_marker',false,'background','gray');
end
