# Flexible stimulus sessions

Implemented and inspected on 2026-10-10 for `/home/davidh/Stimuli/stimuli_2p`.

## Start a session

Open `Marmulator` and choose **flexible_stimuli_2p.mat**. The third column enables the mixed-stimulus mode. Check the folders/sets to include. All matching files currently in a checked folder are used; there is no individual stimulus/call-ID checklist. Add or remove files in the selected folders to change the subset, then Run or Reload. Existing experiment profiles remain available for calibration and older tasks; selecting one disables mixed mode until explicitly checked again.

- **Mode:** AV, A, V, or AV,A,V. The last option schedules all three conditions of each selected call. They share the same visual file and audio sidecar.
- **Shared Time:** positive seconds for images, faces, bodies, objects, tones/noise, dots and gratings. This sets stimulus-on to stimulus-off time independent of fixation. Dots/gratings play from their beginning.
- **Chair timing:** by default `max(shared Time, movie duration, WAV duration)`. Thus short calls have at least the shared presentation time and longer calls play fully. The second option caps this result at **Chair maximum**, removing excess time only from the end. For example, shared Time 1.5 s and chair maximum 2 s presents a 1.1 s call for 1.5 s and a 2.4 s call for 2 s. The same rule applies to AV, A and V conditions of a call.
- **Action / arena duration:** separate positive seconds. When shorter than the movie, use its centered interval: start at `(movie duration - requested duration)/2`. A 5 s movie requested for 4 s plays 0.5–4.5 s. This is a playback seek and end time; source files are not trimmed or re-encoded.
- **Shared Stim W/H:** the same target dimensions for every stimulus, in visual degrees. Images exclude outer transparent padding using the smallest rectangle containing all pixels with alpha greater than zero, then center that rectangle on fixation and fit it inside the requested dimensions while preserving aspect ratio. Alpha movies use one fixed crop covering the foreground during the presented interval, centered on fixation. Their fixed scale fits the **average foreground width/height** into the target dimensions, weighting each frame by how long it is visible (including a final frame held beyond EOF). Natural size changes remain: a 10-degree target can show an animal at 8 degrees early and 12 degrees later. Individual frames can exceed the target dimensions; there is no frame-by-frame resizing or recentering. Opaque media use the full frame; fully transparent media remain blank. **Shared Fix W/H:** independent rectangular fixation-box dimensions, also common to every stimulus.
- **X/Y:** offsets in degrees from the rig-adjusted display center. Positive X moves right; positive Y moves down. For example, X = 5 moves both the stimulus and fixation box 5 degrees right. Their dimensions remain independent. These controls neither delay audio relative to video nor give the fixation box a separate center. The original left-column gaze Offset X/Y controls still calibrate the eye tracker; they are separate from these stimulus-position controls.
- **Reward percentage:** fraction of the entire presentation spent inside the fixation box. The default is 70%; meeting the threshold is sufficient. Missing/invalid gaze counts outside. Intervals are weighted by measured display timestamps, so a missed frame is not counted as just one ordinary interval.
- **Background:** gray, black, or white, visible through alpha. The existing **Black surround** keeps a clear 15-degree circle, fading to black by a 20-degree diameter; it follows the stimulus center and leaves the photodiode visible.
- **Repeats:** complete randomized passes through all selected stimulus/condition combinations. Each selected combination occurs once per pass. This differs from the older profile meaning of repetitions per spatial location.

Shared X/Y also applies to every stimulus. If a requested duration exceeds the available media, the final video frame is held and the sound ends naturally. There is no movie looping.

The default enables only the 12 selected vocalizations in AV mode, using the longer of shared time and full clip/WAV. Shared Time is 1.5 s, stimulus bounds 12×12 degrees, fixation box 6×6 degrees, and position X/Y = 0/0. Arena actions default to 4 s. Chair maximum defaults to 2 s and is disabled until the capped option is chosen. The profile uses a 500 ms inter-trial interval and a 200 ms post-reward wait, with optional pre-trial fixation disabled and reward/punishment sounds disabled.

Folder exclusions, shared geometry/time, chair/action timing, background and reward percentage can change between trials during a session. An ongoing stimulus retains its settings. Unchecking a folder skips its upcoming trials. Folder contents are rescanned at Run; newly added files/conditions enter on the next Run, which creates a finite schedule. The mode checkbox, black surround, initiation controls and repetitions are read at Run. Save/load session JSON preserves folder choices and shared settings without editing the MAT experiment or saving an ID list. Catalog Reload resets catalog choices, so save custom settings first.

