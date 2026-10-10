#!/usr/bin/env python3
"""Inventory stimuli_2p and create a catalog and reproducible PCM tones.
Copy original RGBA chair exports and matching denoised WAVs into the selected
folders, and group face exports by frontal versus other head orientations.
Media are never re-encoded.
"""
import argparse
import array
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import random
import re
import shutil
import subprocess
import sys
import tempfile
import wave


def find_tool(name, explicit):
    candidates = [explicit, shutil.which(name),
                  str(Path.home()/'.pyenv/versions/anaconda3-2020.02/envs/campy/bin'/name)]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            if subprocess.run([candidate, '-version'], stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL).returncode == 0:
                return candidate
    raise RuntimeError('No working '+name+' found; specify --'+name)


def probe(path, ffprobe):
    return json.loads(subprocess.check_output([ffprobe, '-v', 'error', '-show_streams',
                     '-show_format', '-of', 'json', str(path)]))


def atomic_json(path, value):
    temporary = path.with_suffix(path.suffix+'.tmp')
    temporary.write_text(json.dumps(value, indent=2)+'\n')
    temporary.replace(path)


def generate_tones(folder):
    folder.mkdir(exist_ok=True)
    fs, duration, rms, ramp = 96000, 1.5, 0.1, 480
    n = round(fs*duration)
    records = []
    for k in range(14):
        hz = 440*2**(k/2) if k < 13 else 0
        name = 'tone_%09.3fHz.wav' % hz if hz else 'white_noise.wav'
        rng = random.Random(1729)
        values = [math.sqrt(2)*rms*math.sin(2*math.pi*hz*i/fs) if hz else
                  rng.gauss(0, rms) for i in range(n)]
        for i in range(ramp):
            gain = .5-.5*math.cos(math.pi*i/(ramp-1))
            values[i] *= gain
            values[-1-i] *= gain
        data = array.array('h', (round(max(-1,min(1,x))*32767) for x in values))
        if sys.byteorder != 'little':
            data.byteswap()
        target = folder/name
        if not target.exists():
            with wave.open(str(target), 'wb') as f:
                f.setnchannels(1); f.setsampwidth(2); f.setframerate(fs)
                f.writeframes(data.tobytes())
        records.append((target,hz))
    return records


def organize_face_folders(root):
    """Flatten animal folders into two orientation sets, retaining filenames."""
    faces=root/'images/marmfaces_orientations'
    moves=[]
    for path in sorted(faces.rglob('*')):
        if not path.is_file():
            continue
        angle=re.search(r'_head_([+-]?\d+(?:\.\d+)?)deg_',path.name)
        if angle is None:
            continue
        folder='front' if float(angle.group(1))==0 else 'other_orientations'
        target=faces/folder/path.name
        if path==target:
            continue
        if target.exists():
            raise RuntimeError('Cannot regroup faces; destination already exists: '+str(target))
        moves.append((path,target))
    # Check every destination before moving anything. Filenames retain animal IDs.
    targets=[target for _,target in moves]
    if len(set(targets))!=len(targets):
        raise RuntimeError('Duplicate face filenames would collide after regrouping')
    for path,target in moves:
        target.parent.mkdir(parents=True,exist_ok=True)
        path.rename(target)
    for folder in sorted(faces.rglob('*'),key=lambda p:len(p.parts),reverse=True):
        if folder.is_dir() and folder.name not in ['front','other_orientations'] and not any(folder.iterdir()):
            folder.rmdir()
    if moves:
        print('Regrouped',len(moves),'face exports/metadata into front and other_orientations')


