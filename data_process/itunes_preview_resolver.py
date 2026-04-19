import requests
import time


def get_itunes_preview_by_isrc(isrc):
    """Try to find preview by ISRC"""
    try:
        url = f"https://itunes.apple.com/search?term={isrc}&entity=song&limit=1"
        response = requests.get(url, timeout=5)
        response.raise_for_status()
        data = response.json()

        if data.get("resultCount", 0) > 0:
            song = data["results"][0]
            return song.get("previewUrl")
        time.sleep(0.5)
    except Exception as e:
        print(f"  ⚠ ISRC lookup failed: {e}")
    return None


def get_itunes_preview_by_artist_song(artist, song_name):
    """Fallback: search by artist + song name (more reliable)"""
    try:
        query = f"{artist} {song_name}"
        url = f"https://itunes.apple.com/search?term={query}&entity=song&limit=5"
        response = requests.get(url, timeout=5)
        response.raise_for_status()
        data = response.json()

        if data.get("resultCount", 0) > 0:
            # Find best match (exact name match preferred)
            for song in data["results"]:
                if song["trackName"].lower() == song_name.lower():
                    return song.get("previewUrl")
            time.sleep(0.5)
            # If no exact match, return first result
            return data["results"][0].get("previewUrl")
    except Exception as e:
        print(f"  ⚠ iTunes artist/song lookup failed: {e}")
    return None


def resolve_preview_url(isrc, artist, song_name):
    # Try ISRC first
    preview = get_itunes_preview_by_isrc(isrc)
    if preview:
        return preview, "itunes_isrc"

    # Fallback to artist + song name
    preview = get_itunes_preview_by_artist_song(artist, song_name)
    if preview:
        return preview, "itunes_artist_song"
    
    return None, None