A-only trials show a 10-pixel fixation dot at the shared stimulus/fixation center throughout presentation. It is white on gray/black backgrounds and black on white. The full reward fixation box is visible only to the operator; its size is independent of the dot and stimulus bounds.

The operator preview also shows a thin white outline of the configured **Shared Stim W/H** area at the shared X/Y position, including during the interval before presentation. For example, 10×10 degrees gives a 10×10-degree outline, independent of the image aspect ratio and fixation-box size. The outline remains visible with Black surround enabled.

## Inventory and format decisions

The original folder includes many alternative exports of the same identities. Folder patterns select one variant per identity; the current folder counts are:

| Set | Catalog files | Chosen source | Default duration |
| --- | ---: | --- | --- |
| Front faces | 10 | All animals at 0°, source-color refined-mask RGBA PNG | 1.5 s |
| Other head orientations | 80 | All animals at ±22.5°, ±45°, ±67.5°, ±90°, same RGBA variant | 1.5 s |
| Bodies | 20 | Source-color refined-mask RGBA PNG | 1.5 s |
| Objects | 33 | Original-color refined RGBA PNG | 1.5 s |
| Phee | 6 | vocalization_phee: original RGBA + adjacent denoised WAV | 1.780–2.390 s |
| Tisk | 6 | vocalizations_tisk: original RGBA + adjacent denoised WAV | 1.5 s |
| Arena | 438 | arena_exported_5set/rgba, grouped into 9 behaviors | 4 s from 5 s files |
| Dots / gratings | 16 / 16 | Existing 2560×1600, 60 fps MJPEG AVI | 1.5 s from 5 s files |
| Tones / noise | 13 / 1 | Generated mono PCM16 WAV at 96 kHz | 1.5 s |

Total: **18 sets, 639 catalog items**. Face files are physically grouped into `images/marmfaces_orientations/front` and `images/marmfaces_orientations/other_orientations`. Each GUI face choice includes every animal; animal identity remains in filenames, with no separate animal-ID groups. Alternative exports and their parameter files moved with the corresponding images, without changing their contents. Click Reload after this reorganization to use the new folder choices.

All 143 chosen PNGs have nonopaque alpha. Natural movies use MKV with VP9 alpha. The `yuv420p` reported by ffprobe is insufficient to determine transparency: these files also carry `ALPHA_MODE=1`. A decoder must support the separate VP9 alpha stream. A native FFmpeg decode here discarded alpha; explicit libvpx decoding and the installed GStreamer VP9 alpha decoder preserved it. Psychtoolbox playback also preserved it. The player requests RGBA, disables movie audio/hardware decoding, and checks the first frame for alpha before presentation. Missing decoder support causes an error instead of silently displaying an opaque background.

Retain PNG for images, VP9-alpha MKV for natural movies, and PCM WAV for sound. Keep the existing AVI motion movies as their own consistent set. No media were re-encoded. The twelve full mono PCM16/96 kHz denoised WAVs were copied from the production export into `videos_AV/vocalization_phee` and `videos_AV/vocalizations_tisk`, alongside their selected movies. WAV pairing strips `_rgba` from the movie name and appends `_denoised.wav`. A missing adjacent WAV is automatically copied from the production `wav_denoised` folder if available. Arena and motion files are intentionally silent. AV/V reuse one visual file; AV/A reuse one WAV. The production MKVs keep their embedded audio; Marmulator mutes that track and uses PsychPortAudio for all sound.

The selected phee/tisk copies initially matched SHINE exports byte-for-byte. To make the selected folders directly playable with the requested original RGBA sources, those twelve copies were replaced with byte-identical copies from unnormalized `chair_exported_4set/rgba`. Previous selected copies were backed up under the `/tmp/marmulator_selected_chair_backup_*` directory recorded in `stimulus_inventory.json`. All 116 production chair exports and their SHINE alternatives remain untouched. The current selection is **6 phees and 6 tisks**; that count is not hard-coded into the folder loader.

### Chair audio comparison

All twelve original RGBA movies contain **denoised audio**, not raw audio. Their embedded PCM16 samples match the denoised WAVs exactly from sample zero throughout their overlap. All tracks are mono 96 kHz and begin at movie time zero. The selected SHINE copies contain the same embedded audio as the original RGBA movies. The production metadata also explicitly states that denoised audio was muxed into both MKV variants, using `manifest_start` synchronization.

