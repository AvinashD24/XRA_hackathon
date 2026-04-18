import pandas as pd
import json

with open("data/track_ids.json", "r") as f:
    playlist_track_ids = json.load(f)
playlist_track_ids = pd.DataFrame(playlist_track_ids)
print(playlist_track_ids)   