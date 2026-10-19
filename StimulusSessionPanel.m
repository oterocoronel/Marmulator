classdef StimulusSessionPanel < handle
    % Main stimulation controls for flexible 2p sessions; GUIDE owns hardware.
    properties
        panel
        enableCheck
        rootEdit
        rewardEdit
        sharedEdits
        surroundCheck
        surroundRadiusEdit
        surroundFadeEdit
        actionsTimeEdit
        setsTable
        status
        isiEdit
        estimateText
        repeatsEdit
        initiationCheck
        initiationTimeEdit
        config = []
    end
    properties (Access=private)
        runLockedControls = []
        legacyControls = []
        legacyEnable = {}
        legacyDisabled = false
    end
    methods
        function obj = StimulusSessionPanel(fig, blackCheck)
            children=get(fig,'Children');
            for k=1:numel(children), set(children(k),'Units','pixels'); end
            set(fig,'Units','pixels'); pos=get(fig,'Position'); oldWidth=pos(3);
            pos(1)=max(10,pos(1)-350); pos(3)=oldWidth+735;
            set(fig,'Position',pos,'Resize','on');
            obj.panel=uipanel(fig,'Title','Flexible 2p stimulation','Units','pixels', ...
                'Position',[oldWidth+5 10 720 pos(4)-20],'Tag','session_stimuli_panel');
            p=obj.panel;
            obj.enableCheck=uicontrol(p,'Style','checkbox','Units','normalized', ...
                'Position',[.02 .95 .96 .04],'String','Use flexible 2p settings', ...
                'Value',0,'Callback',@(~,~)obj.setEnabled());
            obj.rootEdit=uicontrol(p,'Style','edit','Units','normalized', ...
                'Position',[.02 .895 .71 .04],'HorizontalAlignment','left');
            folderButton=obj.button(p,'Folder...',[.74 .895 .12 .04],@(~,~)obj.browse());
            reloadButton=obj.button(p,'Reload',[.87 .895 .11 .04],@(~,~)obj.reload());
            keys=obj.sharedKeys();
            labels={'Time (s)','Stim width (deg)','Stim height (deg)', ...
                'Init box width (deg)','Init box height (deg)','X position (deg)', ...
                'Hold box width (deg)','Hold box height (deg)','Y position (deg)'};
            obj.sharedEdits=struct();
            for k=1:numel(keys)
                x=.02+.33*mod(k-1,3); y=.83-.06*floor((k-1)/3);
                obj.label(p,labels{k},[x y .22 .04]);
                obj.sharedEdits.(keys{k})=obj.edit(p,'',[x+.22 y .09 .04],@(~,~)obj.syncShared());
            end
            obj.initiationCheck=uicontrol(p,'Style','checkbox','Units','normalized', ...
                'Position',[.02 .645 .52 .045],'String','Require fixation before stimulus', ...
                'Callback',@(~,~)obj.syncRun());
            obj.label(p,'Fixation (s)',[.55 .645 .20 .04]);
            obj.initiationTimeEdit=obj.edit(p,'0.2',[.78 .645 .20 .04],@(~,~)obj.syncRun());
            obj.label(p,'Reward: time inside hold box (%)',[.02 .59 .39 .04]);
            obj.rewardEdit=obj.edit(p,'70',[.42 .59 .10 .04],@(~,~)obj.validateReward());
            obj.label(p,'Action video time (s)',[.55 .59 .31 .04]);
            obj.actionsTimeEdit=obj.edit(p,'4',[.88 .59 .10 .04], ...
                @(~,~)obj.validateTime(obj.actionsTimeEdit,'actions_duration_s'));
            obj.surroundCheck=blackCheck;
            set(blackCheck,'Parent',p,'Units','normalized','Position',[.02 .535 .31 .045], ...
                'String','Black circular surround','Callback',@(~,~)obj.syncSurround(), ...
                'TooltipString','Clear radius and fade width apply next trial. Enable applies at the next Run.');
            obj.label(p,'Clear radius (deg)',[.34 .535 .22 .04]);
            obj.surroundRadiusEdit=obj.edit(p,'7.5',[.57 .535 .1 .04],@(~,~)obj.syncSurround());
            obj.label(p,'Fade width (deg)',[.69 .535 .19 .04]);
            obj.surroundFadeEdit=obj.edit(p,'2.5',[.89 .535 .09 .04],@(~,~)obj.syncSurround());
            obj.label(p,'Repeats',[.02 .48 .12 .04]);
            obj.repeatsEdit=obj.edit(p,'1',[.14 .48 .10 .04],@(~,~)obj.syncRun());
            obj.label(p,'ITI (s)',[.28 .48 .12 .04]);
            obj.isiEdit=obj.edit(p,'0.5',[.40 .48 .12 .04],@(~,~)obj.validateISI());
            obj.label(p,'Monitor: initiation dashed, hold solid.',[.55 .48 .43 .04]);
            obj.label(p,'Checked sets: all matching files, once per randomized repeat.',[.02 .425 .96 .04]);
            obj.setsTable=uitable(p,'Units','normalized','Position',[.02 .19 .96 .235], ...
                'ColumnName',{'Use','Set','Mode','Files','Each (s)'}, ...
                'ColumnEditable',[true false true false false], ...
                'ColumnFormat',{'logical','char',{'AV','A','V','AV,A,V'},'numeric','char'}, ...
                'ColumnWidth',{40 230 90 65 170},'RowName',[], ...
                'CellEditCallback',@(~,e)obj.syncSets(e));
            obj.button(p,'Save settings...',[.02 .14 .22 .04],@(~,~)obj.saveSession());
            loadButton=obj.button(p,'Load settings...',[.26 .14 .22 .04],@(~,~)obj.loadSession());
            obj.estimateText=uicontrol(p,'Style','text','Units','normalized', ...
                'Position',[.02 .04 .96 .09],'HorizontalAlignment','left');
            obj.runLockedControls=[obj.enableCheck obj.rootEdit folderButton reloadButton loadButton];
            obj.status=uicontrol(p,'Style','text','Units','normalized', ...
                'Position',[.02 .005 .96 .032],'HorizontalAlignment','left');
            root=fullfile(getenv('HOME'),'Stimuli','stimuli_2p');
            set(obj.rootEdit,'String',root);
            if isfolder(root), obj.reload(); end
        end
        function bindLegacy(obj,handles)
            names={'repeats_edit','hold_time_edit','response_time_edit','trial_time_edit', ...
                'require_fix_check','fixation_edit','time_out_edit','n_rsvp_edit', ...
                'break_after_edit'};
            obj.legacyControls=gobjects(1,numel(names));
            for k=1:numel(names), obj.legacyControls(k)=handles.(names{k}); end
            obj.setEnabled();
        end
        function setEnabled(obj)
            active=logical(get(obj.enableCheck,'Value'));
            if active && ~obj.legacyDisabled && ~isempty(obj.legacyControls)
                obj.legacyEnable=get(obj.legacyControls,'Enable');
                set(obj.legacyControls,'Enable','off'); obj.legacyDisabled=true;
            elseif ~active && obj.legacyDisabled
                for k=1:numel(obj.legacyControls), set(obj.legacyControls(k),'Enable',obj.legacyEnable{k}); end
                obj.legacyDisabled=false;
            end
        end
        function setRunning(obj,running)
            % Keep the scheduled identities/root fixed while sizes and rewards can change.
            set(obj.runLockedControls,'Enable',obj.onOff(~running));
        end
        function browse(obj)
            root=uigetdir(get(obj.rootEdit,'String'),'Select stimulus root');
            if isequal(root,0), return; end
            set(obj.rootEdit,'String',root); obj.reload();
        end
        function reload(obj)
            try
                c=flexible_2p('catalog',get(obj.rootEdit,'String'));
                obj.config=c; obj.render();
            catch err, set(obj.status,'String',err.message); end
        end
        function render(obj)
            obj.config=flexible_2p('defaults',obj.config);
            keys=obj.sharedKeys();
            for k=1:numel(keys), set(obj.sharedEdits.(keys{k}),'String',num2str(obj.config.shared.(keys{k}))); end
            set(obj.rewardEdit,'String',num2str(100*obj.config.reward_fraction));
            set(obj.rootEdit,'String',obj.config.root);
            set(obj.actionsTimeEdit,'String',num2str(obj.config.actions_duration_s));
            set(obj.surroundCheck,'Value',obj.config.surround.enabled);
            set(obj.surroundRadiusEdit,'String',num2str(obj.config.surround.inner_radius_deg));
            set(obj.surroundFadeEdit,'String',num2str(obj.config.surround.fade_width_deg));
            set(obj.repeatsEdit,'String',num2str(obj.config.run.repeats));
            set(obj.isiEdit,'String',num2str(obj.config.run.inter_trial_interval_s));
            set(obj.initiationCheck,'Value',obj.config.run.require_fixation);
            set(obj.initiationTimeEdit,'String',num2str(obj.config.run.fixation_before_s));
            obj.validateReward(); obj.syncRun(false); obj.renderSets();
        end
        function renderSets(obj)
            rows=cell(numel(obj.config.groups),5);
            for k=1:size(rows,1)
                g=obj.config.groups(k); n=sum(strcmp({obj.config.items.set_name},g.name));
                rows(k,:)={logical(g.enabled),g.name,g.modality,n,''};
            end
            set(obj.setsTable,'Data',rows);
            set(obj.status,'String','Stimulus/reward/size edits apply next trial; run controls and surround enable apply next Run.');
            obj.updateEstimate();
        end
        function syncSets(obj,event)
            rows=get(obj.setsTable,'Data');
            if nargin>1 && event.Indices(2)==3
                r=event.Indices(1); modes=strsplit(rows{r,3},',');
                items=obj.config.items(strcmp({obj.config.items.set_name},rows{r,2}));
                if (any(ismember(modes,{'A','AV'})) && any(cellfun(@isempty,{items.audio_file}))) || ...
                        (any(ismember(modes,{'V','AV'})) && any(cellfun(@isempty,{items.visual_file})))
                    rows{r,3}=event.PreviousData; set(obj.setsTable,'Data',rows);
                    set(obj.status,'String','Choose a mode supported by the files in this folder.');
                end
            end
            for k=1:size(rows,1)
                obj.config.groups(k).enabled=logical(rows{k,1}); obj.config.groups(k).modality=rows{k,3};
            end
            if nargin>1, obj.updateEstimate(); end
        end
        function syncShared(obj,refresh)
            if nargin<2, refresh=true; end
            keys=obj.sharedKeys();
            for k=1:numel(keys)
                control=obj.sharedEdits.(keys{k}); v=str2double(get(control,'String'));
                valid=isfinite(v) && isreal(v);
                if valid && k==1, valid=v>0; end
                if valid && contains(keys{k},'offset'), valid=abs(v)<90;
                elseif valid && k>1, valid=v>0 && v<180; end
                if valid, obj.config.shared.(keys{k})=v;
                else, set(control,'String',num2str(obj.config.shared.(keys{k}))); set(obj.status,'String','Use positive time/sizes and offsets between -90 and 90 degrees.'); end
            end
            if refresh, obj.updateEstimate(); end
        end
        function validateReward(obj)
            obj.readNumber(obj.rewardEdit,'reward_fraction',0,100,100);
        end
        function syncSurround(obj)
            obj.config.surround.enabled=logical(get(obj.surroundCheck,'Value'));
            r=str2double(get(obj.surroundRadiusEdit,'String')); w=str2double(get(obj.surroundFadeEdit,'String'));
            if isfinite(r) && isfinite(w) && r>=0 && w>0 && r+w<90
                obj.config.surround.inner_radius_deg=r; obj.config.surround.fade_width_deg=w;
            else
                set(obj.surroundRadiusEdit,'String',num2str(obj.config.surround.inner_radius_deg));
                set(obj.surroundFadeEdit,'String',num2str(obj.config.surround.fade_width_deg));
                set(obj.status,'String','Clear radius >= 0; fade width > 0; their sum must be < 90 degrees.');
            end
        end
        function validateTime(obj,control,key,varargin)
            obj.readNumber(control,key,eps,Inf);
            if isempty(varargin) || varargin{1}, obj.updateEstimate(); end
        end
        function readNumber(obj,control,key,low,high,divisor)
            if nargin<6, divisor=1; end
            v=str2double(get(control,'String'));
            if isfinite(v) && v>=low && v<=high, obj.config.(key)=v/divisor;
            else, set(control,'String',num2str(divisor*obj.config.(key))); set(obj.status,'String','Invalid value; previous setting restored.'); end
        end
        function syncRun(obj,refresh)
            if nargin<2, refresh=true; end
            r=obj.config.run;
            controls={obj.repeatsEdit,obj.isiEdit,obj.initiationTimeEdit};
            keys={'repeats','inter_trial_interval_s','fixation_before_s'};
            for k=1:numel(keys)
                v=str2double(get(controls{k},'String'));
                valid=isfinite(v) && v>=0;
                if k==1, valid=valid && v>=1 && v==floor(v); end
                if k>=3, valid=valid && v>0; end
                if valid, r.(keys{k})=v;
                else, set(controls{k},'String',num2str(r.(keys{k}))); set(obj.status,'String','Invalid run setting; previous value restored.'); end
            end
            r.require_fixation=logical(get(obj.initiationCheck,'Value'));
            obj.config.run=r; obj.config.estimated_isi_s=r.inter_trial_interval_s;
            set(obj.initiationTimeEdit,'Enable',obj.onOff(r.require_fixation));
            if refresh, obj.updateEstimate(); end
        end
        function validateISI(obj), obj.syncRun(); end
        function updateEstimate(obj)
            if isempty(obj.config), return; end
            try
                repeats=str2double(get(obj.repeatsEdit,'String')); isi=str2double(get(obj.isiEdit,'String'));
                e=flexible_2p('estimate',obj.config,repeats,isi);
                rows=get(obj.setsTable,'Data');
                for k=1:size(rows,1)
                    d=[e.plan(strcmp({e.plan.set_name},rows{k,2})).duration_s]; rows{k,5}='-';
                    if ~isempty(d), rows{k,5}=sprintf('%.3g to %.3g',min(d),max(d)); end
                end
                set(obj.setsTable,'Data',rows);
                set(obj.estimateText,'String',sprintf(['%d presentations/pass x %d repeats = %d presentations\n' ...
                    'Stimuli: %.3f s; between-stimulus ITIs: %.3f s\n' ...
                    'Estimated total: %.3f s (%.2f min)\nPlus preparation, reward and trigger/fixation waits'], ...
                    e.presentations_per_pass,repeats,e.presentations,e.stimulus_duration_s, ...
                    e.isi_duration_s,e.total_duration_s,e.total_duration_s/60));
            catch err, set(obj.estimateText,'String',['Estimate unavailable: ' err.message]); end
        end
        function settings = snapshot(obj,refresh)
            if nargin<2, refresh=false; end
            assert(~isempty(obj.config),'Marmulator:MissingCatalog','Choose a stimulus root first.');
            assert(strcmp(get(obj.rootEdit,'String'),obj.config.root),'Marmulator:ReloadRoot', ...
                'Click Reload after typing a different stimulus root.');
            obj.syncSets(); obj.syncShared(false); obj.validateReward(); obj.syncSurround(); obj.syncRun(false);
            obj.validateTime(obj.actionsTimeEdit,'actions_duration_s',false);
            obj.config.enabled=logical(get(obj.enableCheck,'Value'));
            if refresh, obj.config=flexible_2p('discover',obj.config); obj.renderSets(); end
            settings=obj.config;
        end
        function trial = currentTrial(obj,item,modality)
            trial=flexible_2p('trial',obj.snapshot(),item,modality);
        end
        function rememberRun(obj,settings,experiment_file,wait_for_2p,file)
            if nargin<5, file=fullfile(fileparts(mfilename('fullpath')),'gui','flexible_2p_last_run.mat'); end
            settings=rmfield(settings,'items'); % Rediscover media when reopening.
            last=struct('settings',settings,'experiment_file',experiment_file,'wait_for_2p',logical(wait_for_2p));
            temporary=[file '.tmp.mat'];
            save(temporary,'-struct','last');
            movefile(temporary,file,'f');
        end
        function last = restoreLastRun(obj,file)
            if nargin<2, file=fullfile(fileparts(mfilename('fullpath')),'gui','flexible_2p_last_run.mat'); end
            last=[];
            if ~isfile(file), return; end
            try
                last=load(file);
                obj.config=flexible_2p('discover',last.settings); obj.render();
                set(obj.enableCheck,'Value',obj.config.enabled); obj.setEnabled();
                set(obj.status,'String','Restored settings from the last flexible 2p Run.');
            catch err
                last=[]; set(obj.status,'String',['Could not restore last Run: ' err.message]);
            end
        end
        function saveSession(obj)
            try
                settings=rmfield(obj.snapshot(),'items');
                [file,path]=uiputfile('*.json','Save 2p settings','session_stimuli.json');
                if isequal(file,0), return; end
                fid=fopen(fullfile(path,file),'w'); assert(fid>=0,'Cannot write settings.');
                closer=onCleanup(@()fclose(fid)); %#ok<NASGU>
                fwrite(fid,jsonencode(settings,'PrettyPrint',true),'char');
            catch err, set(obj.status,'String',err.message); end
        end
        function loadSession(obj)
            [file,path]=uigetfile('*.json','Load 2p settings');
            if isequal(file,0), return; end
            try
                c=jsondecode(fileread(fullfile(path,file)));
                assert(c.version==2,'Use version 2 session settings.');
                c=flexible_2p('discover',c); flexible_2p('plan',c,1,false);
                obj.config=c; obj.render(); set(obj.enableCheck,'Value',c.enabled); obj.setEnabled();
            catch err, set(obj.status,'String',err.message); end
        end
    end
    methods (Static, Access=private)
        function keys = sharedKeys()
            keys={'duration_s','stim_width_deg','stim_height_deg','initiation_width_deg', ...
                'initiation_height_deg','offset_x_deg','fixation_width_deg','fixation_height_deg','offset_y_deg'};
        end
        function value = onOff(flag)
            value='off'; if flag, value='on'; end
        end
        function label(parent,string,pos)
            uicontrol(parent,'Style','text','Units','normalized','Position',pos,'String',string,'HorizontalAlignment','left');
        end
        function control = edit(parent,string,pos,callback)
            control=uicontrol(parent,'Style','edit','Units','normalized','Position',pos,'String',string,'Callback',callback);
        end
        function control = button(parent,string,pos,callback)
            control=uicontrol(parent,'Style','pushbutton','Units','normalized','Position',pos,'String',string,'Callback',callback);
        end
    end
end
