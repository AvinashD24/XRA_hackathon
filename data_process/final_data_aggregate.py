import requests
import pandas as pd
import time
from data_process.spotify_api_auth import access_token
from data_process.itunes_preview_resolver import resolve_preview_url


def fetch_track_metadata(token, track_ids):
    headers = {"Authorization": f"Bearer {token}"}

    results = {}

    for i in range(0, len(track_ids), 50):
        batch = track_ids[i:i+50]
        ids = ",".join(batch)
        print(f"Processing Batch From {i} -> {i+50}")

        url = f"https://api.spotify.com/v1/tracks?ids={ids}"
        r = requests.get(url, headers=headers)
        r.raise_for_status()

        data = r.json()["tracks"]

        for t in data:
            if not t:
                continue

            track_id = t["id"]
            artists = ", ".join([a["name"] for a in t["artists"]])
            preview_url = t["preview_url"]
            isrc = t['external_ids'].get("isrc")

            # Try iTunes fallback if Spotify preview is None
            if not preview_url and isrc:
                print(f"  → Spotify preview missing for {t['name']}, trying iTunes...")
                preview_url, source = resolve_preview_url(isrc, artists, t["name"])
                if preview_url:
                    print(f"    ✔ Found via {source}")
            
            results[track_id] = {
                "title": t["name"],
                "artists": artists,
                "isrc": isrc,
                "preview_url": preview_url,
                "album_image": (
                    t["album"]["images"][0]["url"]
                    if t["album"]["images"] else None
                )
            }

            time.sleep(0.1)  # Rate limiting for iTunes API

    return results

df = pd.read_csv("data/reduced_dim.csv")

track_ids = df["track_id"].tolist()

meta = fetch_track_metadata(access_token, track_ids)

meta_df = pd.DataFrame.from_dict(meta, orient="index")
meta_df.index.name = "track_id"
df_final = df.set_index("track_id").join(meta_df)
df_final = df_final.reset_index()
df_final.to_csv("../data/final_data2.csv", index=False)