# This is a sample Python script.
import base64
import configparser
# Press ⌃R to execute it or replace it with your code.
# Press Double ⇧ to search everywhere for classes, files, tool windows, actions, and settings.

# extract song ids from playlist id, given user specs
import json

import requests

with open("spotify_api_keys.json") as file:
    config = json.load(file)
client_id = config["client_id"]
client_secret = config["client_secret"]

# TODO make this user interactive via OAuth key
# for now we will hardcode to a playlist
playlist_id = "34Osh0el1mRoK5KBZ5rIcm"


def get_access_token():
    url = "https://accounts.spotify.com/api/token"
    headers = {
        "Authorization": "Basic " + base64.b64encode(
            f"{client_id}:{client_secret}".encode()
        ).decode()
    }
    data = {
        "grant_type": "client_credentials"
    }

    response = requests.post(url, headers=headers, data=data)
    response.raise_for_status()
    return response.json()["access_token"]


def get_playlist_track_ids(token, playlist_id):
    url = f"https://api.spotify.com/v1/playlists/{playlist_id}/tracks"
    headers = {
        "Authorization": f"Bearer {token}"
    }

    track_ids = []

    while url:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        data = response.json()

        for item in data["items"]:
            track = item.get("track")
            if track and track.get("id"):
                track_ids.append(track["id"])

        url = data.get("next")  # pagination

    return track_ids

access_token = get_access_token()
playlist_track_ids = get_playlist_track_ids(access_token, playlist_id)
with open("data/track_ids.json", "w") as f:
    json.dump(playlist_track_ids, f, indent=4)