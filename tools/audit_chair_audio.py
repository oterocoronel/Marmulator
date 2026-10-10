#!/usr/bin/env python3
"""Compare the selected chair movies with production raw and denoised audio.

Decode to PCM16 without resampling. Exact sample-prefix equality establishes
that the movie uses the denoised export with no sample offset; differing
lengths are reported separately. No source files are modified.
"""
import argparse
import array
import json
import math
from pathlib import Path
import subprocess
import sys
import wave

sys.dont_write_bytecode = True
from prepare_stimuli import atomic_json, find_tool, probe


def decode(path, ffmpeg):
    data = subprocess.check_output([ffmpeg, '-v', 'error', '-i', str(path),
        '-map', '0:a:0', '-vn', '-acodec', 'pcm_s16le', '-f', 's16le', '-'])
    samples = array.array('h')
    samples.frombytes(data)
    if sys.byteorder != 'little':
        samples.byteswap()
    return samples


def compare(a, b):
    n = min(len(a), len(b))
    if n == 0:
        raise RuntimeError('Cannot compare an empty audio track')
    diff = [int(a[i])-int(b[i]) for i in range(n)]
    return dict(samples_a=len(a), samples_b=len(b), same_length=len(a)==len(b),
        overlap_exact=not any(diff), max_abs_difference=max(abs(d) for d in diff)/32768,
        rms_difference=math.sqrt(sum(d*d for d in diff)/n)/32768)


def levels(samples):
    return dict(peak=max(abs(s) for s in samples)/32768,
                rms=math.sqrt(sum(s*s for s in samples)/len(samples))/32768)


def annotation_end(params):
    values = {}
    for line in params.read_text().splitlines():
        key, separator, value = line.partition(' = ')
        if separator and key in ['vocalization.audio_start_s',
                                  'vocalization.vocalization_call_intervals_json']:
            values[key] = json.loads(value)
    if len(values) != 2:
        return None
    intervals = json.loads(values['vocalization.vocalization_call_intervals_json'])
    return max(c['end_s'] for c in intervals)-float(values['vocalization.audio_start_s'])


def audit(root, ffmpeg, ffprobe):
    catalog = json.loads((root/'stimulus_catalog.json').read_text())
    chair = root/'videos_AV/chair_exported_4set'
    rows = []
    items=[]
    for group in catalog['groups']:
        if group['timing']=='chair':
            for movie in sorted((root/group['folder']).glob(group['pattern'])):
                identity=movie.stem.removesuffix('_rgba')
                audio=movie.parent/(identity+'_denoised.wav')
                items.append(dict(visual_file=str(movie.relative_to(root)),
                    audio_file=str(audio.relative_to(root)),set_name=group['name']))
    for item in items:
        identity = Path(item['visual_file']).stem.removesuffix('_rgba')
        movie = root/item['visual_file']
        denoised = root/item['audio_file']
        raw = chair/'wav_raw'/(identity+'_raw.wav')
        streams = probe(movie, ffprobe)['streams']
        audio = next(s for s in streams if s['codec_type']=='audio')
        rate, channels = int(audio['sample_rate']), int(audio['channels'])
        for path in [denoised, raw]:
            with wave.open(str(path), 'rb') as wav:
                if (wav.getframerate(), wav.getnchannels()) != (rate, channels):
                    raise RuntimeError('Sample format mismatch: '+str(path))
        a, b, c = (decode(p, ffmpeg) for p in [movie, denoised, raw])
        last_call = annotation_end(chair/'params'/(identity+'_params.txt'))
        original = chair/'rgba'/(identity+'_rgba.mkv')
        row = dict(id=identity, movie_file=item['visual_file'], denoised_file=item['audio_file'],
            sample_rate=rate, channels=channels, start_time=audio.get('start_time'),
            embedded_vs_denoised=compare(a,b), embedded_vs_raw=compare(a,c),
            embedded_levels=levels(a), denoised_levels=levels(b),
            embedded_missing_tail_ms=max(0,len(b)-len(a))*1000/(rate*channels),
            annotated_last_call_end_s=last_call,
            embedded_padding_after_last_call_s=(len(a)/(rate*channels)-last_call)
                if last_call is not None else None)
        if original.is_file():
            row['original_vs_selected_embedded']=compare(decode(original,ffmpeg),a)
        rows.append(row)
    atomic_json(root/'chair_audio_audit.json', rows)
    exact = sum(r['embedded_vs_denoised']['overlap_exact'] for r in rows)
    short = [r['embedded_missing_tail_ms'] for r in rows if r['embedded_missing_tail_ms']>0]
    print(f'{exact}/{len(rows)} embedded tracks exactly match their denoised WAV prefixes.')
    if short:
        print(f'{len(short)} embedded tracks are shorter by {min(short):.3f}–{max(short):.3f} ms.')
    if exact != len(rows) or not rows:
        raise RuntimeError('Some embedded audio does not match the denoised export; inspect chair_audio_audit.json')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',type=Path)
    parser.add_argument('--ffprobe')
    parser.add_argument('--ffmpeg')
    args=parser.parse_args()
    audit(args.root.resolve(),find_tool('ffmpeg',args.ffmpeg),find_tool('ffprobe',args.ffprobe))
