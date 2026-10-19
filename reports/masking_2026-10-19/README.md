# Video alpha, background and timing audit — October 19, 2026

Compared the current working files, including uncommitted/untracked helpers, against `7664eb60578f316d996f709969678320b435f36b` ("Revemod tracking .asv"). That is the locally recorded `origin/my-main` tip. No remote fetch was performed. Current HEAD is `b2179a4`, four commits ahead of that reference. Existing source edits and staged changes were preserved; this audit adds a benchmark and its reports.

The black surround itself is inexpensive during playback. The significant costs are first-use alpha movie analysis and copying video frames to the operator preview. Typical 12° presentations had no measured steady-state refresh misses, but a 40° high-resolution dot movie with preview did miss refreshes. This is evidence of a rendering limit, not a full acquisition timing certification.

## What changed

- The original `GL_SRC_ALPHA` / `GL_ONE_MINUS_SRC_ALPHA` blend rule is unchanged. Both old and current ordinary movie paths request RGBA textures; alpha compositing itself is not new. The original movie branch did not actively draw its video on the control screen.
- The optional black surround was added after the pushed reference: first rectangular, then circular. Its defaults preserve a 15° central diameter, fade over 2.5° radially, and reach black at 20° diameter. It follows the stimulus and excludes the photodiode patch. It is off by default. The fade is quintic smootherstep in approximate lightness using nominal gamma 2.2. Because it is drawn after the stimulus, it darkens both background and any stimulus crossing its edge; it does not rewrite movie alpha.
- Flexible sessions introduce `SessionStimulusPlayer`. Alpha movies are scanned once per player/file revision, over the entire source movie, to cache frame foreground bounds. A fixed crop covers the selected interval; scaling uses its time-weighted mean foreground size. This can change apparent object size and placement relative to fitting the original complete video frame. The crop does not track or resize on every displayed frame.
- The operator preview downsamples on the subject GPU, reads RGBA into MATLAB with `Screen('GetImage')`, and uploads it into the control display context. The intermediate buffer uses `GL_ONE` / `GL_ZERO`, preserving straight alpha so it is not multiplied twice. The copy happens for new decoded frames; still images reuse their preview texture.
- The new player opens movies with flags `6`, versus `2` in the original branch: both disable movie sound; the additional flag disables hardware video decoding. This can increase CPU decoding load, although the original codec may already have used software decoding. All sound in flexible sessions uses PsychPortAudio separately.
- Flexible sessions force a gray background. The surround is a separate optional overlay. Legacy profiles still select their configured background. Degree-based sizing and aspect-preserving foreground fitting are additional visual changes since the pushed reference.
- The current consolidation into `flexible_2p('surround',...)` preserves the committed circular-mask algorithm: 18 parameter/background combinations produced exactly the same pixels as the function extracted from HEAD. This equivalence is to HEAD's circular surround; the pushed reference had no surround.

