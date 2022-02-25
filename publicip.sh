#!/bin/bash
ip=$(wget -q -O- https://ipecho.net/plain)
if [ ! -z "$ip" ]
then
    echo ${ip}
else
    /usr/bin/notify-send "RED:" "!!! NO Internet !!!" -i network-error -t 8000
    echo '!!! NO Internet !!!'
fi

