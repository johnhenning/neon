"""Decode a bounded sample of real footage; motion is not proof of UI success."""
import json
import subprocess


def validate_video(path):
    probe = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
                            '-show_entries', 'format=duration:stream=width,height,codec_name',
                            '-of', 'json', str(path)], check=True, capture_output=True,
                           text=True, timeout=30)
    info = json.loads(probe.stdout)
    stream = info['streams'][0]
    duration = float(info['format']['duration'])
    if duration <= 0 or stream['width'] <= 0 or stream['height'] <= 0:
        raise ValueError('Video has no finite playable dimensions or duration')
    # One sample/second, at most 180 small frames. Decode errors are fatal;
    # sparse frame timestamps and long still holds must not manufacture motion.
    decoded = subprocess.run(['ffmpeg', '-v', 'error', '-xerror', '-i', str(path),
                              '-vf', 'fps=1,scale=64:64,format=gray', '-frames:v', '180',
                              '-f', 'rawvideo', '-'], check=True, capture_output=True, timeout=90)
    size = 64 * 64
    frames = [decoded.stdout[i:i + size] for i in range(0, len(decoded.stdout), size)]
    if any(len(frame) != size for frame in frames):
        raise ValueError('Incomplete decoded sample')
    deltas = [sum(abs(a - b) for a, b in zip(left, right)) / size
              for left, right in zip(frames, frames[1:])]
    changed = sum(delta >= 1.0 for delta in deltas)
    return {'status': 'passed' if changed >= 2 else 'failed',
            'duration_seconds': duration, 'width': stream['width'], 'height': stream['height'],
            'codec': stream['codec_name'], 'sampled_frames': len(frames),
            'changed_transitions': changed, 'max_mean_pixel_delta': max(deltas, default=0),
            'limitations': 'Samples first 180 seconds. Motion alone does not prove app identity or successful interaction.'}
