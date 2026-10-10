function tests = test_stimulus_sessions
% Hardware-free tests for selection, conditions, timing policy and reward math.
tests = functiontests(localfunctions);
end
function testCatalogAndConditions(testCase)
c = load_stimulus_catalog(fullfile(getenv('HOME'),'Stimuli','stimuli_2p'));
p = session_plan(c,2);
verifyEqual(testCase,numel(p),24);
idx = find(strcmp({c.groups.name},'phee'));
c.groups(idx).modality = 'AV,A,V';
p = session_plan(c,1);
verifyEqual(testCase,numel(p),24);
a = p(strcmp({p.set_name},'phee'));
verifyEqual(testCase,sum(strcmp({a.modality},'AV')),6);
for item = a(strcmp({a.modality},'AV'))
    v = a(strcmp({a.id},item.id) & strcmp({a.modality},'V'));
    sound = a(strcmp({a.id},item.id) & strcmp({a.modality},'A'));
    verifyEqual(testCase,v.visual_file,item.visual_file);
    verifyEqual(testCase,sound.audio_file,item.audio_file);
    verifyEmpty(testCase,v.audio_file);
    verifyEmpty(testCase,sound.visual_file);
end
c.groups(idx).enabled = false;
p = session_plan(c,1);
verifyEqual(testCase,numel(p),6);
end
function testSharedGeometryAndChairTiming(testCase)
c = load_stimulus_catalog(fullfile(getenv('HOME'),'Stimuli','stimuli_2p'));
item = c.items(find(strcmp({c.items.set_name},'phee'),1));
c.shared.duration_s = .5;
c.shared.stim_width_deg = 17; c.shared.stim_height_deg = 13;
c.shared.fixation_width_deg = 5; c.shared.fixation_height_deg = 4;
c.shared.offset_x_deg = 2; c.shared.offset_y_deg = -1;
p = session_trial(c,item,'AV');
verifyEqual(testCase,p.duration_s,item.duration_s);
verifyEqual(testCase,p.media_start_s,0);
c.shared.duration_s = 3;
p = session_trial(c,item,'AV');
verifyEqual(testCase,p.duration_s,3);
c.chair_duration_mode = 'cap'; c.chair_max_duration_s = 1;
p = session_trial(c,item,'AV');
verifyEqual(testCase,p.duration_s,1);
verifyEqual(testCase,p.media_start_s,0); % Chair cropping removes only the end.
for k = 1:numel(c.groups)
    c.groups(k).enabled = true;
    i = find(strcmp({c.items.set_name},c.groups(k).name),1);
    modes = strsplit(c.groups(k).modality,',');
    p = session_trial(c,c.items(i),modes{1});
    verifyEqual(testCase,p.stim_size_deg,[17 13]);
    verifyEqual(testCase,p.fixation_size_deg,[5 4]);
    verifyEqual(testCase,p.offset_deg,[2 -1]);
    if strcmp(c.groups(k).timing,'shared'), verifyEqual(testCase,p.duration_s,3); end
