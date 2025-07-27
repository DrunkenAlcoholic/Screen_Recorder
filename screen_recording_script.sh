#!/bin/bash

# Script to record a specific region of the desktop
# Creates video with separate audio file for easy editing

# Default settings
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PROJECT_NAME="recording_$TIMESTAMP"
OUTPUT_DIR="$(pwd)/$PROJECT_NAME"
OUTPUT_NAME="screen_recording"
CAPTURE_WIDTH=1920
CAPTURE_HEIGHT=1080
FPS=30
AUDIO_DEVICE="default"
DURATION=0  # 0 means record until stopped

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v ffmpeg >/dev/null 2>&1; then
        missing_deps+=("ffmpeg")
    fi
    
    # Check for audio system
    if ! command -v pactl >/dev/null 2>&1 && ! command -v pulseaudio >/dev/null 2>&1; then
        echo "Warning: PulseAudio not detected. Audio recording may not work."
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}"
        echo "Please install them before running this script."
        exit 1
    fi
}

# Function to display usage information
show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --help                  Show this help message"
    echo "  -o, --output NAME       Set project folder name (default: recording_TIMESTAMP)"
    echo "  -x, --x-offset PIXELS   Set X offset for capture region (default: centered)"
    echo "  -y, --y-offset PIXELS   Set Y offset for capture region (default: centered)"
    echo "  -W, --width PIXELS      Set capture width (default: 1920, max: screen width)"
    echo "  -H, --height PIXELS     Set capture height (default: 1080, max: screen height)"
    echo "  -d, --duration SECONDS  Set recording duration (default: until stopped with Ctrl+C)"
    echo "  -f, --fps NUMBER        Set frames per second (default: 30)"
    echo "  -a, --audio DEVICE      Set audio input device (default: default)"
    echo "  -l, --list-devices      List available audio input devices"
    echo "  -m, --monitor NUMBER    Select monitor for multi-monitor setups (default: primary)"
    echo ""
    echo "Press q to stop recording if no duration is specified."
}

# Function to list audio devices
list_audio_devices() {
    echo "Available audio input devices:"
    if command -v pactl >/dev/null 2>&1; then
        pactl list sources short
    else
        ffmpeg -hide_banner -sources pulse 2>&1 | grep "pulse" | grep -v "alsa" 2>/dev/null || echo "Could not detect audio devices"
    fi
}

# Function to list monitors
list_monitors() {
    echo "Available monitors:"
    if command -v xrandr >/dev/null 2>&1; then
        xrandr --current | grep ' connected' | nl -v0
    elif command -v wlr-randr >/dev/null 2>&1; then
        wlr-randr | grep "^[A-Z]" | nl -v0
    else
        echo "Could not detect monitors"
    fi
}

# Process command-line arguments
MONITOR_NUM=""
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --help)
            show_help
            exit 0
            ;;
        -o|--output)
            PROJECT_NAME="$2"
            OUTPUT_DIR="$(pwd)/$PROJECT_NAME"
            shift 2
            ;;
        -x|--x-offset)
            X_OFFSET="$2"
            shift 2
            ;;
        -y|--y-offset)
            Y_OFFSET="$2"
            shift 2
            ;;
        -W|--width)
            CAPTURE_WIDTH="$2"
            shift 2
            ;;
        -H|--height)
            CAPTURE_HEIGHT="$2"
            shift 2
            ;;
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -f|--fps)
            FPS="$2"
            shift 2
            ;;
        -a|--audio)
            AUDIO_DEVICE="$2"
            shift 2
            ;;
        -l|--list-devices)
            list_audio_devices
            exit 0
            ;;
        -m|--monitor)
            MONITOR_NUM="$2"
            shift 2
            ;;
        --list-monitors)
            list_monitors
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Check dependencies first
check_dependencies

