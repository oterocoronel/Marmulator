classdef StimulusSessionPanel < handle
    % Shared controls and folder selection; changes apply between trials.
    properties
        panel
        enableCheck
        rootEdit
        rewardEdit
        backgroundPopup
        sharedTable
        chairModePopup
        chairMaxEdit
        actionsTimeEdit
        setsTable
        status
        isiEdit
        estimateText
        repeatsEdit = []
        config = []
    end
    methods
        function obj = StimulusSessionPanel(fig, blackCheck, repeatsEdit)
            if nargin>2, obj.repeatsEdit = repeatsEdit; end
            children = get(fig,'Children');
            for k = 1:numel(children), set(children(k),'Units','pixels'); end
            set(fig,'Units','pixels'); pos = get(fig,'Position'); oldWidth = pos(3);
            pos(1) = max(10,pos(1)-350); pos(3) = oldWidth+735;
            set(fig,'Position',pos,'Resize','on');
            obj.panel = uipanel(fig,'Title','Session stimuli','Units','pixels', ...
                'Position',[oldWidth+5 10 720 pos(4)-20],'Tag','session_stimuli_panel');
            p = obj.panel;
            obj.enableCheck = uicontrol(p,'Style','checkbox','Units','normalized', ...
                'Position',[.02 .945 .6 .035],'String','Use fixed-duration mixed stimuli','Value',0);
            uicontrol(p,'Style','text','Units','normalized','Position',[.63 .945 .14 .03], ...
                'String','Background','HorizontalAlignment','left');
            obj.backgroundPopup = uicontrol(p,'Style','popupmenu','Units','normalized', ...
                'Position',[.77 .945 .21 .035],'String',{'gray','black','white'},'Value',1);
            set(blackCheck,'Parent',p,'Units','normalized','Position',[.02 .905 .75 .035]);
            obj.rootEdit = uicontrol(p,'Style','edit','Units','normalized', ...
                'Position',[.02 .855 .71 .04],'HorizontalAlignment','left');
            uicontrol(p,'Style','pushbutton','Units','normalized','Position',[.74 .855 .12 .04], ...
                'String','Folder...','Callback',@(~,~)obj.browse());
            uicontrol(p,'Style','pushbutton','Units','normalized','Position',[.87 .855 .11 .04], ...
                'String','Reload','Callback',@(~,~)obj.reload());
            uicontrol(p,'Style','text','Units','normalized','Position',[.02 .805 .39 .035], ...
                'String','Reward: time inside fixation box (%)','HorizontalAlignment','left');
            obj.rewardEdit = uicontrol(p,'Style','edit','Units','normalized', ...
                'Position',[.42 .81 .09 .035],'String','70','Callback',@(~,~)obj.validateReward());
            uicontrol(p,'Style','pushbutton','Units','normalized','Position',[.63 .81 .17 .035], ...
                'String','Save session...','Callback',@(~,~)obj.saveSession());
            uicontrol(p,'Style','pushbutton','Units','normalized','Position',[.81 .81 .17 .035], ...
                'String','Load session...','Callback',@(~,~)obj.loadSession());
            shared = uipanel(p,'Title','Shared by all stimuli: time in seconds; sizes and position in degrees', ...
                'Units','normalized','Position',[.02 .655 .96 .14]);
            obj.sharedTable = uitable(shared,'Units','normalized','Position',[.01 .12 .98 .78], ...
                'ColumnName',{'Time (s)','Stim W','Stim H','Fix W','Fix H','X','Y'}, ...
                'ColumnEditable',true(1,7),'ColumnFormat',repmat({'numeric'},1,7), ...
                'ColumnWidth',{90 90 90 90 90 90 90},'RowName',[], ...
                'CellEditCallback',@(~,e)obj.syncShared(e));
            uicontrol(p,'Style','text','Units','normalized','Position',[.02 .6 .14 .035], ...
                'String','Chair timing','HorizontalAlignment','left');
            obj.chairModePopup = uicontrol(p,'Style','popupmenu','Units','normalized', ...
                'Position',[.16 .6 .57 .04], ...
                'String',{'Longer of shared time and full clip/WAV','Same rule, capped at chair maximum'}, ...
                'Value',1,'Callback',@(~,~)obj.syncChair());
            uicontrol(p,'Style','text','Units','normalized','Position',[.75 .6 .12 .035], ...
                'String','Maximum (s)','HorizontalAlignment','left');
            obj.chairMaxEdit = uicontrol(p,'Style','edit','Units','normalized', ...
                'Position',[.88 .6 .1 .04],'String','2', ...
                'Callback',@(~,~)obj.validateTime(obj.chairMaxEdit,'chair_max_duration_s'));
            uicontrol(p,'Style','text','Units','normalized','Position',[.02 .545 .33 .035], ...
                'String','Action / arena duration (s)','HorizontalAlignment','left');
            obj.actionsTimeEdit = uicontrol(p,'Style','edit','Units','normalized', ...
                'Position',[.35 .545 .1 .04],'String','4', ...
                'Callback',@(~,~)obj.validateTime(obj.actionsTimeEdit,'actions_duration_s'));
            uicontrol(p,'Style','text','Units','normalized','Position',[.48 .54 .5 .045], ...
                'String','Shorter actions: crop equally from start and end.', ...
                'HorizontalAlignment','left');
            uicontrol(p,'Style','text','Units','normalized','Position',[.02 .475 .96 .055], ...
                'String',{'All matching files in checked folders are used. A-only keeps a fixation marker.', ...
                'Folder contents refresh at Run. Repeats = passes through the selected folders.'}, ...
                'HorizontalAlignment','left');
            obj.setsTable = uitable(p,'Units','normalized','Position',[.02 .215 .96 .25], ...
                'ColumnName',{'Use','Set','Mode','Files','Folder','Timing','Each (s)'}, ...
                'ColumnEditable',[true false true false false false false], ...
                'ColumnFormat',{'logical','char',{'AV','A','V','AV,A,V'},'numeric','char','char','char'}, ...
                'ColumnWidth',{35 110 65 45 205 75 100},'RowName',[], ...
                'CellEditCallback',@(~,e)obj.syncSets(e));
            uicontrol(p,'Style','text','Units','normalized','Position',[.02 .17 .25 .035], ...
                'String','Assumed ISI (s), estimate only','HorizontalAlignment','left');
            obj.isiEdit = uicontrol(p,'Style','edit','Units','normalized', ...
                'Position',[.28 .17 .1 .035],'String','0.5', ...
                'TooltipString','Whole gap between stimuli, including waiting for center fixation and reward delays.', ...
                'Callback',@(~,~)obj.validateISI());
            uicontrol(p,'Style','text','Units','normalized','Position',[.4 .165 .58 .045], ...
                'String','Includes gaps between stimuli; excludes initial wait and pauses.', ...
                'HorizontalAlignment','left');
            obj.estimateText = uicontrol(p,'Style','text','Units','normalized', ...
                'Position',[.02 .045 .96 .115],'HorizontalAlignment','left');
            obj.status = uicontrol(p,'Style','text','Units','normalized', ...
                'Position',[.02 .005 .96 .035],'HorizontalAlignment','left');
            root = fullfile(getenv('HOME'),'Stimuli','stimuli_2p');
            set(obj.rootEdit,'String',root);
            if isfile(fullfile(root,'stimulus_catalog.json')), obj.reload(); end
        end
        function browse(obj)
            root = uigetdir(get(obj.rootEdit,'String'),'Select prepared stimulus root');
            if isequal(root,0), return; end
            set(obj.rootEdit,'String',root); obj.reload();
        end
        function reload(obj)
            try
                obj.config = load_stimulus_catalog(get(obj.rootEdit,'String'));
                obj.render();
            catch err, set(obj.status,'String',err.message); end
        end
        function render(obj)
            keys = obj.sharedKeys();
            row = cell(1,numel(keys));
            for k = 1:numel(keys), row{k} = obj.config.shared.(keys{k}); end
            set(obj.sharedTable,'Data',row);
            set(obj.rewardEdit,'String',num2str(100*obj.config.reward_fraction));
            colors = get(obj.backgroundPopup,'String');
            set(obj.backgroundPopup,'Value',find(strcmp(colors,obj.config.background),1));
            set(obj.rootEdit,'String',obj.config.root);
            set(obj.chairModePopup,'Value',1+strcmp(obj.config.chair_duration_mode,'cap'));
            set(obj.chairMaxEdit,'String',num2str(obj.config.chair_max_duration_s));
            set(obj.actionsTimeEdit,'String',num2str(obj.config.actions_duration_s));
            if ~isfield(obj.config,'estimated_isi_s'), obj.config.estimated_isi_s=.5; end
            set(obj.isiEdit,'String',num2str(obj.config.estimated_isi_s));
            obj.syncChair(false); obj.renderSets();
        end
        function renderSets(obj)
            rows = cell(numel(obj.config.groups),7);
            for k = 1:size(rows,1)
                g = obj.config.groups(k);
                n = sum(strcmp({obj.config.items.set_name},g.name));
                rows(k,:) = {logical(g.enabled),g.name,g.modality,n,g.folder,g.timing,''};
            end
            set(obj.setsTable,'Data',rows);
            set(obj.status,'String',sprintf('%d folders, %d files. Settings apply next trial; folder additions next Run.', ...
                numel(obj.config.groups),numel(obj.config.items)));
            obj.updateEstimate();
        end
        function syncSets(obj,event)
            rows = get(obj.setsTable,'Data');
            if nargin>1 && event.Indices(2)==3
                r = event.Indices(1); modes = strsplit(rows{r,3},',');
                items = obj.config.items(strcmp({obj.config.items.set_name},rows{r,2}));
                if (any(ismember(modes,{'A','AV'})) && any(cellfun(@isempty,{items.audio_file}))) || ...
                        (any(ismember(modes,{'V','AV'})) && any(cellfun(@isempty,{items.visual_file})))
                    rows{r,3} = event.PreviousData; set(obj.setsTable,'Data',rows);
                    set(obj.status,'String','Choose a mode supported by the files in this folder.');
                end
            end
            for k = 1:size(rows,1)
                obj.config.groups(k).enabled = logical(rows{k,1});
                obj.config.groups(k).modality = rows{k,3};
            end
            if nargin>1, obj.updateEstimate(); end
        end
        function syncShared(obj,varargin)
            row = get(obj.sharedTable,'Data'); keys = obj.sharedKeys();
            corrected = false;
            for k = 1:numel(keys)
                v = row{1,k}; valid = isnumeric(v) && isscalar(v) && isfinite(v);
                if valid && k==1, valid = v>0; end
                if valid && k>=2 && k<=5, valid = v>0 && v<180; end
                if valid && k>=6, valid = abs(v)<90; end
                if valid
                    obj.config.shared.(keys{k}) = v;
                else
                    row{1,k} = obj.config.shared.(keys{k});
                    corrected = true;
                    set(obj.status,'String','Time must be positive; sizes 0–180 degrees; offsets -90–90 degrees.');
                end
            end
            if corrected, set(obj.sharedTable,'Data',row); end
            if ~isempty(varargin), obj.updateEstimate(); end
        end
        function syncChair(obj,refresh)
            if nargin<2, refresh=true; end
            modes = {'full','cap'};
            obj.config.chair_duration_mode = modes{get(obj.chairModePopup,'Value')};
            enabled = 'off'; if strcmp(obj.config.chair_duration_mode,'cap'), enabled='on'; end
            set(obj.chairMaxEdit,'Enable',enabled);
            if refresh, obj.updateEstimate(); end
        end
        function validateTime(obj,control,key,refresh)
            if nargin<4, refresh=true; end
            value = str2double(get(control,'String'));
            if isfinite(value) && value>0
                obj.config.(key) = value;
            else
                set(control,'String',num2str(obj.config.(key)));
                set(obj.status,'String','Duration must be a positive number of seconds.');
            end
            if refresh, obj.updateEstimate(); end
        end
        function validateISI(obj)
            value = str2double(get(obj.isiEdit,'String'));
            if isfinite(value) && value>=0
                obj.config.estimated_isi_s = value;
            else
                value = .5;
                if isfield(obj.config,'estimated_isi_s'), value=obj.config.estimated_isi_s; end
                set(obj.isiEdit,'String',num2str(value));
                set(obj.status,'String','Assumed ISI must be a nonnegative number of seconds.');
            end
            obj.updateEstimate();
        end
        function updateEstimate(obj)
            if isempty(obj.config), return; end
            try
                repeats = 1;
                if ~isempty(obj.repeatsEdit), repeats=str2double(get(obj.repeatsEdit,'String')); end
                isi = str2double(get(obj.isiEdit,'String'));
                e = session_duration_estimate(obj.config,repeats,isi);
                rows = get(obj.setsTable,'Data');
                for k = 1:size(rows,1)
                    durations = [e.plan(strcmp({e.plan.set_name},rows{k,2})).duration_s];
                    rows{k,7} = '-';
                    if ~isempty(durations)
                        rows{k,7} = sprintf('%.3g to %.3g',min(durations),max(durations));
                        if min(durations)==max(durations), rows{k,7}=sprintf('%.3g',durations(1)); end
                    end
                end
                set(obj.setsTable,'Data',rows);
                set(obj.estimateText,'String',sprintf([ ...
                    '%d presentations/pass x %d repeats = %d presentations\n' ...
                    'Each stimulus: %.3g to %.3g s; stimulus-only total: %.3f s\n' ...
                    '%d ISIs x %.3g s = %.3f s\nEstimated total: %.3f s (%.2f min)'], ...
                    e.presentations_per_pass,repeats,e.presentations,e.min_duration_s,e.max_duration_s, ...
                    e.stimulus_duration_s,e.intervals,isi,e.isi_duration_s, ...
                    e.total_duration_s,e.total_duration_s/60));
            catch err
                rows = get(obj.setsTable,'Data');
                if ~isempty(rows), rows(:,7)={'-'}; set(obj.setsTable,'Data',rows); end
                set(obj.estimateText,'String',['Estimate unavailable: ' err.message]);
            end
        end
        function validateReward(obj)
            percent = str2double(get(obj.rewardEdit,'String'));
            if isfinite(percent) && percent>=0 && percent<=100
                obj.config.reward_fraction = percent/100;
            else
                set(obj.rewardEdit,'String',num2str(obj.config.reward_fraction*100));
                set(obj.status,'String','Fixation percentage must be between 0 and 100.');
            end
        end
        function config = snapshot(obj,refresh)
            if nargin<2, refresh=false; end
            assert(~isempty(obj.config),'Marmulator:MissingCatalog','Load a stimulus catalog first.');
            obj.syncSets(); obj.syncShared(); obj.syncChair(false); obj.validateReward();
            obj.validateTime(obj.chairMaxEdit,'chair_max_duration_s',false);
            obj.validateTime(obj.actionsTimeEdit,'actions_duration_s',false);
            obj.config.enabled = logical(get(obj.enableCheck,'Value'));
            colors = get(obj.backgroundPopup,'String');
            obj.config.background = colors{get(obj.backgroundPopup,'Value')};
            if refresh, obj.config = discover_session_stimuli(obj.config); obj.renderSets(); end
            config = obj.config;
        end
        function trial = currentTrial(obj,item,modality)
            trial = session_trial(obj.snapshot(),item,modality);
        end
        function saveSession(obj)
            try
                config = rmfield(obj.snapshot(),'items'); % Folder contents are discovered at Run.
                [file,path] = uiputfile('*.json','Save session settings','session_stimuli.json');
                if isequal(file,0), return; end
                fid = fopen(fullfile(path,file),'w'); assert(fid>=0,'Cannot write session settings.');
                closer = onCleanup(@()fclose(fid)); %#ok<NASGU>
                fwrite(fid,jsonencode(config,'PrettyPrint',true),'char');
            catch err, set(obj.status,'String',err.message); end
        end
        function loadSession(obj)
            [file,path] = uigetfile('*.json','Load session settings');
            if isequal(file,0), return; end
            try
                config = jsondecode(fileread(fullfile(path,file)));
                assert(config.version==2,'Use a session saved with shared stimulus settings.');
                config = discover_session_stimuli(config);
                session_plan(config,1);
                obj.config = config; obj.render(); set(obj.enableCheck,'Value',config.enabled);
            catch err, set(obj.status,'String',err.message); end
        end
    end
    methods (Static, Access=private)
        function keys = sharedKeys()
            keys = {'duration_s','stim_width_deg','stim_height_deg','fixation_width_deg', ...
                'fixation_height_deg','offset_x_deg','offset_y_deg'};
        end
    end
end
