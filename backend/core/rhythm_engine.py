import librosa
import numpy as np

def analyze_rhythm(audio_path):
    y, sr = librosa.load(audio_path, sr=None)
    tempo, beats = librosa.beat.beat_track(y=y, sr=sr)
    beat_times = librosa.frames_to_time(beats, sr=sr)
    
    return {
        "bpm": float(tempo[0] if isinstance(tempo, np.ndarray) else tempo),
        "beats": [float(t) for t in beat_times]
    }
