function samples = session_audio_samples(trial,fs)
% Stereo samples prepared before stimulus onset; no audio work in the frame loop.
[samples,fileFs] = audioread(trial.audio_file);
assert(fileFs == fs, 'Marmulator:AudioSampleRate', ...
    'Stimulus audio must be %d Hz: %s is %d Hz.',fs,trial.audio_file,fileFs);
n = max(1,round(trial.duration_s*fs));
if trial.tone_hz<0 && trial.media_start_s>0
    first = min(size(samples,1)+1,1+round(trial.media_start_s*fs));
    samples = samples(first:end,:);
end
if trial.tone_hz > 0
    assert(trial.tone_hz < fs/2,'Marmulator:Nyquist','Tone is above Nyquist.');
    samples = sqrt(2)*.1*sin(2*pi*trial.tone_hz*(0:n-1)'/fs);
elseif trial.tone_hz == 0 && n>size(samples,1)
    % Repeat the exact deterministic white-noise file for longer presentations.
    samples = repmat(samples,ceil(n/size(samples,1)),1);
end
samples = samples(1:min(n,size(samples,1)),:);
% Prevent a click at a custom crop. Vocalizations end naturally when shorter.
nr = min(round(.005*fs),floor(size(samples,1)/2));
if nr > 1
    ramp = .5-.5*cos(pi*(0:nr-1)'/(nr-1));
    samples(1:nr,:) = samples(1:nr,:).*ramp;
    samples(end-nr+1:end,:) = samples(end-nr+1:end,:).*flipud(ramp);
end
if size(samples,2)==1, samples = repmat(samples,1,2); end
assert(size(samples,2)==2,'Marmulator:AudioChannels','Use mono or stereo stimulus audio.');
end
