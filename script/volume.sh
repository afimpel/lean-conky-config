#!/bin/bash
if hash pactl 2>/dev/null; then
   name=$(pactl list sinks |grep -A 20 "RUNNING" | grep -m1 "alsa.name" | cut -d '"' -f2)
   volu=$(pactl list sinks |grep -A 20 "RUNNING" | grep "Volume" | grep "front" -m 1 | cut -d '/' -f4)
   if [ ! -z "$name" ]
   then
      echo "\${alignc}${name}\${alignr}\${color2}${volu}"
   else
      echo '${alignr}Muted '
   fi
else
   volu=$(awk -F"[][]" '/dB/ { print $2; exit }' <(amixer sget Master))
   echo "\${alignc}Master:	\${alignr}\${color2}${volu}"
fi
