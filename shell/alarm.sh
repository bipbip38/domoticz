#!/bin/bash

# if no command line arg given
# set rental to Unknown
if [ -z $1 ]
then
  typealarm="clock"
elif [ -n $1 ]
then
# otherwise make first arg as  the type
  typealarm=$1
fi

# use case statement to make decision for rental
case $typealarm in
   "clock") filename="Old-alarm-clock-ringing.mp3";;
   "buzzer") filename="Buzzer-sound-military-ship.mp3";;
   "alarm") filename="Warning-alarm.mp3";;
   "military") filename="Buzzer-sound-military-ship.mp3";;
   "siren") filename="Futuristic-siren-sound-effect.mp3";;
   *) filename="Old-alarm-clock-ringing.mp3";;
esac
if [ "$#" -eq  "0" ]
  then
    echo "No arguments supplied (one of : clock, buzzer, alarm, military,siren"
else
  mpc volume 75
  /usr/bin/mpg123 /home/pi/mp3/alarm/$filename >/dev/null 2>&1
  mpc volume 90

fi
