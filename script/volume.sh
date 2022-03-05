#!/bin/bash
if hash pactl 2>/dev/null; then
   name=$(pactl list sinks |grep -A 20 "RUNNING" | grep "alsa.name" | cut -d '"' -f2)
   volu=$(pactl list sinks |grep -A 20 "RUNNING" | grep "Volume" | grep "front" -m 1 | cut -d '/' -f4 | cut -d '%' -f1)
   echo "${name}:	${volu}%"
else
   volu=$(awk -F"[][]" '/dB/ { print $2 }' <(amixer sget Master))
   echo "Master:	${volu}"
fi