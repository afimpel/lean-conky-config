#!/bin/bash
if hash pactl 2>/dev/null; then
    pactl list sinks | grep "Volume" | grep "front" -m 1 | cut -d '/' -f4
else
    awk -F"[][]" '/dB/ { print $2 }' <(amixer sget Master)
fi
