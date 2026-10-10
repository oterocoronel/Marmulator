function starts = movie_clip_start_times(duration_s, count, presentation_s, rate)
% Fixed starting points in equal sections of one source movie.
validateattributes(duration_s, {'numeric'}, {'scalar','positive','finite'});
validateattributes(count, {'numeric'}, {'scalar','integer','positive','finite'});
validateattributes(presentation_s, {'numeric'}, {'scalar','positive','finite'});
validateattributes(rate, {'numeric'}, {'scalar','positive','finite'});
assert(presentation_s*rate <= duration_s/count, 'Marmulator:ClipTooLong', ...
    'Presentation time at the chosen movie rate must fit within one of the %d movie sections.', count);
starts = (0:count-1) * (duration_s/count);
end
