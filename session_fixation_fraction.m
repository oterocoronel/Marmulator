function fraction = session_fixation_fraction(frame_onsets, inside, stimulus_off)
% Weight each displayed interval by its measured duration, including misses.
% NaN/invalid gaze is outside, rather than removed from the denominator.
times = [frame_onsets(:); stimulus_off];
weights = diff(times);
assert(numel(inside) == numel(weights) && all(isfinite(times)) && ...
    all(weights >= 0), 'Marmulator:FixationTimes', 'Invalid fixation interval timestamps.');
if isempty(weights) || sum(weights) <= 0
    fraction = 0;
else
    fraction = sum(weights .* (inside(:) == 1)) / sum(weights);
end
end
