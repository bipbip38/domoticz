-- script_time_stairdoor.lua
-- Script to be used within Domoticz
-- naming convention makes it executed every minutes


GRACE_PERIOD = 600              -- how long do we wait before notifying door should be closed (in seconds)
SENSOR_HAUT = 'Meuble TV'       -- exact device name of the upstairs temperature sensor
SENSOR_BAS = 'Salon'            -- exact device name of the downstairs temperature sensor
SWITCH_DOOR = 'Porte Escalier'  -- exact device name of the door switch sensor
TEMP_OFFSET = 0.1               -- delta temperature when   
PRINT_MODE = true               -- when true will print output to log and send notifications


temphaut = otherdevices_temperature[SENSOR_HAUT]
tempbas = otherdevices_temperature[SENSOR_BAS]

-- This is a notification sript to prevnet the door in between stairs to remain open when heating is on. 
-- (the "thermostat" is downstairs, if the door is open, temperature is increasing much faster upstairs)
-- unless their is fire in the cheminey, downstairs temperature will always be less than upstairs.

delta = temphaut - tempbas

t1 = os.time()
s = otherdevices_lastupdate['Porte Escalier']
-- returns a date time like 2013-07-11 17:23:12
 
year = string.sub(s, 1, 4)
month = string.sub(s, 6, 7)
day = string.sub(s, 9, 10)
hour = string.sub(s, 12, 13)
minutes = string.sub(s, 15, 16)
seconds = string.sub(s, 18, 19)
  
commandArray = {}
  
t2 = os.time{year=year, month=month, day=day, hour=hour, min=minutes, sec=seconds}
difference = (os.difftime (t1, t2))
-- Notification will only be sent in case temperature is lower downstairs ()
if (otherdevices[SWITCH_DOOR] == 'On' and difference > GRACE_PERIOD and difference < 700 and delta > TEMP_OFFSET) then
      commandArray['SendNotification']='Porte Escalier ouverte depuis +10 minutes!'
      print('Porte Escalier ouverte depuis + de 10min, Temp salon:' ..tempBas)

end 
       
return commandArray
