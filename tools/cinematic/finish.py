"""Encode the authored vertical trailer, teaser and poster with FFmpeg."""
from pathlib import Path
import argparse
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'build/cinematic'
DEST = ROOT / 'videos'
parser = argparse.ArgumentParser()
parser.add_argument('--skip-main', action='store_true')
args = parser.parse_args()
DEST.mkdir(exist_ok=True)
main = DEST / 'orcs-elves-ii-vertical-trailer-en.mp4'
short = DEST / 'orcs-elves-ii-vertical-teaser-en.mp4'
poster = DEST / 'orcs-elves-ii-trailer-poster.png'
codec = ['-c:v', 'libx264', '-preset', 'medium', '-crf', '18', '-pix_fmt', 'yuv420p',
         '-color_range', 'tv', '-color_primaries', 'bt709', '-color_trc', 'bt709',
         '-colorspace', 'bt709', '-c:a', 'aac', '-b:a', '192k', '-ar', '48000',
         '-metadata:s:a:0', 'language=eng', '-movflags', '+faststart']


def ffmpeg(*parts):
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', *map(str, parts)],
                   cwd=ROOT, check=True)


if not args.skip_main:
    ffmpeg('-f', 'image2pipe', '-framerate', '60', '-vcodec', 'mjpeg', '-i', WORK / 'render.mjpeg',
           '-i', WORK / 'mix.wav', '-vf',
           'scale=in_range=pc:out_range=tv:out_color_matrix=bt709,format=yuv420p,'
           'fade=t=in:st=0:d=0.4,fade=t=out:st=46.7:d=0.9,setsar=1',
           '-af', 'loudnorm=I=-16:LRA=9:TP=-1', *codec,
           '-metadata', 'title=Orcs & Elves II - Vertical Trailer', '-shortest', main)

cuts = [(0, 4), (4, 7), (7, 11), (15.8, 19.6), (36.6, 39.6), (43.6, 47.6)]
filters = ['[0:v]split=6' + ''.join(f'[v{i}]' for i in range(6)),
           '[0:a]asplit=6' + ''.join(f'[a{i}]' for i in range(6))]
for i, (start, end) in enumerate(cuts):
    filters.append(f'[v{i}]trim={start}:{end},setpts=PTS-STARTPTS[vv{i}]')
    filters.append(f'[a{i}]atrim={start}:{end},asetpts=PTS-STARTPTS,'
                   f'afade=t=in:d=0.04,afade=t=out:st={end-start-0.04:.3f}:d=0.04[aa{i}]')
filters.append(''.join(f'[vv{i}][aa{i}]' for i in range(6)) + 'concat=n=6:v=1:a=1[v][a]')
ffmpeg('-i', main, '-filter_complex', ';'.join(filters), '-map', '[v]', '-map', '[a]',
       *codec, '-metadata', 'title=Orcs & Elves II - Vertical Teaser', short)
ffmpeg('-ss', '8.3', '-i', main, '-frames:v', '1', poster)

report = {}
for path, seconds in [(main, 47.6), (short, 21.8)]:
    result = subprocess.run(['ffprobe', '-v', 'error', '-count_frames', '-show_streams',
                             '-show_format', '-of', 'json', str(path)],
                            capture_output=True, text=True, check=True)
    data = json.loads(result.stdout)
    video, audio = data['streams']
    assert (video['width'], video['height'], video['r_frame_rate']) == (1080, 1920, '60/1')
    assert video['codec_name'] == 'h264' and video['pix_fmt'] == 'yuv420p'
    assert video['color_range'] == 'tv' and video['color_space'] == 'bt709'
    assert audio['codec_name'] == 'aac' and audio['sample_rate'] == '48000'
    assert abs(float(data['format']['duration']) - seconds) < 0.05
    assert int(video['nb_read_frames']) == round(seconds * 60)
    # Read every frame/sample, including the AAC stream, and reject decode errors.
    ffmpeg('-v', 'error', '-xerror', '-i', path, '-f', 'null', '-')
    report[path.name] = data
(WORK / 'video-verified.json').write_text(json.dumps(report, indent=2))
print('Verified vertical English videos:', ', '.join(report))
