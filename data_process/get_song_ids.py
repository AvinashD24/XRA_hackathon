import json
import requests
import argparse
from data_process.spotify_api_auth import access_token

DEFAULT_PLAYLIST_ID = "1gt20k87aquS2gUT1Y8gzQ"

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


def main():
    parser = argparse.ArgumentParser(description="Fetch Spotify playlist track IDs")

    parser.add_argument(
        "--playlist_id",
        type=str,
        default=DEFAULT_PLAYLIST_ID,
        help="Spotify playlist ID (default: hardcoded playlist)"
    )

    parser.add_argument(
        "--output",
        type=str,
        default="data/track_ids.json",
        help="Output JSON file path"
    )

    args = parser.parse_args()

    print(f"Using playlist: {args.playlist_id}")

    playlist_track_ids = get_playlist_track_ids(
        access_token,
        args.playlist_id
    )

    with open(args.output, "w") as f:
        json.dump(playlist_track_ids, f, indent=4)

    print(f"Saved {len(playlist_track_ids)} tracks -> {args.output}")


if __name__ == "__main__":
    main()