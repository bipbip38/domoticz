--[[
 
This script controls the humidity in a typical bathroom setting by detecting
relative rises in humidity in a short period.
Of course it requires a humidity sensor and a binary switch controlling a fan/ventilator.
(there is no provision for variable speed ventilators here!)
 
How it works (assuming the default constants as defined below):
Every 5 minutes a reading is done. Every reading is stored together
with the previous reading and is stored in two user variables (humidityTmin5 and humidityTmin10).
So it has two reading over the past 10 minutes.
It then takes the lowest of the two and compares it with the latest reading and
calculates a delta.
If the delta is 3 or higher (see constants) then the fan will be turned
on, it calculates the target humidity and the 'humidity-decrease program' is started (fanFollowsProgram=1).
From then on, every 5 minutes the current humidity is compared to the
stored target humidity. Basically if that target is reached, the fan is turned off
and the 'program' is ended.
Of course, it is possible that the target is never reached (might start raining outside
or whatever). Then there is a failsafe (FAN_MAX_TIME) after which the ventilator
will be turned off.
 
Also, it will detect if the ventilator is manually switched off during a program
or when it is switched on before the program starts.
 
Along the lines it prints to the log and sends notifications
but of course you can turn that off by removing those lines.

V6
 
--]]
 
commandArray = {}
 
-- declare some constants
-- adjust to your specific situation
SAMPLE_INTERVAL = 1                 -- time in minutes when a the script logic will happen
FAN_DELTA_TRIGGER = 2               -- rise in humidity that will trigger the fan
TEMP_DELTA_TRIGGER_OFF = -0.1       -- decrease in temperature that will stop the  music
TEMP_DELTA_TRIGGER_ON = 0.1         -- increase in temperature that will start the  music
MAX_MUSIC_CYCLES = 12               -- maximum amount of sample cycles the music can be on
ALARMLEVEL1 = 5 	            
ALARMLEVEL2 = 8                
MAX_MUSIC_CYCLES = 15                -- maximum amount of sample cycles the music can be on
FAN_MAX_TIME = 120                  --  maximum amount of sample cycles the fan can be on, 
                                    -- in case we never reach the target humidity
TARGET_OFFSET = 2                   -- ventilator goes off if target+offset is reached 
                                    -- (maybe it takes too long to reach the true target due to wet towels etc)
FAN_NAME = 'VMC'    -- exact device name of the switch turning on/off the ventilator
ALARM_NAME = 'Alarme'    -- exact device name of the switch turning on/off the ventilator
SPEAKER_NAME = 'SpeakerDouche' -- exact device name of the switch turning on/off the music
SENSOR_NAME = 'Douche'     -- exact device name of the humidity sensor
 
TEST_MODE = false                   -- when true TEST_MODE_HUMVAR is used instead of the real sensor
TEST_MODE_HUMVAR = 'testHumidity'   -- fake humidity value, give it a test value in domoticz/uservars
PRINT_MODE = true				-- when true wil print output to log and send notifications
 
if PRINT_MODE == true then
print('Fan control')
end
 
-- get the global variables:
-- this script runs every minute, humCounter is used to create SAMPLE_INTERVAL periods
humCounter = tonumber(uservariables['humCounter'])
humidityTmin5 = tonumber(uservariables['humidityTmin5'])                -- youngest reading
humidityTmin10 = tonumber(uservariables['humidityTmin10'])              -- oldest reading
temperatureTmin10 = tonumber(uservariables['tempTmin10'])      		-- oldest reading (Temp)
temperatureTmin5 = tonumber(uservariables['tempTmin5'])         	-- youngest reading (Temp)
targetFanOffHumidity = tonumber(uservariables['targetFanOffHumidity'])  -- target humidity
fanMaxTimer = tonumber(uservariables['fanMaxTimer'])
fanFollowsProgram = tonumber(uservariables['fanFollowsProgram'])        -- marker indicating that the 
                                                                        -- decrease program is started
showerStarted = tonumber(uservariables['showerStarted'])      -- marker indicating from how many 
									-- cycle is the music is started
target = 0 -- will hold the target humidity when the program starts
 
-- get the current humidity value
if (TEST_MODE) then
    current = tonumber(uservariables[TEST_MODE_HUMVAR])
else
    current = otherdevices_humidity[SENSOR_NAME]
    curtemp = otherdevices_temperature[SENSOR_NAME]
end
 
-- check if the sensor is on or has some weird reading
if (current == 0 or current == nil) then
    print('current is 0 or nil. Skipping this reading')
    return commandArray
end
 
