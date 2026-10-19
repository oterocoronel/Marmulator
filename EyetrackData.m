classdef EyetrackData < handle

    properties (Access = public)
        eyetracker = []; % for connection handle
        Data = [];
    end

    properties (Access = private)
        recording = false
        recordingStart = 0
        samples = zeros(0,6)
        sampleCount = 0
        pendingText = ''
    end

    methods
        % Constructor to initialize the class
        function obj = EyetrackData()
            %obj.Data = []; % Initialize data
        end

        % Method to add data
        function obj = addData(obj, newData)
            obj.Data = newData; % Overwrite data
            if obj.recording
                values=sscanf(char(newData),'%f,%f,%f,%f,%f');
                if numel(values)==5
                    if obj.sampleCount==size(obj.samples,1)
                        obj.samples=[obj.samples;zeros(size(obj.samples))];
                    end
                    obj.sampleCount=obj.sampleCount+1;
                    obj.samples(obj.sampleCount,:)=[GetSecs()-obj.recordingStart values'];
                end
            end
        end

        function startRecording(obj,start_time)
            drawnow; % Drain events from before this session.
            if ~isempty(obj.eyetracker), obj.readAddData(obj.eyetracker,[]); end
            obj.recordingStart=start_time;
            obj.samples=zeros(10000,6); obj.sampleCount=0;
            obj.recording=true;
        end

        function data = stopRecording(obj)
            if obj.recording
                drawnow;
                if ~isempty(obj.eyetracker), obj.readAddData(obj.eyetracker,[]); end
            end
            obj.recording=false;
            rows=obj.samples(1:obj.sampleCount,:);
            % Arrival time may lag during blocking calls; retain tracker time too.
            data=struct('time',rows(:,1),'eyetracker_tstamp',rows(:,2), ...
                'x_pos',rows(:,3),'y_pos',rows(:,4),'radius',rows(:,5),'eye_open_rat',rows(:,6));
        end

        function connectTCPIP(obj, IPaddr, port, varargin)
            %connectTCPIP(obj, IPaddr, port, connect_timeout)
            if numel(varargin)>0
                connect_timeout = varargin{1}; 
            else
                connect_timeout = 10; 
            end
            obj.eyetracker = tcpclient(IPaddr, port, 'ConnectTimeout', connect_timeout);             
            %configureCallback(obj.eyetracker, 'terminator', @obj.readAddData);
            configureCallback(obj.eyetracker, 'terminator', @(src, event) obj.readAddData(src, event)); 
            flush(obj.eyetracker)
            write(obj.eyetracker, 'start'); 

        end

        %function readAddData(src, ~, obj)
        function readAddData(obj, src, ~)
            % Read queued packets together, retaining an incomplete final line.
            n=src.NumBytesAvailable;
            if n==0, return; end
            bytes=read(src,n,'uint8');
            obj.pendingText=[obj.pendingText char(bytes(:)')];
            ends=find(obj.pendingText==newline); first=1;
            for k=1:numel(ends)
                obj.addData(obj.pendingText(first:ends(k)-1)); first=ends(k)+1;
            end
            obj.pendingText=obj.pendingText(first:end);
        end

        function startSend(obj)
            write(obj.eyetracker, 'start')
        end

        function stopSend(obj)
            write(obj.eyetracker, 'stop')
        end

        function delete(obj)
            if ~isempty(obj.eyetracker)
                write(obj.eyetracker, 'stop'); 
            end
            delete(obj.eyetracker); 
            fprintf('eyetracker deleted\n')
        end

        % Method to retrieve data
        function pupil = getData(obj)
            data = obj.Data;
            if isempty(data)
                %fprintf('EyetrackData: data read is empty\n')
                pupil.t_stamp = NaN; 
                pupil.x_pos = NaN; 
                pupil.y_pos = NaN; 
                pupil.radius = NaN; 
                pupil.eye_open_rat = NaN; 
            else
                data_vec = sscanf(char(data),'%f,%f,%f,%f,%f');
                if numel(data_vec)~=5, data_vec=nan(5,1); end
                pupil.t_stamp = data_vec(1);
                pupil.x_pos = data_vec(2);
                pupil.y_pos = data_vec(3);
                pupil.radius = data_vec(4);
                pupil.eye_open_rat = data_vec(5);
            end
            obj.Data = [];
        end

    end
end