Five embedded tracks contain the entire denoised WAV; seven omit 10.021–86.010 ms from its end. According to the exported call annotations, those omissions lie in the approximately 500 ms of trailing padding, after the vocalization. Even the shortest retained padding is about 414 ms. This is a container/export-length difference, not a change to the denoised waveform. The full WAVs avoid relying on these shortened tracks. Some visual duration tags also end one frame interval early, so native chair presentation duration is the maximum of the visual duration tag and the synchronized WAV duration. The final frame is held when necessary. Shared time and the optional chair maximum then determine the presentation duration as described above.

`chair_audio_audit.json` records the sample comparisons, lengths, digital levels and annotation padding for every selected call. One selected-folder RGBA movie plus its adjacent denoised WAV is the runtime pairing; matching happens automatically by filename. This also keeps A-only playback independent of the movie decoder. The twelve temporary extracted WAVs from the initial preparation were retired to `/tmp/marmulator_obsolete_chair_audio_gjz6anm1`; no production assets were moved or deleted.

`stimulus_catalog.json` version 2 holds folder definitions and shared GUI settings, with no stimulus/call-ID list. `stimulus_inventory.json` caches movie headers and records preparation choices; its entries do not determine membership. Current files are enumerated on load and at Run. The folder patterns exclude raw masks, seeds, diagnostics and SHINE duplicates. Session JSON saves only folder choices/settings; actual filenames are still logged per trial for reproducibility.

## Tones

Half-octaves, including both endpoints: 440, 622.254, 880, 1244.508, 1760, 2489.016, 3520, 4978.032, 7040, 9956.063, 14080, 19912.127, 28160 Hz. Files use 96 kHz mono PCM16, nominal RMS 0.1 digital full scale, and 5 ms raised-cosine onset/offset ramps. The tones folder includes **13 tones plus `white_noise.wav`**, all loaded by the tones GUI choice. The saved noise clip is 1.5 seconds and uses a deterministic seed. Nothing here establishes an acoustic SPL or equal loudness across frequencies.

At presentation, tones are synthesized at the exact requested duration. White noise uses the saved waveform, repeating it for durations beyond 1.5 seconds. Vocalization audio is cropped if needed and receives a short onset/offset ramp to avoid clicks; shorter recordings end naturally. Mono stimuli are sent identically to both output channels. The engine opens a 96 kHz stereo device; short legacy feedback sounds are resampled separately. The Steinberg UR22C opened at 96 kHz in the muted hardware smoke test.

### Ryan's audio settings

All 42 MAT files in `experiment_params_fromRyan` were inspected. They specify reward/punishment sound paths and switches, and two profiles enable movie sound. The AV profiles reference `correct_96khz.wav` / `incorrect_96khz.wav`. There are no SPL, digital gain, volume, RMS, attenuation, or speaker-calibration settings in these experiment files. `calibration_win_len` and `calibration_win_ht` are visual window dimensions. The matching fields are recorded in `ryan_audio_settings_audit.json` beside the stimulus catalog.

The legacy `AV_code/filter_norm_audio_fcn.m` applies a fourth-order 400 Hz high-pass filter, then peak-normalizes each extracted movie sound to 0.8 digital full scale. That is digital preprocessing, not an acoustic SPL calibration. The new session player preserves the existing denoised WAV amplitude, aside from short anti-click ramps; it does not apply this older filter or peak normalization. Tones/noise remain at nominal RMS 0.1 digital full scale. A physical calibration at the animal's position and the rig's output gain are still needed to assign SPL or equalize frequencies.

## Data and compatibility

The new engine arguments are optional `session_config` and `session_reader`, following `black_surround`; existing callers retain their positional API. The existing engine continues handling gaze transforms, initiation, triggers, lick monitoring, pump suppression and rewards. Mixed mode overrides fixation-contingent ending and RSVP, and opens only the current stimulus rather than hundreds of movies at once.

The operator preview uses a texture created for its own display. On this rig, drawing the subject display's texture directly on the other X screen produced a white rectangle. The player now renders the current frame at the preview's actual pixel coordinates on the subject GPU, transfers that small RGBA image, and creates a separate operator texture. Images are copied once; movies update the copy only when a new decoded frame arrives. This preserves transparency and exact frame pairing while retaining one movie decoder and the original subject resolution. Preview buffers/textures are released at trial end.