def build(root, ffprobe):
    groups, media, warnings, selection_notes = [], [], [], []
    image_count=0
    previous=root/'stimulus_inventory.json'
    if previous.is_file():
        # Keep recovery paths when an idempotent preparation changes no movies.
        selection_notes=[s for s in json.loads(previous.read_text()).get('selection_notes',[])
                         if 'backed up at ' in s]
    def group(name, folder, pattern, kind, timing='shared', mode='V', alpha=True, enabled=False):
        if not any(g['name']==name for g in groups):
            groups.append(dict(name=name, enabled=enabled, modality=mode, timing=timing,
                folder=str(folder.relative_to(root)),pattern=pattern,kind=kind,has_alpha=alpha))
    def video(path, audio=''):
        j=probe(path,ffprobe)
        v=next(s for s in j['streams'] if s['codec_type']=='video')
        # Prefer the visual stream duration over an unrelated container tail.
        fps=eval_fraction(v['avg_frame_rate'])
        tag=v.get('tags',{}).get('DURATION','')
        dur=time_seconds(tag) if tag else float(j['format']['duration'])
        visual_duration=dur
        if audio:
            # The exported WAV covers the complete synchronized master interval.
            # Some MKV duration tags omit the last frame interval (about 24 ms).
            with wave.open(str(audio),'rb') as f:
                dur=max(dur,f.getnframes()/f.getframerate())
        alpha=v.get('tags',{}).get('ALPHA_MODE')=='1' or 'a' in v.get('pix_fmt','') and v.get('pix_fmt') not in ['gray','gray16le']
        media.append(dict(file=str(path.relative_to(root)),codec=v['codec_name'],
                          pixel_format=v.get('pix_fmt'),alpha=alpha,width=v['width'],
                          height=v['height'],fps=fps,duration_s=dur,
                          visual_duration_s=visual_duration,
                          file_bytes=path.stat().st_size,
                          audio_streams=sum(s['codec_type']=='audio' for s in j['streams'])))
        return dur
    organize_face_folders(root)
    # Choose a single unnormalized, refined, source-color export per image identity.
    for path in sorted((root/'images').rglob('*.png')):
        if path.name.endswith('_RGBA_sourcecolor_refinedmask.png') or path.name.endswith('_RGBA_bg-original_refined.png'):
            name = 'faces/'+path.parent.name if 'marmfaces_orientations' in path.parts else path.parent.name
            pattern='*_RGBA_sourcecolor_refinedmask.png' if path.name.endswith('_RGBA_sourcecolor_refinedmask.png') else '*_RGBA_bg-original_refined.png'
            group(name,path.parent,pattern,'image')
            image_count+=1
    chair=root/'videos_AV/chair_exported_4set'
    backup=None
    for folder,name in [('vocalization_phee','phee'),('vocalizations_tisk','tisk')]:
        selected_folder=root/'videos_AV'/folder
        selected=sorted(selected_folder.glob('*'))
        selected=[p for p in selected if p.suffix.lower() in ['.mkv','.mov','.avi','.mp4']]
        group(name,selected_folder,'*_rgba.mkv','movie',timing='chair',mode='AV',enabled=True)
        identities=set()
        for path in selected:
            identity=path.stem.removesuffix('_rgba').removesuffix('_masked')
            if identity in identities:
                raise RuntimeError('More than one selected movie for '+identity)
            identities.add(identity)
            matches=list((chair/'rgba').glob(identity+'_rgba.*'))
            if len(matches)!=1:
                raise RuntimeError('Expected one original RGBA movie for '+identity)
            source=matches[0]
            source_audio=chair/'wav_denoised'/(identity+'_denoised.wav')
            if not source_audio.is_file():
                raise RuntimeError('Missing production denoised WAV: '+str(source_audio))
            visual=selected_folder/source.name
            if path!=visual or hashlib.sha256(path.read_bytes()).digest()!=hashlib.sha256(source.read_bytes()).digest():
                if backup is None:
                    backup=Path(tempfile.mkdtemp(prefix='marmulator_selected_chair_backup_'))
                saved=backup/folder/path.name
                saved.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(path,saved)
                shutil.copy2(source,visual)
                if path!=visual:
                    path.unlink()
                selection_notes.append('Copied original RGBA for '+identity+'; previous selection backed up at '+str(saved))
            audio=selected_folder/source_audio.name
            if not audio.exists() or hashlib.sha256(audio.read_bytes()).digest()!=hashlib.sha256(source_audio.read_bytes()).digest():
                shutil.copy2(source_audio,audio)
            video(visual,audio)
    arena=root/'videos_V/arena_exported_5set/rgba'
    for path in sorted(arena.glob('*.mkv')):
        action=path.name.split('_a-',1)[1].split('_c-',1)[0]
        name='arena/'+action
        group(name,arena,'*_a-'+action+'_*.mkv','movie',timing='actions')
        video(path)
    for name in ['dots','gratings']:
        group(name,root/name,'*.avi','movie',alpha=False)
        for path in sorted((root/name).glob('*.avi')):
            video(path)
    group('tones',root/'tones','*.wav','audio',mode='A',alpha=False)
    tones=generate_tones(root/'tones')
    item_count=image_count+len(media)+len(tones)
    inventory=Counter(str(p.relative_to(root).parent)+' | '+p.suffix.lower()
                      for p in root.rglob('*') if p.is_file() and p.suffix.lower() in ['.mkv','.avi','.png','.wav'])
    catalog=dict(version=2,root=str(root),reward_fraction=.7,background='gray',
        shared=dict(duration_s=1.5,stim_width_deg=12,stim_height_deg=12,
                    fixation_width_deg=6,fixation_height_deg=6,offset_x_deg=0,offset_y_deg=0),
        chair_duration_mode='full',chair_max_duration_s=2.0,actions_duration_s=4.0,groups=groups)
    atomic_json(root/'stimulus_catalog.json',catalog)
    atomic_json(root/'stimulus_inventory.json',dict(counts=dict(sorted(inventory.items())),
                catalog_items=item_count,media=media,warnings=warnings,selection_notes=selection_notes))
    print('Catalog:',len(groups),'sets,',item_count,'items;',len(media),'movie headers inspected')
    print('\n'.join(warnings))


def eval_fraction(value):
    a,b=value.split('/')
    return float(a)/float(b) if float(b) else 0


def time_seconds(value):
    h,m,s=map(float,value.split(':'))
    return h*3600+m*60+s


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',type=Path)
    parser.add_argument('--ffprobe')
    args=parser.parse_args()
    build(args.root.resolve(),find_tool('ffprobe',args.ffprobe))
