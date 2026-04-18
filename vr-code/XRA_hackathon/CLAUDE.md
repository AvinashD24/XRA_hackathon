# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A visionOS (Apple Vision Pro) app that visualizes Spotify playlist tracks as interactive 3D data points in spatial space. The project has two components:

- **vr-code/XRA_hackathon/** — Native visionOS app (SwiftUI + RealityKit)
- **python-code/** — Data pipeline scripts that fetch Spotify tracks and extract audio features, outputting CSV data that drives the 3D visualization

## Build & Run

Open `vr-code/XRA_hackathon/XRA_hackathon.xcodeproj` in Xcode and run on a visionOS simulator or Vision Pro device. There is no CLI build workflow — the project requires Xcode.

```bash
# CLI build (no run)
xcodebuild -project vr-code/XRA_hackathon/XRA_hackathon.xcodeproj -scheme XRA_hackathon build
```

## Architecture

### visionOS App

- **`XRA_hackathonApp.swift`** — Entry point; declares a `WindowGroup` with `.volumetric` style for 3D immersive display
- **`ContentView.swift`** — Main view; renders a `RealityView` scene, handles tap gestures on 3D entities, manages entity scaling state
- **`Packages/RealityKitContent/`** — Swift package containing 3D scene assets; exposes `realityKitContentBundle` for asset loading
- **`Packages/RealityKitContent/Sources/RealityKitContent/RealityKitContent.rkassets/Scene.usda`** — USDA scene definition for the sphere entities (GridMaterial, Collider, InputTarget components)

The app loads a USDA scene via RealityKit, then populates the 3D space with song spheres positioned at x/y/z coordinates derived from audio features. Tap gestures on entities trigger selection/enlargement.

### Python Data Pipeline

The CSV format expected by the app:
```
track_id,x,y,z,title,artist,playback_url,photo_url
```

- **`get_song_ids.py`** — Authenticates with Spotify OAuth, paginates through a playlist, writes `data/track_ids.json`
- **`extract_audio_features.py`** — Reads track IDs, fetches audio features, computes 3D coordinates, outputs CSV

Spotify credentials are read from `spotify_api_keys.json` (gitignored).

### Key Platform Details

- Deployment target: xrOS 26.4
- Swift Package Manager used for `RealityKitContent` (not CocoaPods/Carthage)
- 3D assets use USDZ/USDA format
- `InputTarget` + `Collider` components on entities are required for tap gesture recognition in RealityKit




Project idea: Apple Vision Pro 3d song visualization
use an algorithm to cluster similar songs (can pull a lot of songs using Spotify api)
Show clustering in 3D in user's environment, representing each song as a small sphere
Selecting a song plays it
Can "grab" an area of songs to create a playlist out of those songs
Can grab two areas and bring them together to create a combined playlist

Visualize in user’s environment


CSV Format
track_id,x,y,z,title,artist,playback_url,photo_url

Interface and interactions plan
When the user looks at a song sphere, it highlights the sphere, shows the song name, artist name, album name above it. There is also a play button, which they can click to play the 30sec preview of the song.
Song widget to show the preview that's currently playing, like the image below, that the user can control. Widget will be attached to user’s arm.


Points are colored based on their coordinate. For example, songs on a further x coordinate might be more blue.

Reset button to reset the view to default after user changes it
Users can create playlists which will show up next to the song widget and be attached to their arm as well. Users can scroll through the playlists list if there are too many playlists to fit on their arm. THe users can also scroll through the songs in each playlist, the UI for which will look like spotify’s playlist UI.

How the user grabs a group of songs:
Option 1:
User brings their hands together then pinches outward to create a sphere with their hands as long as they are pinching for, for as far as they drag their hands
All the songs in that sphere get selected. The user then clicks a button that appears above or near the sphere to make that into a playlist
Once the songs are grabbed, user can drag it into a playlist on their arm
User can also drag and drop individual songs into playlists
Trash can icon on their arm to drag and drop playlists and songs from playlists into if they want to delete them

If time:
Search bar to search songs by name, like on spotify. Clicking a song navigates to it and zooms into the location of that song and highlights the song’s sphere.

Development
Using realitykit with XCode and any other tools necessary
