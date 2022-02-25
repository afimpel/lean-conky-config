#!/bin/bash
 for i in $(ls /sys/class/net/); do
    if grep -Fxq "up" "/sys/class/net/${i}/operstate"
    then
        if ! grep -Fxq "bridge" "/sys/class/net/${i}/uevent"
        then
            sal=$(grep DEVTYPE /sys/class/net/${i}/uevent | cut -d = -f2 | tail -1)
            if [ -z "$sal" ]
            then
                echo "${i}:eth"
            else
                echo "${i}:${sal}" 
            fi
        fi
    fi
done; 

