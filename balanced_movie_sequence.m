function img_seq = balanced_movie_sequence(tr_seq, n_stim)
% Balance movies within each location while preserving the location order.
% Counts differ by at most one within a location and across the whole plan.
validateattributes(tr_seq, {'numeric'}, {'vector','integer','positive','finite'});
validateattributes(n_stim, {'numeric'}, {'scalar','integer','positive','finite'});
img_seq = zeros(size(tr_seq));
movie_order = randperm(n_stim);
remainder_offset = 0;
for loc = unique(tr_seq(:))'
    slots = find(tr_seq == loc);
    n = numel(slots);
    remainder = mod(n, n_stim);
    extra = movie_order(mod(remainder_offset + (0:remainder-1), n_stim) + 1);
    pool = [repmat(1:n_stim, 1, floor(n/n_stim)), extra];
    img_seq(slots) = pool(randperm(n));
    remainder_offset = mod(remainder_offset + remainder, n_stim);
end
end