end
end
function testActionsCropSymmetrically(testCase)
c = load_stimulus_catalog(fullfile(getenv('HOME'),'Stimuli','stimuli_2p'));
g = find(startsWith({c.groups.name},'arena/'),1); c.groups(g).enabled = true;
item = c.items(find(strcmp({c.items.set_name},c.groups(g).name),1));
c.actions_duration_s = 4;
p = session_trial(c,item,'V');
verifyEqual(testCase,p.duration_s,4);
verifyEqual(testCase,p.media_start_s,(item.duration_s-4)/2,'AbsTol',1e-9);
verifyEqual(testCase,item.duration_s-(p.media_start_s+p.duration_s),p.media_start_s,'AbsTol',1e-9);
c.actions_duration_s = item.duration_s+1;
p = session_trial(c,item,'V');
verifyEqual(testCase,p.media_start_s,0);
verifyEqual(testCase,p.duration_s,item.duration_s+1);
end
function testFolderContentsDefineSelection(testCase)
c = load_stimulus_catalog(fullfile(getenv('HOME'),'Stimuli','stimuli_2p'));
g = find(strcmp({c.groups.name},'bodies'));
source = c.items(find(strcmp({c.items.set_name},'bodies'),1)).visual_file;
root = tempname; mkdir(root); cleanup = onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
c.root = root; c.groups = c.groups(g); c.groups.folder = 'chosen';
c.groups.pattern = '*.png'; c.groups.enabled = true;
mkdir(fullfile(root,'chosen')); copyfile(source,fullfile(root,'chosen','one.png'));
c = rmfield(c,'items');
fid = fopen(fullfile(root,'stimulus_catalog.json'),'w'); fwrite(fid,jsonencode(c)); fclose(fid);
loaded = load_stimulus_catalog(root); verifyNumElements(testCase,loaded.items,1);
copyfile(source,fullfile(root,'chosen','two.png'));
loaded = load_stimulus_catalog(root); verifyNumElements(testCase,loaded.items,2);
delete(fullfile(root,'chosen','one.png'));
loaded = load_stimulus_catalog(root); verifyNumElements(testCase,loaded.items,1);
verifyEqual(testCase,loaded.items.label,'two');
end
function testSilentStimuliRejectAudio(testCase)
c = load_stimulus_catalog(fullfile(getenv('HOME'),'Stimuli','stimuli_2p'));
g = find(startsWith({c.groups.name},'arena/'),1);
c.groups(g).enabled = true; c.groups(g).modality = 'AV';
verifyError(testCase,@()session_plan(c,1),'Marmulator:MissingAudio');
end
function testTimeWeightedFixation(testCase)
verifyEqual(testCase,session_fixation_fraction([0 .01 .04],[1 0 1],.05),.4,'AbsTol',1e-12);
verifyEqual(testCase,session_fixation_fraction([0 .01],[1 NaN],.02),.5);
verifyEqual(testCase,session_fixation_fraction([0 .01],[0 0],.02),0);
verifyEqual(testCase,session_fixation_fraction([0 .01],[1 1],.02),1);
end
function testTonesAndCustomAudioDuration(testCase)
c = load_stimulus_catalog(fullfile(getenv('HOME'),'Stimuli','stimuli_2p'));
g = find(strcmp({c.groups.name},'tones'));
c.groups(g).enabled = true;
items = c.items(strcmp({c.items.set_name},'tones'));
verifyEqual(testCase,numel(items),14);
hz = sort([items.tone_hz]);
verifyEqual(testCase,hz(2:end),440*2.^((0:12)/2),'AbsTol',1e-9);
c.shared.duration_s = .25;
t = session_trial(c,items(1),'A');
a = session_audio_samples(t,96000);
verifySize(testCase,a,[24000 2]);
verifyEqual(testCase,a([1 end],:),zeros(2,2),'AbsTol',1e-12);
c.shared.duration_s = 2;
t = session_trial(c,items(end),'A');
a = session_audio_samples(t,96000);
verifySize(testCase,a,[192000 2]);
end
function testPanel(testCase)
f = figure('Visible','off','Position',[0 0 790 790]);
cleanup = onCleanup(@()close(f)); %#ok<NASGU>
b = uicontrol(f,'Style','checkbox');
p = StimulusSessionPanel(f,b);
verifyEqual(testCase,numel(p.config.items),639);
set(p.enableCheck,'Value',1);
c = p.snapshot();
verifyTrue(testCase,c.enabled);
verifyEqual(testCase,get(b,'Parent'),p.panel);
verifyFalse(testCase,isprop(p,'filesTable'));
row = get(p.sharedTable,'Data'); row{1,1} = .8; row{1,6} = 3;
set(p.sharedTable,'Data',row);
c = p.snapshot(true);
verifyEqual(testCase,c.shared.duration_s,.8);
verifyEqual(testCase,c.shared.offset_x_deg,3);
end

function testGeneratedWavFrequencies(testCase)
c = load_stimulus_catalog(fullfile(getenv('HOME'),'Stimuli','stimuli_2p'));
items = c.items(strcmp({c.items.set_name},'tones'));
for item = items(:)'
    [y,fs] = audioread(item.audio_file);
    verifyEqual(testCase,fs,96000);
    verifySize(testCase,y,[144000 1]);
    verifyLessThan(testCase,max(abs(y)),1);
    verifyGreaterThan(testCase,sqrt(mean(y.^2)),.095);
    verifyLessThan(testCase,sqrt(mean(y.^2)),.105);
    if item.tone_hz>0
        spectrum=abs(fft(y)); [~,peak]=max(spectrum(1:floor(numel(y)/2)));
        verifyEqual(testCase,(peak-1)*fs/numel(y),item.tone_hz,'AbsTol',1);
    end
end
end
