function output = create_session_profile(root)
% Create the mixed-session profile without changing any existing experiment.
if nargin<1, root = fullfile(getenv('HOME'),'Stimuli','stimuli_2p'); end
base = fileparts(fileparts(mfilename('fullpath')));
templates = dir(fullfile(base,'experiment_params','AV_stim_*.mat'));
assert(~isempty(templates),'No AV template profile found.');
s = load(fullfile(templates(1).folder,templates(1).name));
s.save_params_name = 'flexible_stimuli_2p';
s.save_params_here = fullfile(base,'experiment_params');
s.session_catalog = fullfile(root,'stimulus_catalog.json');
s.expt_type = 'experiment';
s.stim_mode = 'session'; s.trial_mode = 'trial';
s.reward_on = 'location'; s.reward_thresh = .7;
s.fixation_exp_mode = false; s.n_rsvp = 1;
s.require_fix_tr_init = false;
s.fixation_to_init = 200; s.time_out_trial_init_s = 10;
s.repeats_per_stim = 1;
s.presentation_time = 1500;
s.n_pts_x = 1; s.n_pts_y = 1; s.add_center = false;
s.stim_rect_size_x_deg = 12; s.stim_rect_size_y_deg = 12;
s.bounding_rect_size_x_deg = 6; s.bounding_rect_size_y_deg = 6;
s.manual_bounding_boxes = []; s.manual_bounding_boxes_stim_pre_dot = [];
if isfield(s,'manual_bounding_boxes_fraction'), s = rmfield(s,'manual_bounding_boxes_fraction'); end
s.stimulus_pre_dot = false; s.stimulus_pre_dot_disappear = true;
s.constant_bg_mode = false; s.wake_up_trials = false;
if isfield(s,'wake_up_movie'), s = rmfield(s,'wake_up_movie'); end
s.img_folder = fullfile(root,'images','bodies');
s.movie_folder = fullfile(root,'videos_AV','chair_exported_4set','rgba');
s.loop_movie = false; s.movie_play_sound = false;
s.reset_movie_time_index = true;
s.reward_sound_file = fullfile(base,'trial_outcome_snds','correct.wav');
s.punish_sound_file = fullfile(base,'trial_outcome_snds','incorrect.wav');
s.play_reward_sound = false; s.play_punish_sound = false;
s.give_punishments = false; s.give_rewards = true;
s.inter_stim_interval = 500; s.iti_random = false; s.wait_after_reward = .2;
s.bg_col = 'gray'; s.order = 'random'; s.image_order = 'random';
s.window_rect = []; s.skip_sync_tests = false;
output = fullfile(s.save_params_here,[s.save_params_name '.mat']);
save(output,'-struct','s');
fprintf('Created %s\n',output);
end
