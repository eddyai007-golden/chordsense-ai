from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
import os
import sys

# Ensure core is in path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from core.chord_engine import analyze_chords
from core.rhythm_engine import analyze_rhythm

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"message": "ChordSense AI Backend is running"}

@app.post("/analyze/file")
async def analyze_file(file: UploadFile = File(...)):
    # Save file temporarily
    file_location = f"temp_{file.filename}"
    with open(file_location, "wb+") as file_object:
        file_object.write(file.file.read())
    
    # Process audio
    try:
        chords = analyze_chords(file_location)
        rhythm = analyze_rhythm(file_location)
    except Exception as e:
        os.remove(file_location)
        return {"error": str(e)}
    
    os.remove(file_location)
    
    # Simple compression for chord timeline to avoid sending huge arrays
    compressed_chords = []
    if chords:
        current_chord = chords[0]["chord"]
        start_time = chords[0]["time"]
        for i in range(1, len(chords)):
            if chords[i]["chord"] != current_chord:
                compressed_chords.append({
                    "chord": current_chord,
                    "start_time": start_time,
                    "end_time": chords[i-1]["time"]
                })
                current_chord = chords[i]["chord"]
                start_time = chords[i]["time"]
        compressed_chords.append({
            "chord": current_chord,
            "start_time": start_time,
            "end_time": chords[-1]["time"]
        })
    
    return {"chords": compressed_chords, "rhythm": rhythm}
