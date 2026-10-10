function output = create_balanced_quadrant_profile(movie_folder)
% Copy the small four-quadrant design with movie counts balanced per location.
% Default: five fixed clips from the original single nature video.
% With a folder argument, balance all separate movie files in that folder.
base = fileparts(fileparts(mfilename('fullpath')));
s = load(fullfile(base,'experiment_params', ...
    'four_quadrant_video_small_stim20x11deg_bb39.5x11deg.mat'));
if nargin > 0
    s.movie_folder = movie_folder;
else
    s.movie_clip_count = 5;
    s.movie_play_sound = false;
    s.reset_movie_time_index = true;
end
s.save_params_name = 'four_quadrant_video_small_BALANCED_stim20x11deg_bb39.5x11deg';
s.save_params_here = fullfile(base,'experiment_params');
s.save_base = base;
s.save_full = fullfile(s.save_params_here,s.save_params_name);
s.image_order = 'balanced_per_location';
s.repeats_per_stim = 30;
output = [s.save_full '.mat'];
save(output,'-struct','s');
fprintf('Created %s\n',output);
end
