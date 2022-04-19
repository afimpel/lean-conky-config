#!/bin/bash
 for i in $(ls /sys/class/net/); do
    if grep -q "up" "/sys/class/net/${i}/operstate"
    then
        ip=$(ip -4 -j -p addr show ${i} | grep local | cut -d '"' -f4)
        if [ ! -z "$ip" ]
            then
            if ! grep -q "=bridge" "/sys/class/net/${i}/uevent"
            then
                sal=$(grep DEVTYPE /sys/class/net/${i}/uevent | cut -d = -f2 | tail -1)
                if [ -z "$sal" ]
                then
                    echo "${i}:eth:${ip}:"
                else
                    echo "${i}:${sal}:${ip}:" 
                fi
            fi
        fi
    fi
done; 

