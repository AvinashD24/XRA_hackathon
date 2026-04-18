import requests
import pandas as pd
from data_process.spotify_api_auth import access_token

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

            results[track_id] = {
                "title": t["name"],
                "artists": artists,
                "isrc": t['external_ids']["isrc"] if "isrc" in t['external_ids'] else None,
                "preview_url": t["preview_url"],
                "album_image": (
                    t["album"]["images"][0]["url"]
                    if t["album"]["images"] else None
                )
            }

    return results

df = pd.read_csv("data/reduced_dim.csv")

track_ids = df["track_id"].tolist()

meta = fetch_track_metadata(access_token, track_ids)

meta_df = pd.DataFrame.from_dict(meta, orient="index")
meta_df.index.name = "track_id"
df_final = df.set_index("track_id").join(meta_df)
df_final = df_final.reset_index()
df_final.to_csv("data/final_data2.csv", index=False)