import librosa
import numpy as np


def analyze_rhythm(audio_path, start_time=0, end_time=None):

    duration = None

    if end_time is not None:
        duration = end_time - start_time

    y, sr = librosa.load(
        audio_path,
        sr=None,
        offset=start_time,
        duration=duration
    )

    tempo, beats = librosa.beat.beat_track(
        y=y,
        sr=sr
    )

    beat_times = librosa.frames_to_time(
        beats,
        sr=sr
    )

    return {
        "bpm": float(
            tempo[0] if isinstance(tempo, np.ndarray) else tempo
        ),
        "beats": [
            float(t + start_time)
            for t in beat_times
        ]
    }