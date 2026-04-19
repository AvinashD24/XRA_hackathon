import requests
import pandas as pd
import time
import os
from data_process.spotify_api_auth import access_token
from data_process.itunes_preview_resolver import resolve_preview_url


def load_existing_results(output_file):
    """Load existing results from CSV to avoid re-querying"""
    if os.path.exists(output_file):
        df = pd.read_csv(output_file)
        # Return dict of track_id -> preview_url for tracks that have previews
        existing = {}
        for _, row in df.iterrows():
            track_id = row.get("track_id")
            preview_url = row.get("preview_url")
            if pd.notna(preview_url) and preview_url:
                existing[track_id] = preview_url
        return existing
    return {}


def fetch_track_metadata(token, track_ids, existing_previews=None):
    """Fetch track metadata, skipping tracks with existing previews"""
    if existing_previews is None:
        existing_previews = {}
    
    headers = {"Authorization": f"Bearer {token}"}
    results = {}
    queried_count = 0

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
            
            # Use cached preview if available
            if track_id in existing_previews:
                preview_url = existing_previews[track_id]
                print(f"  ✓ Using cached preview for {t['name']}")
            # Try iTunes fallback if Spotify preview is None
            elif not preview_url:
                queried_count += 1
                print(f"  → Spotify preview missing for {t['name']}, trying iTunes...")
                preview_url, source = resolve_preview_url(artists, t["name"])
                if preview_url:
                    print(f"    ✔ Found via {source}")
                else:
                    print(f"    ✗ No preview found on iTunes")
            
            results[track_id] = {
                "title": t["name"],
                "artists": artists,
                "preview_url": preview_url,
                "album_image": (
                    t["album"]["images"][0]["url"]
                    if t["album"]["images"] else None
                )
            }

            time.sleep(0.05)  # Small delay between queries

    print(f"\n✔ Total iTunes queries made: {queried_count}")
    return results

df = pd.read_csv("data/reduced_dim.csv")

track_ids = df["track_id"].tolist()

output_file = "data/final_data2.csv"

# Load existing results to avoid re-querying
existing_previews = load_existing_results(output_file)
print(f"✓ Found {len(existing_previews)} tracks with existing previews\n")

meta = fetch_track_metadata(access_token, track_ids, existing_previews)

meta_df = pd.DataFrame.from_dict(meta, orient="index")
meta_df.index.name = "track_id"
df_final = df.set_index("track_id").join(meta_df)
df_final = df_final.reset_index()
df_final.to_csv(output_file, index=False)

print(f"\n✔ Results saved to {output_file}")