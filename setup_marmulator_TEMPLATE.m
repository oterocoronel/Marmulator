% run this once, or anytime configuration params change! 

%%%% Set these parameters: 
marmulator_base_dir = ''; % e.g. '/home/user/Documents/MATLAB/Marmulator' 
save_dir_local = ''; % e.g. '/home/user/Data/Marmulator'  
save_dir_remote = ''; % e.g. '/mnt/server/user/Marmulator_data'
log_dir = fullfile(save_dir_local, 'subject_logs'); % directory for saving subject logs to track reward volume over days

eyetracker_IP = ''; % 'xxx.xx.x.xxx' as a str
eyetracker_port = ''; % 'xxxxx'as a str 

% SETUP PERIPHERALS - ARDUINOS, PUMP
serial_pump_comport = ''; % e.g. '/dev/ttyUSB0'
arduino_lickometer_comport = ''; % e.g. '/dev/ttyUSB1'
arduino_triggers_comport = ''; % e.g. '/dev/ttyACM0'

% TRIGGER ARDUINO PIN CONFIGURATION 
session_pin = 4; 
trial_pin = 7; 
stim_pin = 10; 
sampleCommand_pin = []; % set to [] if you don't want it

% SETUP AUDIO DEVICE
audio_device_keyword = ''; % e.g. 'Steinberg' or 'Rubix22'


% SCREEN PARAMS 
default_gaze_center_adjust = [0,0]; % in pixels from center, negative moves 
screenid_stim = 1; 
screenid_ctrl = 0; 



% Physical stimulus monitor geometry; window_rect=[] uses the full monitor.
deviceBrand = ''; % e.g. 'ASUS'
display_geometry.viewing_distance_cm = 30;
display_geometry.diagonal_inches = 16;
display_geometry.resolution_px = [2560 1600];
display_geometry.size_cm = display_geometry.diagonal_inches * 2.54 * ...
    display_geometry.resolution_px / norm(display_geometry.resolution_px);
display_geometry.pixels_per_cm = display_geometry.resolution_px ./ display_geometry.size_cm;
display_geometry.pixel_pitch_mm = 10 ./ display_geometry.pixels_per_cm;
display_geometry.pixels_per_degree = 2 * display_geometry.viewing_distance_cm * ...
    tand(0.5) * display_geometry.pixels_per_cm;
screenInches = [display_geometry.size_cm/2.54, display_geometry.diagonal_inches];
screenPhysicalPixels = display_geometry.resolution_px;
screenPixels = screenPhysicalPixels;
screenScale = 100;
devicePixelRatio = 1;
viewportPPI = screenPixels(1)/screenInches(1);
dist_to_screen = display_geometry.viewing_distance_cm/2.54; % legacy field in inches
deg_to_inch_on_screen = 2*tand(0.5)*dist_to_screen;
deg_to_pixel_on_screen = display_geometry.pixels_per_degree(1);
%%%%


reward_types = {''}; % cell of strings for reward


%%%% DO NOT MODIFY %%%%
setup_date = datestr(now, 'yyyy-mm-dd_HH-MM_SS'); 
setup_save_path = fullfile(marmulator_base_dir, 'setup_config_TEST.mat'); 

save(setup_save_path, 'marmulator_base_dir', 'save_dir_local',...
    'save_dir_remote', 'log_dir', 'eyetracker_IP', 'eyetracker_port', 'serial_pump_comport',...
    'session_pin', 'trial_pin', 'stim_pin', 'sampleCommand_pin', ...
    'arduino_lickometer_comport', 'arduino_triggers_comport',...
    'default_gaze_center_adjust', 'screenid_stim', 'screenid_ctrl', ...
    'setup_date', 'reward_types',...
    'deviceBrand','screenInches','screenPixels','screenPhysicalPixels','screenScale','viewportPPI','devicePixelRatio',...
    'dist_to_screen','deg_to_inch_on_screen','deg_to_pixel_on_screen', ...
    'audio_device_keyword', 'display_geometry');

fprintf('saved setup config to %s\n', setup_save_path); 