# Function to detect screen resolution
detect_screen_resolution() {
    # Method 1: Try xrandr (X11)
    if command -v xrandr >/dev/null 2>&1; then
        local monitor_info
        if [ -n "$MONITOR_NUM" ]; then
            # Get specific monitor
            monitor_info=$(xrandr --current | grep ' connected' | sed -n "$((MONITOR_NUM + 1))p")
        else
            # Get primary monitor, or first connected if no primary
            monitor_info=$(xrandr --current | grep ' connected primary' | head -n 1)
            if [ -z "$monitor_info" ]; then
                monitor_info=$(xrandr --current | grep ' connected' | head -n 1)
            fi
        fi
        
        if [ -n "$monitor_info" ]; then
            local resolution offset
            resolution=$(echo "$monitor_info" | grep -oP '\d+x\d+\+\d+\+\d+' | head -n 1)
            SCREEN_WIDTH=$(echo "$resolution" | cut -d'x' -f1)
            SCREEN_HEIGHT=$(echo "$resolution" | cut -d'x' -f2 | cut -d'+' -f1)
            SCREEN_X_OFFSET=$(echo "$resolution" | cut -d'+' -f2)
            SCREEN_Y_OFFSET=$(echo "$resolution" | cut -d'+' -f3)
            return 0
        fi
    fi
    
    # Method 2: Try wlr-randr (Wayland)
    if command -v wlr-randr >/dev/null 2>&1; then
        local monitor_info
        if [ -n "$MONITOR_NUM" ]; then
            monitor_info=$(wlr-randr | grep -A5 "^[A-Z]" | sed -n "$((MONITOR_NUM * 6 + 1)),$((MONITOR_NUM * 6 + 6))p")
        else
            monitor_info=$(wlr-randr | grep -A5 "^[A-Z]" | head -n 6)
        fi
        
        if [ -n "$monitor_info" ]; then
            local current_mode
            current_mode=$(echo "$monitor_info" | grep "current" | head -n 1)
            if [ -n "$current_mode" ]; then
                SCREEN_WIDTH=$(echo "$current_mode" | grep -oP '\d+x\d+' | cut -d'x' -f1)
                SCREEN_HEIGHT=$(echo "$current_mode" | grep -oP '\d+x\d+' | cut -d'x' -f2)
                SCREEN_X_OFFSET=0
                SCREEN_Y_OFFSET=0
                return 0
            fi
        fi
    fi
    
    # Method 3: Try xdpyinfo (X11 fallback)
    if command -v xdpyinfo >/dev/null 2>&1; then
        local dimensions
        dimensions=$(xdpyinfo | grep dimensions | awk '{print $2}')
        SCREEN_WIDTH=$(echo "$dimensions" | cut -d'x' -f1)
        SCREEN_HEIGHT=$(echo "$dimensions" | cut -d'x' -f2)
        SCREEN_X_OFFSET=0
        SCREEN_Y_OFFSET=0
        return 0
    fi
    
    # Fallback if all methods fail
    echo "Warning: Could not detect screen resolution automatically."
    echo "Using default values: 1920x1080"
    SCREEN_WIDTH=1920
    SCREEN_HEIGHT=1080
    SCREEN_X_OFFSET=0
    SCREEN_Y_OFFSET=0
    return 1
}

# Detect screen resolution
detect_screen_resolution
echo "Detected screen resolution: ${SCREEN_WIDTH}x${SCREEN_HEIGHT}"
if [ -n "$SCREEN_X_OFFSET" ] && [ -n "$SCREEN_Y_OFFSET" ]; then
    echo "Monitor offset: +${SCREEN_X_OFFSET}+${SCREEN_Y_OFFSET}"
fi

# Calculate default position if not specified (centered)
if [ -z "$X_OFFSET" ]; then
    X_OFFSET=$(( SCREEN_X_OFFSET + (SCREEN_WIDTH - CAPTURE_WIDTH) / 2 ))
fi

if [ -z "$Y_OFFSET" ]; then
    Y_OFFSET=$(( SCREEN_Y_OFFSET + (SCREEN_HEIGHT - CAPTURE_HEIGHT) / 2 ))
fi

# Validate recording area fits within screen boundaries
if [ "$CAPTURE_WIDTH" -gt "$SCREEN_WIDTH" ]; then
    echo "Warning: Requested capture width (${CAPTURE_WIDTH}) exceeds screen width (${SCREEN_WIDTH})."
    CAPTURE_WIDTH=$SCREEN_WIDTH
    echo "Adjusted capture width to ${CAPTURE_WIDTH}."
fi

if [ "$CAPTURE_HEIGHT" -gt "$SCREEN_HEIGHT" ]; then
    echo "Warning: Requested capture height (${CAPTURE_HEIGHT}) exceeds screen height (${SCREEN_HEIGHT})."
    CAPTURE_HEIGHT=$SCREEN_HEIGHT
    echo "Adjusted capture height to ${CAPTURE_HEIGHT}."
fi

