import http
import time

import pandas as pd
import json
import requests

from data_process.spotify_api_auth import access_token

def fetch_batch(track_ids):
    conn = http.client.HTTPSConnection("api.reccobeats.com")

    ids_str = ",".join(track_ids[:40])

    conn.request(
        "GET",
        f"/v1/audio-features?ids={ids_str}",
        headers={"Accept": "application/json"}
    )

    res = conn.getresponse()
    data = res.read()

    response = json.loads(data.decode("utf-8"))

    result = {}

    for item in response.get("content", []):
        spotify_id = item["href"].split("/")[-1]

        result[spotify_id] = {
            "acousticness": item.get("acousticness"),
            "danceability": item.get("danceability"),
            "energy": item.get("energy"),
            "instrumentalness": item.get("instrumentalness"),
            "key": item.get("key"),
            "liveness": item.get("liveness"),
            "loudness": item.get("loudness"),
            "mode": item.get("mode"),
            "speechiness": item.get("speechiness"),
            "tempo": item.get("tempo"),
            "valence": item.get("valence")
        }

    return result

def fetch_all(track_ids, batch_size=40):
    all_results = {}

    for i in range(0, len(track_ids), batch_size):
        batch = track_ids[i:i+batch_size]

        print(f"Fetching batch {i} -> {i+len(batch)}")

        batch_result = fetch_batch(batch)

        all_results.update(batch_result)

        time.sleep(0.5)

    return all_results

def fetch_audio_features(token, track_ids):
    fetch_results = fetch_all(track_ids)

    df = pd.DataFrame.from_dict(fetch_results, orient="index")
    df.index.name = "track_id"

    return df
with open("data/track_ids.json", "r") as f:
    playlist_track_ids = json.load(f)
data_features = fetch_audio_features(access_token, playlist_track_ids)
data_features.to_csv("../data/audio_features.csv", index=True)
print(data_features.head())