if PRINT_MODE == true then
        print('Current humidity:' .. current)
		print('targetFanOffHumidity:' .. targetFanOffHumidity)
		print('humidityTmin5: ' .. humidityTmin5)
		print('humidityTmin10: ' .. humidityTmin10)
		print('temperatureTmin5: ' .. temperatureTmin5)
		print('temperatureTmin10: ' .. temperatureTmin10)
		print('fanMaxTimer: ' .. fanMaxTimer)
		print('humCounter:' .. humCounter)
		print('fanFollowsProgram:' .. fanFollowsProgram)
end
 
-- increase cycle counter
humCounter = humCounter + 1

-- If SAMPLE_INTERVAL=1, check will be executed everytime (i.e 1 minute) 
if (humCounter >= SAMPLE_INTERVAL) then
 
    if (humidityTmin5 == 0) then
        -- initialization, assume this is the first time
        humidityTmin5 = current
        humidityTmin10 = current
        temperatureTmin5 = curtemp
        temperatureTmin10 = curtemp
	
    end
 
    humCounter = 0 -- reset the cycle counter
 
    -- pick the lowest history value for humidity to calculate the delta
    -- this also makes sure that two relative small deltas in the past 2*interval minutes are treated as one larger rise
    -- and therefore will still trigger the ventilator
    -- I don't want to use a longer interval instead because I want the ventilator to start as soon as possible
    -- (so rather after 5 minutes instead of after 15 minutes because the mirrors in the bathroom become kinda useless ;-)
    --
    -- Pick the highest history temperature to calculate temp delta to make sure we detect as early as possible a temp
    -- decrease
    
    delta = current - math.min(humidityTmin10, humidityTmin5)
    tempdelta = curtemp - math.max(temperatureTmin10, temperatureTmin5)
if PRINT_MODE == true then
	print('Delta Humidity: ' .. delta)
	print('Delta Temp: ' .. tempdelta)
