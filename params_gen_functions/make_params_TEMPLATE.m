function make_params_TEMPLATE()

%%%%% THIS IS INTENDED AS A COMPLETE TEMPLATE - MAKE A COPY OF THIS FILE TO
%%%%% MAKE YOUR OWN PARAMETER GENERATION FUNCTIONS 

save_params_name = 'center_RSVP3_stim10x10deg_bb4x4deg';
save_base = fileparts(fileparts(mfilename('fullpath')));
expt_type = 'experiment';
display_geometry.viewing_distance_cm = 30;
display_geometry.diagonal_inches = 16;
display_geometry.resolution_px = [2560 1600];
display_geometry.size_cm = display_geometry.diagonal_inches * 2.54 * ...
    display_geometry.resolution_px / norm(display_geometry.resolution_px);
display_geometry.pixels_per_cm = display_geometry.resolution_px ./ display_geometry.size_cm;
display_geometry.pixel_pitch_mm = 10 ./ display_geometry.pixels_per_cm;
display_geometry.pixels_per_degree = 2 * display_geometry.viewing_distance_cm * ...
    tand(0.5) * display_geometry.pixels_per_cm;
geometry_units = 'degrees'; % Edit *_deg fields; pixel values are generated below.

%% SETTINGS:
% general
window_rect = []; % empty to run fullscreen
skip_sync_tests = 1;

calibration_win_len_deg = 8;
calibration_win_ht_deg = 8;

n_pts_x = 1; % how many different x grid locations
n_pts_y = 1; % how many different y grid locations 
repeats_per_stim = 10; % along w n_pts_x and n_pts_y, determines number of trials: n_pts_x * n_pts_y * repeats_per_stim 
presentation_time = 300; % ms
inter_stim_interval = [1000 2000];
iti_random = false;
order = 'random'; % or 'sequential'
bg_col = 'gray';
stim_rect_size_x_deg = 10; % moving dots, rectangles, images
stim_rect_size_y_deg = 10; % Sizes must be multiples of 0.5 degrees.


show_curr_bounding_box = true;
show_all_bounding_boxes = true;

bounding_rect_size_x_deg = 4;
bounding_rect_size_y_deg = 4;

manual_bounding_boxes = []; % empty for automoatic OR e.g. [0, 0, 768, 432; 768,0,1536,432; 0,432,768,864; 768,432,1536,864];

% mode
trial_mode = 'foraging'; % 'trial' or 'foraging' - MUST BE SET TO FORAGING FOR RSVP MODE
reward_on = 'location'; % quality or location
time_to_reward = 500; % ms; only applies on foraging expts
time_out_after = 2000; % ms; ; only applies on foraging expts
location_require_quality = true; 

stim_mode = 'images'; % 'images', 'movie', 'moving_dot', 'rectangle', 'spinning', 'smooth pursuit'

if strcmp(stim_mode,'spinning') || strcmp(stim_mode,'smooth pursuit') 
    diam_circle = 500; % diameter of the circular trajectory % px
    speed = 500; %speed of the stimulus along the circular trajectory % px
end

if strcmp(stim_mode,'smooth pursuit')
    angle_endpts = [45, 135, 225, 315]; 
end

% images
img_folder = {fullfile(save_base, 'stim\yj_camels'), fullfile(save_base, 'stim\yj_wrenches'),}; 
img_folder = {fullfile(save_base,'stim\brad')};
pulse_size = false; % true or false

% movies 
movie_folder = 'C:\Users\Hector\Documents\Nature videos\for_calib_stim'; 
movie_rate = 1; % speed of movie playback 

% moving dot parameters
scale_fact_move = 10; % how quickly should dot move?
scale_fact_size = 3; % how quickly should dot change size? 0 = no change
mvdot_sz_deg = 0.5;
reverse_rate = 0.2; % how often (per frame) should the stim change direction in x, y, or size
reverse_rate_sz = 0.2;

% rsvp - if n_rsvp>1, this will use 'rsvp mode' and trial_mode must be set
% to 'foraging'
n_rsvp = 3; 
rsvp_iti_t = 200; 
break_after = 300; 