# Validate offsets
if [ "$X_OFFSET" -lt "$SCREEN_X_OFFSET" ]; then
    X_OFFSET=$SCREEN_X_OFFSET
    echo "Adjusted X offset to screen boundary: $X_OFFSET"
fi

if [ "$Y_OFFSET" -lt "$SCREEN_Y_OFFSET" ]; then
    Y_OFFSET=$SCREEN_Y_OFFSET
    echo "Adjusted Y offset to screen boundary: $Y_OFFSET"
fi

echo "=== Screen Recording Setup ==="
echo "Recording area: ${CAPTURE_WIDTH}x${CAPTURE_HEIGHT} at position (${X_OFFSET},${Y_OFFSET})"
echo "Output: $OUTPUT_DIR/$OUTPUT_NAME"
echo "FPS: $FPS"
echo "Audio device: $AUDIO_DEVICE"
if [ "$DURATION" -gt 0 ]; then
    echo "Duration: $DURATION seconds"
else
    echo "Duration: Until stopped (press q to stop)"
fi
echo "============================="
echo "Press Enter to start recording (or Ctrl+C to cancel)..."
read

# Create project directory only after user confirms
mkdir -p "$OUTPUT_DIR"
if [ $? -ne 0 ]; then
    echo "Error: Could not create output directory: $OUTPUT_DIR"
    exit 1
fi
echo "Created project directory: $OUTPUT_DIR"

# Set duration parameter if specified
DURATION_PARAM=""
if [ "$DURATION" -gt 0 ]; then
    DURATION_PARAM="-t $DURATION"
fi

# Record screen and audio
echo "Recording started. Press q to stop..."

# First, record the main video with audio
if ! ffmpeg -hide_banner -loglevel error \
    -f x11grab -video_size ${CAPTURE_WIDTH}x${CAPTURE_HEIGHT} -framerate $FPS \
    -i :0.0+${X_OFFSET},${Y_OFFSET} \
    -f pulse -i $AUDIO_DEVICE \
    -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
    -c:a aac -b:a 192k \
    $DURATION_PARAM \
    "$OUTPUT_DIR/${OUTPUT_NAME}.mkv"; then
    echo "Error: Recording failed!"
    exit 1
fi

# Extract audio as FLAC for editing
echo "Extracting audio for editing..."
if ! ffmpeg -hide_banner -loglevel error \
    -i "$OUTPUT_DIR/${OUTPUT_NAME}.mkv" \
    -vn -c:a flac \
    "$OUTPUT_DIR/${OUTPUT_NAME}_audio.flac"; then
    echo "Warning: Could not extract audio file for editing."
fi

echo "Recording completed successfully!"
echo "Video saved as: $OUTPUT_DIR/${OUTPUT_NAME}.mkv"
if [ -f "$OUTPUT_DIR/${OUTPUT_NAME}_audio.flac" ]; then
    echo "Audio saved as: $OUTPUT_DIR/${OUTPUT_NAME}_audio.flac"
fi
echo ""
echo "Next steps:"
echo "1. Edit audio in Audacity: $OUTPUT_DIR/${OUTPUT_NAME}_audio.flac"
echo "2. Export edited audio as: $OUTPUT_DIR/${OUTPUT_NAME}_edited.wav"
echo "3. Run the following command to combine them for YouTube upload:"
echo ""
echo "   # For direct YouTube upload (recommended):"
echo "   ffmpeg -i \"$OUTPUT_DIR/${OUTPUT_NAME}.mkv\" -i \"$OUTPUT_DIR/${OUTPUT_NAME}_edited.wav\" \\"
echo "      -map 0:v -map 1:a -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \\"
echo "      -c:a aac -b:a 192k -ar 48000 -movflags +faststart \\"
echo "      \"$OUTPUT_DIR/${OUTPUT_NAME}_youtube.mp4\""
echo ""
echo "   # If you need to trim the video at the same time (example starts at 10s and takes 5 minutes):"
echo "   ffmpeg -i \"$OUTPUT_DIR/${OUTPUT_NAME}.mkv\" -i \"$OUTPUT_DIR/${OUTPUT_NAME}_edited.wav\" \\"
echo "      -map 0:v -map 1:a -ss 00:00:10 -t 00:05:00 \\"
echo "      -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \\"
echo "      -c:a aac -b:a 192k -ar 48000 -movflags +faststart \\"
echo "      \"$OUTPUT_DIR/${OUTPUT_NAME}_youtube.mp4\""