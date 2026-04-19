import json
import pandas as pd
import os

# Load iTunes cache
cache_file = "data/itunes_preview_cache.json"
csv_file = "data/final_data.csv"
output_file = "data/final_data.csv"

print(f"Loading iTunes cache from {cache_file}...")
with open(cache_file, "r") as f:
    itunes_cache = json.load(f)

print(f"✓ Loaded {len(itunes_cache)} cached preview URLs\n")

# Load final_data.csv
print(f"Loading CSV from {csv_file}...")
df = pd.read_csv(csv_file)
print(f"✓ Loaded {len(df)} rows\n")

# Track matches
matches = 0
no_match = 0

print("Matching cache entries with CSV rows...\n")

# Iterate through each row and try to find a match in the cache
for idx, row in df.iterrows():
    if pd.isna(row['preview_url']) or row['preview_url'] == '':
        # Try to find a match in the cache
        artists = row['artists'].lower()
        title = row['title'].lower()
        
        # Try exact match first
        cache_key = f"{artists}||{title}"
        if cache_key in itunes_cache:
            preview_url = itunes_cache[cache_key]
            if preview_url:
                df.at[idx, 'preview_url'] = preview_url
                matches += 1
                print(f"✓ Match: {row['artists']} - {row['title']}")
            else:
                no_match += 1
        else:
            # Try to find by title alone (in case artists differ slightly)
            found = False
            for key, value in itunes_cache.items():
                cache_title = key.split("||")[1] if "||" in key else key
                if cache_title == title and value:
                    df.at[idx, 'preview_url'] = value
                    matches += 1
                    print(f"✓ Match (title only): {row['artists']} - {row['title']}")
                    found = True
                    break
            
            if not found:
                no_match += 1

print(f"\n{'='*60}")
print(f"Results:")
print(f"{'='*60}")
print(f"✓ Matched and populated: {matches}")
print(f"✗ No preview found in cache: {no_match}")
print(f"{'='*60}\n")

# Save updated CSV
print(f"Saving updated CSV to {output_file}...")
df.to_csv(output_file, index=False)
print(f"✓ Done!")
