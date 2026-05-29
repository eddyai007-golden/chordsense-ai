import librosa
import numpy as np
from scipy.ndimage import median_filter

def get_chord_templates():
    # Basic
    maj = [1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0]
    min_ = [1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0]
    dom7 = [1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0]
    maj7 = [1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1]
    min7 = [1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0]
    
    # 9ths
    maj9 = [1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1]
    min9 = [1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1, 0]
    dom9 = [1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0]
    
    # 11ths
    maj11 = [1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1]
    min11 = [1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0]
    dom11 = [1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0]
    
    # Altered
    dom7sharp9 = [1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0]
    dom7flat9 = [1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0]
    dom7sharp5 = [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0]
    dom7flat5 = [1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0]
    dim7 = [1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0]
    m7b5 = [1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0]

    names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    
    chord_definitions = [
        ('', maj), ('m', min_), ('7', dom7), ('maj7', maj7), ('m7', min7),
        ('maj9', maj9), ('m9', min9), ('9', dom9),
        ('maj11', maj11), ('m11', min11), ('11', dom11),
        ('7#9', dom7sharp9), ('7b9', dom7flat9), ('7#5', dom7sharp5), ('7b5', dom7flat5),
        ('dim7', dim7), ('m7b5', m7b5)
    ]

    all_templates = []
    labels = []
    chord_metadata = []

    for i, root in enumerate(names):
        for suffix, template in chord_definitions:
            shifted_template = np.roll(template, i)
            all_templates.append(shifted_template)
            labels.append(f"{root}{suffix}")
            chord_metadata.append({'root_idx': i, 'root_name': root, 'suffix': suffix})
            
    all_templates.append(np.zeros(12))
    labels.append("N")
    chord_metadata.append({'root_idx': -1, 'root_name': 'N', 'suffix': ''})
    
    return np.array(all_templates), labels, chord_metadata

def resolve_rootless_voicings(chord_label, bass_idx, metadata, names):
    if bass_idx == -1 or chord_label == "N":
        return chord_label
        
    root_idx = metadata['root_idx']
    suffix = metadata['suffix']
    bass_name = names[bass_idx]
    
    if bass_idx != root_idx:
        interval = (root_idx - bass_idx) % 12
        if interval == 4 and suffix == 'm7': return f"{bass_name}maj9"
        if interval == 4 and suffix == 'm7b5': return f"{bass_name}9"
        if interval == 4 and suffix == 'dim7': return f"{bass_name}7b9"
        if interval == 10 and suffix == 'maj7': return f"{bass_name}11"
        if interval == 7 and suffix == 'm7': return f"{bass_name}11"
        return f"{chord_label}/{bass_name}"
        
    return chord_label

def analyze_chords(audio_path):
    y, sr = librosa.load(audio_path, sr=None)
    
    chroma = librosa.feature.chroma_cqt(y=y, sr=sr, hop_length=512)
    chroma = librosa.util.normalize(chroma, axis=0)
    
    try:
        y_harmonic, _ = librosa.effects.hpss(y)
        cqt_bass = np.abs(librosa.cqt(y_harmonic, sr=sr, hop_length=512, fmin=librosa.note_to_hz('C1'), n_bins=36))
        chroma_bass = np.zeros((12, cqt_bass.shape[1]))
        for i in range(36):
            chroma_bass[i % 12, :] += cqt_bass[i, :]
        chroma_bass = librosa.util.normalize(chroma_bass, axis=0)
        bass_matches = np.argmax(chroma_bass, axis=0)
    except Exception:
        bass_matches = np.argmax(chroma, axis=0)
    
    templates, labels, metadata_list = get_chord_templates()
    
    correlations = np.dot(templates, chroma)
    best_matches = np.argmax(correlations, axis=0)
    
    smoothed_matches = median_filter(best_matches, size=15)
    smoothed_bass = median_filter(bass_matches, size=15)
    
    times = librosa.frames_to_time(np.arange(len(smoothed_matches)), sr=sr, hop_length=512)
    names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    
    results = []
    for i in range(len(smoothed_matches)):
        match_idx = smoothed_matches[i]
        bass_idx = smoothed_bass[i]
        base_chord = labels[match_idx]
        metadata = metadata_list[match_idx]
        
        final_chord = resolve_rootless_voicings(base_chord, bass_idx, metadata, names)
        
        results.append({
            "time": float(times[i]),
            "chord": final_chord
        })
        
    return results