% stimulus pre dot
stimulus_pre_dot = true;
stimulus_pre_dot_disappear = true; 
stimulus_pre_time = 500; %ms, does not apply if require_fix_tr_init
stim_pre_dot_sz_deg = 0.5;

bounding_rect_size_stim_pre_dot_x_deg = 2;
bounding_rect_size_stim_pre_dot_y_deg = 2;

% require fixation for trial start
require_fix_tr_init = true;
fixation_to_init = 400;
time_out_trial_init_s = 10; 

% offset in y
gaze_center_adj_y = 0;
gaze_center_adj_x = 0;
apply_gaze_center_adj = true;

% gaze point drawing
draw_gaze_pt = true;
n_gaze_pts_draw = 1;
dot_col = distinguishable_colors(1);
gaze_pt_sz_deg = 0.5;
draw_retain_bb_pts = false; % draw and retain the points that land in the bounding box through the session

% gaze point feedback % SOMEWHAT DEPRECATED
color_shift_feedback = false; 
rew_col_start = [127.5,127.5,127.5]; % gray
rew_col_end = [50,205,50]; % lime green

% reward sound feedback 
play_reward_sound = true; 
reward_sound_file = fullfile(save_base, 'trial_outcome_snds\correct.wav'); 

% punishment params 
give_punishments = true; 
punish_length_ms = 500; 
play_punish_sound = true; 
punish_sound_file = fullfile(save_base, 'trial_outcome_snds\incorrect.wav');  


% eyetracking
eye_method = 'pupil'; % 'pupil', 'rand', or GUI mouse-gaze mode
n_frames_blink = 8; 

% reward
give_rewards = true;
reward_thresh = 0.95; % 95% of quality codes should be 0 ('glint is good')
reward_on_dur = 0.1; % this shouldn't matter given the pump program just runs on the rising edge
ard_pin_rew = 10; % which pin has the reward signal?
wait_after_reward = 4;

% wake-up trials 
wake_up_trials = true;
wake_up_every = [4 8];
wake_up_tr_dur = 6;
wake_up_img_fold = fullfile(save_base, 'stim\naturalistic_scenes');
wake_up_stim_size_x_deg = 24.5;
wake_up_stim_size_y_deg = 18.5;

%%% DO NOT MODIFY %%%%
% Cache pixel fields for existing analysis code. The engine derives them
% again from the degree fields and current rig geometry at session startup.
deg_to_pix = @(d) round(convertDegreesPix(d, display_geometry.viewing_distance_cm, ...
    display_geometry.size_cm, display_geometry.resolution_px));
calibration_win_len = deg_to_pix(calibration_win_len_deg);
calibration_win_ht = deg_to_pix(calibration_win_ht_deg);
stim_rect_size_x = deg_to_pix(stim_rect_size_x_deg);
stim_rect_size_y = deg_to_pix(stim_rect_size_y_deg);
bounding_rect_size_x = deg_to_pix(bounding_rect_size_x_deg);
bounding_rect_size_y = deg_to_pix(bounding_rect_size_y_deg);
bounding_rect_size_stim_pre_dot_x = deg_to_pix(bounding_rect_size_stim_pre_dot_x_deg);
bounding_rect_size_stim_pre_dot_y = deg_to_pix(bounding_rect_size_stim_pre_dot_y_deg);
stim_pre_dot_sz = deg_to_pix(stim_pre_dot_sz_deg);
gaze_pt_sz = deg_to_pix(gaze_pt_sz_deg);
mvdot_sz = deg_to_pix(mvdot_sz_deg);
wake_up_stim_size_x = deg_to_pix(wake_up_stim_size_x_deg);
wake_up_stim_size_y = deg_to_pix(wake_up_stim_size_y_deg);
clear deg_to_pix;
save_params_here = fullfile(save_base, 'experiment_params');
save_full = fullfile(save_params_here, save_params_name);
save(save_full);
fprintf('saved %s \n', save_params_name);
disp(save_full);