Session files include the initial configuration in `calib_settings.session_config` and effective per-trial settings in `calib.session_trials`, including modality, files, timing policy, native/requested/scheduled durations, movie start time (`media_start_s`), marker visibility, shared geometry, offsets, pixel rectangles and reward threshold. Visual trials also record the source crop (`visual_source_rect_px`), mean foreground size before scaling (`visual_mean_foreground_size_px`), fixed source-to-display scale (`visual_scale`), and actual destination rectangle (`visual_rect_px`); `stim_rect_px` remains the requested target box. They also include `calib.fixation_fraction`, `calib.session_skipped`, `calib.audio_start_t`, movie presentation timestamps, measured onset/offset and frame timestamps. Aborted trials are logged and excluded from the completed count. Manual reward/end and Escape remain explicit operator overrides to normal timing. Automatic reward still respects existing pump/lick suppression.

The old movie path's source-frame-count versus display-frame-count termination was replaced with elapsed movie duration. All new stimulus timing uses flip timestamps and rounds the desired duration to the nearest display refresh, with at least one refresh. Movie load/decode preparation happens before stimulus onset; it can extend the blank interval. The first use of an alpha movie scans all frames for foreground bounds and timestamps, keeping only one scan texture at a time. Those small per-frame measurements are cached for subsequent trials in the same session and rescanned if the file's size or modification time changes. Changing the selected interval recalculates its crop and average foreground size from the cached measurements. The subject display and operator preview use the same source crop; source media are not rewritten. Acquisition/display overload can still miss a refresh and is visible in saved timestamps. Software audio scheduling and timestamps do not replace a physical audiovisual-latency measurement on the rig.

## Reproduce and verify

From the repository:

```sh
python3 tools/prepare_stimuli.py /home/davidh/Stimuli/stimuli_2p
python3 tools/audit_chair_audio.py /home/davidh/Stimuli/stimuli_2p
```

The preparation command regroups face exports into front/other-orientation folders, probes the 482 selected movies, creates missing tones/noise, copies original RGBA chair movies and full denoised WAVs into the selected folders, and regenerates the folder catalog and inventory. It backs up selected movie copies before replacing a different export. Production movie sources and arena/dots/gratings files are not rewritten. The audio audit decodes the selected movie, original movie, raw WAV and selected denoised WAV without resampling. If the default ffmpeg/ffprobe are broken, the tools try the existing `campy` installation; explicit `--ffprobe` and, for the audio audit, `--ffmpeg` paths are supported.

In MATLAB:

```matlab
addpath(fullfile(pwd,'tools'));
create_session_profile('/home/davidh/Stimuli/stimuli_2p');
results = runtests('tests');
assertSuccess(results);
verify_session_media('/home/davidh/Stimuli/stimuli_2p');
```

Automated tests cover folder additions/removals, shared AV/A/V media, shared geometry/time, full/capped chair timing, centered action trimming/seeking, audio preparation, A-only marker visibility/contrast, GUI construction, time-weighted fixation, complete mixed-engine trials with gaze inside/outside, live settings/exclusions, a dropped display frame, and Escape. Engine simulations use temporary device fakes outside the repository; they do not play sound or deliver rewards. The media smoke test now opens small windows on **both configured displays**, checks actual decoder transparency/compositing and centered action seeks, and plays silent frames of all 12 calls plus one item from each other visual set. It compares operator-preview pixels to a reference drawn in the subject's graphics context, at half size and after resizing, and checks that trial textures are released. **All 27 representative stimuli passed on both displays**, as did A-only marker contrast on gray, black and white. The earlier single-window check missed the cross-display white-rectangle bug. The face reorganization preserved all 720 image/metadata files byte-for-byte and passed the catalog/audio/GUI tests, including loading white noise. This windowed test deliberately skips sync checks and does not validate fullscreen experimental timing. Production sessions keep sync checks enabled. No reward or trigger hardware was exercised.

Relevant PTB references: [OpenMovie](https://psychtoolbox.org/docs/Screen-OpenMovie) documents RGBA decoding and disabling movie audio; [GetMovieImage](https://psychtoolbox.org/docs/Screen-GetMovieImage) documents nonblocking frame retrieval and movie presentation timestamps; [SetMovieTimeIndex](https://psychtoolbox.org/docs/Screen-SetMovieTimeIndex) seeks to the centered action start in seconds.

## Remaining experiment choices

1. Which physical speaker calibration and output-gain setting should define sound level? Ryan's experiment files do not supply this information.

Confirmed choices: six phees and six tisks selected by folder contents, original chair RGBA movies with adjacent denoised WAVs, thirteen half-octave tones from 440 to 28,160 Hz, shared geometry/time controls, centered action cropping, end-only chair cropping, and fixation markers for A-only presentation.
