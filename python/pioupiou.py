#!/usr/bin/python

######################################################################
# * $Id: 
# * $Revision:  $
######################################################################

import json
import requests
from requests.auth import HTTPBasicAuth
from datetime import datetime,timedelta

############# Parameters ################################## 

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Domoticz parameters
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Connection Info
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
dz_ip='192.168.0.9'
dz_port='8080'
dz_user='laurent'
dz_password='kokopel1'

# IDX of the Virtual Sensor
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
dz_idx='13'

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# PiouPiou parameters
# http://api.pioupiou.fr/v1/live/{station_id}
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
pi_ip='api.pioupiou.fr'
pi_port='80'
pi_stationid='178'
pi_url='/v1/live/'
pi_request='http://'+pi_ip+':'+pi_port+pi_url+pi_stationid

# Define the delay until we consider measure is outdated
offsetdays=0
offsethours=-2
##################  ENd of Parameters ######################

########### Domoticz Virtual Widget update FUNCTION ########

def upd_widget(idx,val):
    # domoticz URL for virtual widegt update for Wind:
    #/json.htm?type=command&param=udevice&idx=IDX&nvalue=0&svalue=WB;WD;WS;WG;22;24
    # see https://www.domoticz.com/wiki/Domoticz_API/JSON_URL's#Wind

    json_url_text1='/json.htm?type=command&param=udevice&idx='
    json_url_text2='&nvalue=0&svalue='

    dz_request='http://'+dz_ip+':'+dz_port+json_url_text1+idx+json_url_text2+val

    r=requests.get(dz_request,auth=HTTPBasicAuth(dz_user,dz_password))

    if  r.status_code != 200:
        print "Error ("+str(r.status_code)+") sending data to Domoticz API using request: "+dz_request
        
###### END DOmoticz Virtual Widget update FUNCTION ########
     
###### Utils FUNCTIONS to convert heading in degrees to cardinal directions
def deg_to_direction(degrees):
        try:
            degrees = float(degrees)
        except ValueError:
            return None
        if degrees < 0 or degrees > 360:
            return None
        if degrees <= 11.25 or degrees >= 348.76:
            return "N"
        elif degrees <= 33.75:
            return "NNE"
        elif degrees <= 56.25:
            return "NE"
        elif degrees <= 78.75:
            return "ENE"
        elif degrees <= 101.25:
            return "E"
        elif degrees <= 123.75:
            return "ESE"
        elif degrees <= 146.25:
            return "SE"
        elif degrees <= 168.75:
            return "SSE"
        elif degrees <= 191.25:
            return "S"
        elif degrees <= 213.75:
            return "SSW"
        elif degrees <= 236.25:
            return "SW"
        elif degrees <= 258.75:
            return "WSW"
        elif degrees <= 281.25:
            return "W"
        elif degrees <= 303.75:
            return "WNW"
        elif degrees <= 326.25:
            return "NW"
        elif degrees <= 348.75:
            return "NNW"
        else:
            return None

### Request pioupiou api server to get live data for the given station
headers = {
    'User-Agent': 'Mozilla/5.0',
}

r = requests.get(pi_request, headers=headers)

status=r.status_code
if status == 200:
# API send 200 f everything is OK
    pioupiou=r.json()

# Parse result to get measures
# see http://developers.pioupiou.fr/api/live/

    measurements=pioupiou['data']['measurements']
    # Wind speed average(over the last 4 minutes) - km/h
    pi_wind_avg=measurements['wind_speed_avg']

    # Minimum wind speed (over the last 4 minutes) - km/h
    pi_wind_min=measurements['wind_speed_min']

    # Maximum wind speed over the last 4 minutes) - km/h
    pi_wind_max=measurements['wind_speed_max']

    # Wind heading - degrees
    pi_wind_head=measurements['wind_heading']

    # Measurement date
    pi_wind_date=datetime.strptime(measurements['date'], '%Y-%m-%dT%H:%M:%S.%fZ')

# Convert to units expected by domotics virtual sensor
    # WS = 10 * Wind speed [m/s]
    val_ws=  str(round(float(pi_wind_avg)*1000*10/3600))

    # WG = 10 * Gust [m/s]
    val_wg= str(round(float(pi_wind_max)*1000*10/3600))

    # WB = Wind bearing (0-359)
    val_wb=str(pi_wind_head)

    # WD = Wind direction (S, SW, NNW, etc.)
    val_wd=deg_to_direction(pi_wind_head)

#   print "speed is "+val_ws+" (max is "+val_wg+") - heading is "+val_wb+" (direction is "+val_wd+")"

# Check how fresh is the measure before sending to domoticz (<8 hours).
    limit_date = datetime.now() +  timedelta (days=offsetdays,hours=offsethours)
    if (pi_wind_date > limit_date):
        # Prepare svalue as expected by the Wind Virtual Sensor (svalue=WB;WD;WS;WG;22;24)
        svalue=val_wb+";"+val_wd+";"+val_ws+";"+val_wg+";00;00"
        upd_widget (dz_idx,svalue) 
    else:
        print "Measurement date starts to be old ["+str(pi_wind_date)+"], domoticz was not refreshed"
else:

    print "Error ("+str(status)+") reading data from Pioupiou API using request: "+pi_request
