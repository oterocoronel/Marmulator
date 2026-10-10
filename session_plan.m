function trials = session_plan(config, repeats)
% A randomized complete pass through every selected item/condition per repeat.
validateattributes(repeats, {'numeric'}, {'scalar','integer','positive','finite'});
trials = struct([]);
for k = 1:numel(config.items)
    item = config.items(k);
    gidx = find(strcmp({config.groups.name}, item.set_name), 1);
    if isempty(gidx) || ~config.groups(gidx).enabled || ~item.enabled, continue; end
    modes = strsplit(config.groups(gidx).modality, ',');
    for m = 1:numel(modes)
        trial = session_trial(config, item, modes{m});
        if ~isempty(trial), trials = [trials trial]; end %#ok<AGROW>
    end
end
assert(~isempty(trials), 'Marmulator:EmptySession', 'Select at least one nonempty stimulus folder.');
base = trials;
trials = struct([]);
for k = 1:repeats
    trials = [trials base(randperm(numel(base)))]; %#ok<AGROW>
end
end
