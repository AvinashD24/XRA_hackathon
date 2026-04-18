import base64
import json

import requests


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

with open("spotify_api_keys.json") as file:
    config = json.load(file)
client_id = config["client_id"]
client_secret = config["client_secret"]
access_token = get_access_token()