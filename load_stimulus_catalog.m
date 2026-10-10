function config = load_stimulus_catalog(root)
% Load folder definitions and discover their current contents.
catalog = fullfile(root, 'stimulus_catalog.json');
assert(isfile(catalog), 'Marmulator:MissingCatalog', ...
    'Missing %s. Run tools/prepare_stimuli.py on this stimulus root first.', catalog);
config = jsondecode(fileread(catalog));
assert(config.version == 2, 'Marmulator:CatalogVersion', ...
    'Run tools/prepare_stimuli.py to update this stimulus catalog.');
config.root = root;
config.enabled = true;
config = discover_session_stimuli(config);
end
