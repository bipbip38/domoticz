#!/bin/bash
mpc clear
# Exclude all mp3 files which are not music (like jingles, spoken ,...)
mpc ls music | mpc add
mpc random on
mpc volume 95
mpc play

# "mpc toggle" can be used to pause or "mpc stop" to stop the playlist"