end
 
    -- pick the lowest history value
    target = math.min(humidityTmin10, humidityTmin5) + TARGET_OFFSET
 
    -- shift the previous measurements
    humidityTmin10 = humidityTmin5
    temperatureTmin10 = temperatureTmin5
    -- and store the current
    humidityTmin5 = current
    temperatureTmin5 = curtemp
 
    if (otherdevices[FAN_NAME]=='Off' or (otherdevices[FAN_NAME]=='On' and fanFollowsProgram==0)) then
        -- either the fan is off or it is on but the decrease program has not started
        -- in that latter case we start the program anyway. This could happen if someone turns on the ventilator
        -- manually because he/she is about to take a shower and doesn't like damp mirrors.
        -- I don't do this because the ventilator removes heat from the bathroom and I want this to happen
        -- as late as possible ;-)
 
        if (fanFollowsProgram == 1 and otherdevices[FAN_NAME]=='Off') then
            -- likely someone turned off the ventilator while the program was running
            fanFollowsProgram = 0
        end
 
        -- see if we have to turn the fan on
        if (delta >= FAN_DELTA_TRIGGER) then
            -- time to start the fan
            commandArray[FAN_NAME] = 'On'
            targetFanOffHumidity = target
 
            if (fanFollowsProgram == 1) then
                print('Ventilator was already on but we start the de-humidifying program')
            end
 
            fanFollowsProgram = 1
 
            -- set the safety stop
            fanMaxTimer = FAN_MAX_TIME
 
	    if PRINT_MODE == true then
            	print('Rise in humidity. Turning on the vents. Delta: ' .. delta)
            	print('Target humidity for turning the ventilator: ' ..targetFanOffHumidity)
            	commandArray['SendNotification'] = 'Ventilator and Music are on#The ventilator was activated at humidity level ' .. current .. '#0'
            	-- Starting the music
            	commandArray[SPEAKER_NAME] = 'On'
	        showerStarted=0
	    end
        end
 
    else
        if (fanMaxTimer > 0) then
            -- possible that someone started the ventilator manually
            fanMaxTimer = fanMaxTimer - 1
        end
 
 
        if (fanFollowsProgram == 1) then -- not manually started
 
            if (delta >= FAN_DELTA_TRIGGER) then
                -- ok, there is another FAN_DELTA_TRIGGER rise in humidity
                -- when this happen we reset the fanMaxTimer to a new count down
                -- because we have to ventilate a bit longer due to the extra humidity
                if PRINT_MODE == true then
				print('Another large increase detected, resetting max timer. Delta: ' .. delta)
				end
                fanMaxTimer = FAN_MAX_TIME
            end
 
            -- first see if it can be turned off
            if (current <= targetFanOffHumidity or fanMaxTimer==0) then
                commandArray[FAN_NAME] = 'Off'
 
                msg = ''
 
                if (fanMaxTimer == 0 and current > targetFanOffHumidity) then
                    msg = 'Target not reached but safety time-out is triggered.'
                    if PRINT_MODE == true then
					print(msg)
					end
                else
                    msg = 'Target humidity reached'
                    if PRINT_MODE == true then
					print(msg)
					end
                end
 
				if PRINT_MODE == true then
                print('Turning off the ventilator')
                msg = msg .. '\nTurning off the ventilator'
				end
 
                targetFanOffHumidity = 0
                fanMaxTimer = 0
                fanFollowsProgram = 0
                -- reset history in this case.. we start all over
                -- Tmin10 is still in the 'ventilator=On'-zone
                humidityTmin10 = humidityTmin5
                 if PRINT_MODE == true then
				commandArray['SendNotification'] = 'Ventilator is off#' .. msg .. '#0'
				end
 
            else
                -- we haven't reached the target for humidity yet (let's give some fun in the bathroom by starting
                -- the music and running some alarms to save hot water !).
               if PRINT_MODE == true then
			   print('Temperature delta: ' .. tempdelta)
	       end

               if (otherdevices[SPEAKER_NAME]=='On') then
                   -- Music is already started, time limit was not exceed
                   -- In case a decrease in temperature is detected, stop the music, reset counter to 0
               	   showerStarted = showerStarted + 1

               	   if (tempdelta < TEMP_DELTA_TRIGGER_OFF) then
 			-- Decrease was detected, stop the Speaker
			print('Decrease detected, stopping the music')
            	        commandArray['SendNotification'] = 'Shower is now stopped after ' .. showerStarted .. ' min'
                	commandArray[SPEAKER_NAME] = 'Off'
                	showerStarted=0
                   else
		      -- Check if we didn't reach the maxium music playing time
		      -- and make sure to send notifications 
		      print('showerStarted #: ' .. showerStarted)
	              if (showerStarted > MAX_MUSIC_CYCLES) then
                	        commandArray[ALARM_NAME] = 'Buzzer'
                		commandArray[SPEAKER_NAME] = 'Off'
            	                commandArray['SendNotification'] = 'Music stopped and Buzzer alarm sent after ' .. showerStarted .. ' min'
	              elseif (showerStarted ==ALARMLEVEL2 ) then
                	        commandArray[ALARM_NAME] = 'Alarme'
            	                commandArray['SendNotification'] = 'Alarme sent after ' .. showerStarted .. ' min'
	              elseif (showerStarted ==ALARMLEVEL1 ) then
                	        commandArray[ALARM_NAME] = 'Clock'
            	                commandArray['SendNotification'] = 'Clock alarm sent after ' .. showerStarted .. ' min'
                      end	  
		   end
               else -- Speaker is off (shower is either stopped or max music cycle exceed)
               	   if (tempdelta > TEMP_DELTA_TRIGGER_ON and delta > 0  and showerStarted==0) then
                     -- Music is off and shower was stoppped, temperature increase detected and humitidy still rising,
                     -- Let's start the music again
		     print('New major Temperature increase detected')
                     commandArray[SPEAKER_NAME] = 'On'
            	     commandArray['SendNotification'] = 'Music is on , temperature increase detected' .. tempdelta
	             showerStarted=0
                   elseif (showerStarted > 0) then 
                     -- Music is off (max playing time was reached!) but shower is still on
               	     showerStarted = showerStarted + 1
		     print('Maximum shower time exceed' .. showerStarted)
                   end
               end -- end else speaker is off
            end -- end else humitidy target not reached yet
        end
    end
 
if PRINT_MODE == true then
    print('New values >>>>>>>>>>>')
    print('humidityTmin5: ' .. humidityTmin5)
    print('humidityTmin10: ' .. humidityTmin10)
    print('temperatureTmin5: ' .. temperatureTmin5)
    print('temperatureTmin10: ' .. temperatureTmin10)
    print('fanMaxTimer: ' .. fanMaxTimer)
    print('humCounter:' .. humCounter)
    print('fanFollowsProgram:' .. fanFollowsProgram)
    print('------ target: ' .. targetFanOffHumidity)
    print('Shower Started since #: ' .. showerStarted)
end
 
-- save the globals
commandArray['Variable:humCounter'] = tostring(humCounter)
commandArray['Variable:humidityTmin10'] = tostring(humidityTmin10)
commandArray['Variable:humidityTmin5'] = tostring(humidityTmin5)
commandArray['Variable:tempTmin10'] = tostring(temperatureTmin10)
commandArray['Variable:tempTmin5'] = tostring(temperatureTmin5)
commandArray['Variable:targetFanOffHumidity'] = tostring(targetFanOffHumidity)
commandArray['Variable:fanMaxTimer'] = tostring(fanMaxTimer)
commandArray['Variable:fanFollowsProgram'] = tostring(fanFollowsProgram)
commandArray['Variable:showerStarted'] = tostring(showerStarted)
 
return commandArray