Relevant code: [player preparation](../../SessionStimulusPlayer.m#L32), [foreground scan](../../SessionStimulusPlayer.m#L141), [preview readback](../../SessionStimulusPlayer.m#L179), [surround construction](../../flexible_2p.m#L396), and [draw/flip order](../../engine.m#L2393).

## Tests performed

71 existing MATLAB tests passed: 13 foreground/player tests, 29 engine tests, 21 session tests, 3 eye-tracker tests, and 5 movie-sequencing tests. These use fake hardware where appropriate and cover alpha bounds, fixed movie geometry, caching, simulated missed refreshes, packet retention, and trial/reward timing policy. They are not measurements of physical displays.

The existing `verify_session_media` also passed with 27 real stimuli on both configured displays, checking RGBA retention, backgrounds through transparency, matching preview pixels, resizing, and texture cleanup. Audio-only fixation markers passed on gray, black and white backgrounds. This functional checker deliberately uses small windows with `SkipSyncTests=1`; its timing warnings are expected and its flip timing was not used for performance conclusions.

The separate rendering benchmark used fullscreen subject output, the same half-scale control view as the engine, `SkipSyncTests=0`, priority 1, and actual movie decoding. It used one chair movie, one arena movie and one full-resolution dot movie at two target sizes. Each of five configurations ran for 120 requested subject refreshes per movie and size. The first ten refreshes are excluded from steady-state statistics; all raw samples, including startup, are retained. The chair clip ends before the approximately two-second run and holds its final frame, as the player normally does.

The "legacy" condition reproduces original movie drawing operations (OpenMovie flags 2, nonblocking frame fetch, full source frame, subject draw). It is a simplified rendering baseline, not the entire historical engine. The other configurations call the actual current player. Surround timing uses the same cached mask/drawing primitives at a centered location. Eye sockets, Arduino IO, audio, rewards and imaging acquisition are not exercised by this rendering benchmark. Existing desktop applications remained running.

## Rendering results

CPU wall time for frame preparation, p95, in milliseconds. This includes frame fetching and preview transfers, but GPU drawing can continue after calls return. The late/long-refresh counts are therefore the more direct evidence of display scheduling trouble. The subject refresh budget was approximately 16.674 ms.

| Target size | Movie | Original drawing | Current, subject only | + surround | + preview | + preview + surround | Late refreshes, final column |
|---|---|---:|---:|---:|---:|---:|---:|
| 12° | Chair alpha movie | 2.80 | 2.90 | 3.52 | 6.00 | 6.18 | 0/110 |
| 12° | Arena alpha movie | 3.48 | 3.30 | 3.27 | 5.52 | 6.46 | 0/110 |
| 12° | 2560×1600, 60 fps dots | 8.61 | 8.50 | 8.64 | 12.32 | 12.52 | 0/110 |
| 40° | Chair alpha movie | 2.74 | 4.45 | 2.96 | 11.03 | 11.54 | 0/110 |
| 40° | Arena alpha movie | 4.19 | 3.34 | 3.95 | 12.55 | 12.46 | 0/110 |
| 40° | 2560×1600, 60 fps dots | 8.49 | 9.66 | 9.15 | 16.14 | 16.09 | 26/110 |

At 12°, all 1,650 steady-state refreshes across the fifteen conditions met their requested timing, with no large movie-PTS gaps. Preview increases median preparation by roughly 2–4 ms. Adding the surround typically changes it by much less than one millisecond; individual p95 values vary between these short runs.

At 40°, the dot movie missed 22/110 refreshes with preview and 26/110 with preview plus surround; both also had large movie-PTS gaps. Subject-only dot rendering had no steady-state misses. Thus preview overhead can delay the subject, even though the operator flip is nonblocking, because preview creation and submission execute before the subject flip. Blacking out much of a large stimulus does not eliminate the decoding or preview-copy cost.

Startup is a separate limitation: every clean 12° condition had a late first benchmark refresh (15 total, including the legacy baseline); the 40° runs had 68 late refreshes including startup and 48 after the first ten refreshes. Startup measurements include un-warmed decoder, driver and benchmark setup effects. They are not a measurement of production engine first-onset latency, and should not be discarded when deciding whether onset timing has been established. Raw data include these transients.

An initial exploratory two-repeat run is retained separately. A CPU audit briefly overlapped part of it, and occasional dot misses occurred in both original and current subject-only configurations. The tables above use the subsequent sequential runs, with no concurrent diagnostic CPU benchmark.

## Preparation cost and other processes

Measured first preparation and immediate cached preparation at 12°:

| Movie | First prepare, seconds | Cached prepare, seconds |
|---|---:|---:|
| Chair alpha movie | 2.003 | 0.236 |
| Arena alpha movie | 6.277 | 0.275 |
| 2560×1600, 60 fps dots | 0.166 | 0.170 |

The scan cache lives in the player object and is rebuilt for a new Run/player or changed file; it is not persistent across MATLAB runs. Preparing an unseen alpha movie occurs at the trial boundary before its presentation. Several seconds of preparation can therefore lengthen inter-trial/session timing even when playback is smooth. The session duration estimate does not include that decoding scan. A long arena source is scanned in full even if only a shorter interval will be presented.

The default mask is 786×786 RGBA, 2,471,184.0 bytes (about 2.36 MiB per pixel array). Construction took about 20.5 ms, but happens when parameters/background change, not every playback frame. GPU textures are reused. In legacy movie mode, the existing per-trial `Screen('Close')` also closes surround textures; the engine recreates them from the cached image on a later draw without recalculating the fade.

A 1292×1292 foreground-bound calculation took 0.987 ms per array, in addition to decoding and GPU readback. Old eye parsing took 0.2336 ms versus 0.0032 ms for `sscanf`; recording one packet with the current parser/storage took about 0.0156 ms in this isolated test. These are microbenchmarks, not TCP callback latency measurements. Continuous eye recording adds memory and occasional buffer expansion, but the parser change itself reduced CPU cost in the measured case.

The host has an RTX 2080 Ti (11 GiB), MATLAB R2026a and Psychtoolbox 3.0.18. Before testing the GPU reported about 2% utilization and 799 MiB used. The subject X screen was 2560×1600 at approximately 59.973 Hz; the operator X screen was 1920×1080 at 100 Hz. The existing MATLAB desktop, browser, GNOME and remote-desktop processes remained running. Available host RAM was about 14 GiB. This is a snapshot of this workload, not a worst-case stress test of every existing process.

## Timing limits and next actions

Psychtoolbox reported failed rasterbeam queries on both screens and used fallback timestamping. The control view is windowed and its `dontsync=1` flip returns invalid timestamps by design. The subject USB-C output was reported as disconnected by xrandr despite an active configured mode. Consequently these are GPU/X-screen rendering measurements, not proof of physical light onset on a connected panel. The two refresh rates also do not establish simultaneous subject/operator presentation. No display settings were changed.

There is substantial remaining refresh budget for the sampled small alpha movies, but much less for the normal-size dot movie and too little for the large dot preview. Blocking lickometer/trigger reads, eye callbacks, audio scheduling and acquisition load still share that budget; the rendering test cannot guarantee their combined timing.

The highest-value follow-ups are to precompute and persist alpha foreground geometry before Run, reduce the operator preview resolution or update frequency independently of subject refresh, and capture every subject flip's returned missed-deadline value and interval during a complete session with real IO/audio/acquisition. Prewarm the first frame/preview and validate trigger-to-light onset and duration using the existing photodiode. The current production engine stores frame timestamps but does not retain the flip's fourth (`Missed`) return value.

Psychtoolbox documents the [performance cost of GPU image readback](https://psychtoolbox.org/docs/Screen-GetImage), [movie opening flags](https://psychtoolbox.org/docs/Screen-OpenMovie), and [flip synchronization/timestamps](https://psychtoolbox.org/docs/Screen-Flip).

## Reproduce

From the repository in MATLAB:

```matlab
addpath(fullfile(pwd,'tools'));
benchmark_mask_rendering('/tmp/mask_12.mat',120,2,[12 12]);
benchmark_mask_rendering('/tmp/mask_40.mat',120,2,[40 40]);
verify_session_media();
```

Run while acquisition is idle; the benchmark displays silent stimuli on the configured screens. The benchmark restores the display preferences it changes. Existing production sources and rig configuration were not edited. Raw JSON/MAT results and test logs are stored beside this report.
