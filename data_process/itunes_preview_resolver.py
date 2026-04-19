import requests
import time
import os
import json


# In-memory cache for this session
_itunes_cache = {}

# Persistent cache file path
CACHE_FILE = "data/itunes_preview_cache.json"


def load_persistent_cache():
    """Load iTunes preview cache from JSON file"""
    global _itunes_cache
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                _itunes_cache = json.load(f)
                print(f"✓ Loaded {len(_itunes_cache)} cached previews from {CACHE_FILE}\n")
        except Exception as e:
            print(f"⚠ Failed to load cache: {e}\n")
            _itunes_cache = {}
    return _itunes_cache


def save_persistent_cache():
    """Save iTunes preview cache to JSON file"""
    try:
        os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
        with open(CACHE_FILE, "w") as f:
            json.dump(_itunes_cache, f, indent=2)
    except Exception as e:
        print(f"⚠ Failed to save cache: {e}")


def get_cache_key(artist, song_name):
    """Generate consistent cache key"""
    return f"{artist.lower()}||{song_name.lower()}"


def get_itunes_preview_by_artist_song(artist, song_name, max_retries=3):
    """
    Search iTunes by artist + song name with exponential backoff rate limit handling
    Checks cache first before querying API.

    Returns: preview_url or None
    """
    cache_key = get_cache_key(artist, song_name)

    # Check cache first
    if cache_key in _itunes_cache:
        cached_url = _itunes_cache[cache_key]
        if cached_url:
            print(f"  ✓ Cache hit for {artist} - {song_name}")
        return cached_url

    # Not in cache, query iTunes
    query = f"{artist} {song_name}"
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            url = f"https://itunes.apple.com/search?term={query}&entity=song&limit=5"
            response = requests.get(url, timeout=5)
            
            # Handle rate limiting (HTTP 429)
            if response.status_code == 429:
                wait_time = 60 * (2 ** retry_count)  # Exponential backoff: 60s, 120s, 240s
                print(f"  ⚠ Rate limited! Waiting {wait_time} seconds before retry...")
                time.sleep(wait_time)
                retry_count += 1
                continue
            
            response.raise_for_status()
            data = response.json()

            preview_url = None
            if data.get("resultCount", 0) > 0:
                # Find best match (exact name match preferred)
                for song in data["results"]:
                    if song["trackName"].lower() == song_name.lower():
                        preview_url = song.get("previewUrl")
                        break

                # If no exact match, return first result
                if not preview_url:
                    preview_url = data["results"][0].get("previewUrl")

            # Cache the result (even if None)
            _itunes_cache[cache_key] = preview_url
            save_persistent_cache()

            return preview_url

        except requests.exceptions.RequestException as e:
            print(f"  ⚠ iTunes lookup failed: {e}")
            # Cache the failure (None)
            _itunes_cache[cache_key] = None
            save_persistent_cache()
            return None

    print(f"  ⚠ Max retries exceeded for iTunes lookup")
    # Cache the failure
    _itunes_cache[cache_key] = None
    save_persistent_cache()
    return None


def resolve_preview_url(artist, song_name):
    """
    Resolve preview URL by artist + song name with rate limit handling and caching

    Returns: preview_url or None
    """
    return get_itunes_preview_by_artist_song(artist, song_name)
