function output = create_progress_dot_profile()
% Derive the dot calibration from the existing 3x3 faces/large-window design.
% Keep grid, gaze boxes, dot size, initiation, hold, timeout and reward fraction.
base = fileparts(fileparts(mfilename('fullpath')));
s = load(fullfile(base,'experiment_params', ...
    'grid_3x3_faces_calibration_10deg_lgwin_stim6x6deg_bb10x10deg.mat'));
s.stim_mode = 'progress_dot';
s.pulse_size = false;
s.img_folder = '';
s.stimulus_pre_dot_disappear = false;
s.save_params_name = 'grid_3x3_progress_dot_calibration_10deg_lgwin';
s.save_params_here = fullfile(base,'experiment_params');
s.save_base = base;
s.save_full = fullfile(s.save_params_here,s.save_params_name);
output = [s.save_full '.mat'];
save(output,'-struct','s');
fprintf('Created %s\n',output);
end
