# Marmulator

Stimulus delivery and oculomotor-behavior control software </br>
Written in MATLAB, based on Psychtoolbox for high precision stimulus timing

## Task modes

### Fixation experiment mode
Trials (typically) require fixation to start, and successful completion requires maintenance of fixation in a bounding box.
This is automatically turned on when n_rsvp is set to >1 OR when fixation_exp_mode is set to TRUE.  
Relevant task variables: 

### Forage mode
Trials are presented in a timed manner and do not require fixation for trial start, however completion of the trial requires a saccade and fixation within a bounding box.  
Relevant task variables: 

### Trial mode 
Trials are presented in a timed manner without requiring fixation for either trial start or for completion of the full trial.  
Relevant task variables: 



## Flexible stimulus sessions

Choose `flexible_stimuli_2p.mat` for folder-selected images, movies and sounds with shared geometry, separate chair/action timing rules, and fixation-percentage rewards. See [setup, formats and audit](STIMULUS_SESSIONS.md).

## Balanced four-quadrant videos

Choose `four_quadrant_video_small_BALANCED_stim20x11deg_bb39.5x11deg.mat`.
It uses the existing small-video geometry and five fixed clips from the same
nature video in `movie_folder`. Clips start at 0%, 20%, 40%, 60% and 80% of the
source duration and replay from their assigned starting point on each trial.
The GUI presentation time sets clip length (400 ms by default); it must fit
within one fifth of the source duration at the selected playback rate.
With five clips and **30 repeats per loc**, the plan contains 120 trials:
each clip appears six times in each
quadrant. If repeats do not divide evenly, counts differ by at most one per
quadrant, with extra presentations distributed across videos. Location order
still follows `order`; movie assignments are randomized within each location.
Balance applies to the planned session; stopping early or timing out before a
stimulus appears can leave the actual presentations unbalanced.

Run `create_balanced_quadrant_profile` (in `tools`) to recreate the default
single-video, five-clip profile. To balance separate video files instead, run
`create_balanced_quadrant_profile('/path/to/five/videos')`.
The default folder is inherited from the original small-video profile and
must contain exactly one video. This clip design uses silent playback.
The saved `img_seq` contains clip IDs and `movie_start_times_s` records their
source timestamps; `img_list` repeats the source filename for each clip.
