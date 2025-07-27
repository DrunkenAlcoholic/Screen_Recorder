# Desktop Screen Recorder

A straightforward bash script for recording your desktop with separate audio tracks. I wrote this because I needed a simple way to record screencasts and edit the audio separately afterward.

## What it does

This script records a specific area of your screen (or the whole thing) while capturing audio to a separate file. The main benefit is that you get clean audio tracks that you can edit in Audacity or whatever audio editor you prefer, then recombine them with the video later.

The script handles the tedious stuff like detecting your screen resolution, centering the capture area, and making sure everything fits within your screen boundaries.

## Requirements

You'll need these installed:

- ffmpeg (for the actual recording)
- PulseAudio (for audio capture)
- xrandr or wlr-randr (depending on whether you're using X11 or Wayland)

The script checks for these when you run it, so don't worry about remembering.

## Basic usage

Make the script executable first:

```bash
chmod +x record_desktop.sh
```

Then just run it:

```bash
./record_desktop.sh
```

This records a 1920x1080 area in the center of your screen until you press 'q' to stop.

## Useful examples

Record a specific size for 10 minutes:
```bash
./record_desktop.sh -W 1280 -H 720 -d 600
```

Record from a specific position on screen:
```bash
./record_desktop.sh -x 100 -y 50 -W 1600 -H 900
```

If you have multiple monitors, list them first:
```bash
./record_desktop.sh --list-monitors
```

Then record from monitor 1:
```bash
./record_desktop.sh -m 1
```

Check what audio devices are available:
```bash
./record_desktop.sh --list-devices
```

Set a custom project name:
```bash
./record_desktop.sh -o "my_tutorial_video"
```

## Command line options

```
--help                  Show help
-o, --output NAME       Project folder name (default: recording_TIMESTAMP)
-x, --x-offset PIXELS   Where to start recording horizontally
-y, --y-offset PIXELS   Where to start recording vertically  
-W, --width PIXELS      Width of recording area (default: 1920)
-H, --height PIXELS     Height of recording area (default: 1080)
-d, --duration SECONDS  How long to record (default: until you stop it)
-f, --fps NUMBER        Frame rate (default: 30)
-a, --audio DEVICE      Which audio input to use
-m, --monitor NUMBER    Which monitor to record from
-l, --list-devices      List available audio inputs
--list-monitors         List available monitors
```

## What you get

The script creates a folder with these files:

- `screen_recording.mkv` - Your main video file
- `screen_recording_audio.flac` - High quality audio for editing

## Editing workflow

Here's how I typically use this:

1. Record with the script
2. Open the .flac file in Audacity
3. Clean up the audio (noise reduction, normalization, etc.)  
4. Export as .wav file named `screen_recording_edited.wav`
5. Use the ffmpeg command the script prints out to combine everything

The script gives you the exact ffmpeg commands you need. For a basic YouTube upload:

```bash
ffmpeg -i "your_folder/screen_recording.mkv" -i "your_folder/screen_recording_edited.wav" \
  -map 0:v -map 1:a -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -ar 48000 -movflags +faststart \
  "your_folder/screen_recording_youtube.mp4"
```

If you need to trim the video at the same time:

```bash
ffmpeg -i "your_folder/screen_recording.mkv" -i "your_folder/screen_recording_edited.wav" \
  -map 0:v -map 1:a -ss 00:00:10 -t 00:05:00 \
  -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -ar 48000 -movflags +faststart \
  "your_folder/screen_recording_final.mp4"
```

## Common issues

**Audio not working**: Make sure PulseAudio is running. Try `pulseaudio --check` and if that fails, restart it with `pulseaudio -k && pulseaudio --start`.

**Can't detect screen size**: The script tries several methods to detect your screen. If it fails, it defaults to 1920x1080. You can override this with the -W and -H options.

**Recording area goes off screen**: The script should catch this and adjust automatically, but if something seems wrong, double-check your -x, -y, -w, and -H values.

**Multiple monitors acting weird**: Use `--list-monitors` to see what's available, then specify which one with `-m`.

## Why I made this

I got tired of using screen recording software that either didn't give me separate audio tracks or was overkill for simple screencasts. This does exactly what I need: records the screen, captures audio separately, and gets out of my way.

The separate audio track is really the key feature here. You can clean up audio issues, add background music, or just get better compression without affecting your video quality.

## License

MIT License. Do whatever you want with it.