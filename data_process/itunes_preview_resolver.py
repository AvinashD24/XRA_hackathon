import requests
import time


def get_itunes_preview_by_artist_song(artist, song_name, max_retries=3):
    """
    Search iTunes by artist + song name with exponential backoff rate limit handling
    
    Returns: (preview_url, source) or (None, None)
    """
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

            if data.get("resultCount", 0) > 0:
                # Find best match (exact name match preferred)
                for song in data["results"]:
                    if song["trackName"].lower() == song_name.lower():
                        return song.get("previewUrl"), "itunes_artist_song"
                
                # If no exact match, return first result
                return data["results"][0].get("previewUrl"), "itunes_artist_song"
            
            return None, None
            
        except requests.exceptions.RequestException as e:
            print(f"  ⚠ iTunes lookup failed: {e}")
            return None, None
    
    print(f"  ⚠ Max retries exceeded for iTunes lookup")
    return None, None


def resolve_preview_url(artist, song_name):
    """
    Resolve preview URL by artist + song name with rate limit handling
    
    Returns: (preview_url, source) or (None, None)
    """
    return get_itunes_preview_by_artist_song(artist, song_name)
