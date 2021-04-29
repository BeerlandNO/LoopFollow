//
//  Alarms.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//
//
//
//
//
//


import Foundation
import AVFoundation

extension MainViewController {
    
    
    func checkAlarms(bgs: [ShareGlucoseData]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Checking Alarms") }
        // Don't check or fire alarms within 1 minute of prior alarm
        if checkAlarmTimer.isValid {  return }
        
        let date = Date()
        let now = date.timeIntervalSince1970
        let currentBG = bgs[bgs.count - 1].sgv
        let lastBG = bgs[bgs.count - 2].sgv
        
        var deltas: [Int] = []
        if bgs.count > 3 {
            deltas.append(bgs[bgs.count - 1].sgv - bgs[bgs.count - 2].sgv)
            deltas.append(bgs[bgs.count - 2].sgv - bgs[bgs.count - 3].sgv)
            deltas.append(bgs[bgs.count - 3].sgv - bgs[bgs.count - 4].sgv)
        } else if bgs.count > 2 {
            deltas.append(bgs[bgs.count - 1].sgv - bgs[bgs.count - 2].sgv)
            deltas.append(bgs[bgs.count - 2].sgv - bgs[bgs.count - 3].sgv)
            // Set remainder to match the last delta we have
            deltas.append(bgs[bgs.count - 2].sgv - bgs[bgs.count - 3].sgv)
        } else if bgs.count > 1 {
            deltas.append(bgs[bgs.count - 1].sgv - bgs[bgs.count - 2].sgv)
            // Set remainder to match the last delta we have
            deltas.append(bgs[bgs.count - 1].sgv - bgs[bgs.count - 2].sgv)
            deltas.append(bgs[bgs.count - 1].sgv - bgs[bgs.count - 2].sgv)
        } else {
            // We only have 1 reading, set all to 0.
            deltas.append(0)
            deltas.append(0)
            deltas.append(0)
        }
        
        
        let currentBGTime = bgs[bgs.count - 1].date
        var alarmTriggered = false
        var numLoops = 0
        var playSound = true
        checkQuietHours()
        clearOldSnoozes()
        
        // Exit if all is snoozed
        // still send persistent notification with all snoozed
        if UserDefaultsRepository.alertSnoozeAllIsSnoozed.value {
            persistentNotification(bgTime: currentBGTime)
            return
        }
        
        
        // BG Based Alarms
        // Check to make sure it is a current reading and has not already triggered alarm from this reading
        if now - currentBGTime <= (5*60) && currentBGTime > UserDefaultsRepository.snoozedBGReadingTime.value as! TimeInterval {
            
            // trigger temporary alert first
            if UserDefaultsRepository.alertTemporaryActive.value {
                if UserDefaultsRepository.alertTemporaryBelow.value {
                    if Float(currentBG) < UserDefaultsRepository.alertTemporaryBG.value {
                        UserDefaultsRepository.alertTemporaryActive.value = false
                        AlarmSound.whichAlarm = "Temporary Alert"
                        if UserDefaultsRepository.alertTemporaryBGRepeat.value { numLoops = -1 }
                        triggerAlarm(sound: UserDefaultsRepository.alertTemporarySound.value, snooozedBGReadingTime: currentBGTime, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops)
                        return
                    }
                } else{
                    if Float(currentBG) > UserDefaultsRepository.alertTemporaryBG.value {
                        tabBarController?.selectedIndex = 2
                        AlarmSound.whichAlarm = "Temporary Alert"
                        if UserDefaultsRepository.alertTemporaryBGRepeat.value { numLoops = -1 }
                        triggerAlarm(sound: UserDefaultsRepository.alertTemporarySound.value, snooozedBGReadingTime: currentBGTime, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops)
                        return
                    }
                }
            }
            
            // Check Urgent Low
            if UserDefaultsRepository.alertUrgentLowActive.value && !UserDefaultsRepository.alertUrgentLowIsSnoozed.value &&
                Float(currentBG) <= UserDefaultsRepository.alertUrgentLowBG.value {
                // Separating this makes it so the low or drop alerts won't trigger if they already snoozed the urgent low
                if !UserDefaultsRepository.alertUrgentLowIsSnoozed.value {
                    AlarmSound.whichAlarm = "Urgent Low Alert"
                    //determine if it is day or night and what should happen
                    if UserDefaultsRepository.nightTime.value {
                        if UserDefaultsRepository.alertUrgentLowNightTime.value { numLoops = -1 }
                        if !UserDefaultsRepository.alertUrgentLowNightTimeAudible.value { playSound = false }
                    } else {
                        if UserDefaultsRepository.alertUrgentLowDayTime.value { numLoops = -1 }
                        if !UserDefaultsRepository.alertUrgentLowDayTimeAudible.value { playSound = false }
                    }
                    triggerAlarm(sound: UserDefaultsRepository.alertUrgentLowSound.value, snooozedBGReadingTime: currentBGTime, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops, snoozeTime: UserDefaultsRepository.alertUrgentLowSnooze.value, audio: playSound)
                    return
                } else {
                    return
                }
            }
            
            // Check Low
            if UserDefaultsRepository.alertLowActive.value && !UserDefaultsRepository.alertUrgentLowIsSnoozed.value &&
                Float(currentBG) <= UserDefaultsRepository.alertLowBG.value && !UserDefaultsRepository.alertLowIsSnoozed.value {
                AlarmSound.whichAlarm = "Low Alert"
  
                //determine if it is day or night and what should happen
                if UserDefaultsRepository.nightTime.value {
                    if UserDefaultsRepository.alertLowNightTime.value { numLoops = -1 }
                    if !UserDefaultsRepository.alertLowNightTimeAudible.value { playSound = false }
                    print ("It is NightTime and playSound = ", playSound)
                } else {
                    if UserDefaultsRepository.alertLowDayTime.value { numLoops = -1 }
                    if !UserDefaultsRepository.alertLowDayTimeAudible.value { playSound = false }
                    //print ("It is DayTime and playSound = ", playSound)
                }
                
                triggerAlarm(sound: UserDefaultsRepository.alertLowSound.value, snooozedBGReadingTime: currentBGTime, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops, snoozeTime: UserDefaultsRepository.alertLowSnooze.value, audio: playSound)
                return
            }
            
            // Check Urgent High
            if UserDefaultsRepository.alertUrgentHighActive.value && !UserDefaultsRepository.alertUrgentHighIsSnoozed.value &&
                Float(currentBG) >= UserDefaultsRepository.alertUrgentHighBG.value {
                // Separating this makes it so the high or rise alerts won't trigger if they already snoozed the urgent high
                if !UserDefaultsRepository.alertUrgentHighIsSnoozed.value {
                    AlarmSound.whichAlarm = "Urgent High Alert"
                    //determine if it is day or night and what should happen
                    if UserDefaultsRepository.nightTime.value {
                        if UserDefaultsRepository.alertUrgentHighNightTime.value { numLoops = -1 }
                        if !UserDefaultsRepository.alertUrgentHighNightTimeAudible.value { playSound = false }
                    } else {
                        if UserDefaultsRepository.alertUrgentHighDayTime.value { numLoops = -1 }
                        if !UserDefaultsRepository.alertUrgentHighDayTimeAudible.value { playSound = false }
                    }
                    triggerAlarm(sound: UserDefaultsRepository.alertUrgentHighSound.value, snooozedBGReadingTime: currentBGTime, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops, snoozeTime: UserDefaultsRepository.alertUrgentHighSnooze.value, audio: playSound)
                    return
                } else {
                    return
                }
                
            }
            
            // Check High
            let persistentReadings = Int(UserDefaultsRepository.alertHighPersistent.value / 5)
            let persistentBG = bgData[bgData.count - 1 - persistentReadings].sgv
            if UserDefaultsRepository.alertHighActive.value &&
                !UserDefaultsRepository.alertHighIsSnoozed.value &&
                Float(currentBG) >= UserDefaultsRepository.alertHighBG.value &&
                Float(persistentBG) >= UserDefaultsRepository.alertHighBG.value &&
                !UserDefaultsRepository.alertHighIsSnoozed.value {
                AlarmSound.whichAlarm = "High Alert"
                //determine if it is day or night and what should happen
                if UserDefaultsRepository.nightTime.value {
                    if UserDefaultsRepository.alertHighNightTime.value { numLoops = -1 }
                    if !UserDefaultsRepository.alertHighNightTimeAudible.value { playSound = false }
                    print ("It is NightTime and playSound = ", playSound)
                } else {
                    if UserDefaultsRepository.alertHighDayTime.value { numLoops = -1 }
                    if !UserDefaultsRepository.alertHighDayTimeAudible.value { playSound = false }
                    //print ("It is DayTime and playSound = ", playSound)
                }
                triggerAlarm(sound: UserDefaultsRepository.alertHighSound.value, snooozedBGReadingTime: currentBGTime, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops, snoozeTime: UserDefaultsRepository.alertHighSnooze.value, audio: playSound)
                return
            }
            
            
            
            // Check Fast Drop
            if UserDefaultsRepository.alertFastDropActive.value && !UserDefaultsRepository.alertFastDropIsSnoozed.value {
                // make sure limit is off or BG is below value
                if (!UserDefaultsRepository.alertFastDropUseLimit.value) || (UserDefaultsRepository.alertFastDropUseLimit.value && Float(currentBG) < UserDefaultsRepository.alertFastDropBelowBG.value) {
                    let compare = 0 - UserDefaultsRepository.alertFastDropDelta.value
                    
                    //check last 2/3/4 readings
                    if (UserDefaultsRepository.alertFastDropReadings.value == 2 && Float(deltas[0]) <= compare)
                        || (UserDefaultsRepository.alertFastDropReadings.value == 3 && Float(deltas[0]) <= compare && Float(deltas[1]) <= compare)
                        || (UserDefaultsRepository.alertFastDropReadings.value == 4 && Float(deltas[0]) <= compare && Float(deltas[1]) <= compare && Float(deltas[2]) <= compare) {
                        AlarmSound.whichAlarm = "Fast Drop Alert"
                        //determine if it is day or night and what should happen
                        if UserDefaultsRepository.nightTime.value {
                            if UserDefaultsRepository.alertFastDropNightTime.value { numLoops = -1 }
                            if !UserDefaultsRepository.alertFastDropNightTimeAudible.value { playSound = false }
                        } else {
                            if UserDefaultsRepository.alertFastDropDayTime.value { numLoops = -1 }
                            if !UserDefaultsRepository.alertFastDropDayTimeAudible.value { playSound = false }
                        }
                        triggerAlarm(sound: UserDefaultsRepository.alertFastDropSound.value, snooozedBGReadingTime: currentBGTime, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops, snoozeTime: UserDefaultsRepository.alertFastDropSnooze.value, audio: playSound)
                        return
                    }
                }
            }
            
            // Check Fast Rise
            if UserDefaultsRepository.alertFastRiseActive.value && !UserDefaultsRepository.alertFastRiseIsSnoozed.value {
                // make sure limit is off or BG is above value
                if (!UserDefaultsRepository.alertFastRiseUseLimit.value) || (UserDefaultsRepository.alertFastRiseUseLimit.value && Float(currentBG) > UserDefaultsRepository.alertFastRiseAboveBG.value) {
                    let compare = UserDefaultsRepository.alertFastDropDelta.value
                    
                    //check last 2/3/4 readings
                    if (UserDefaultsRepository.alertFastRiseReadings.value == 2 && Float(deltas[0]) >= compare)
                        || (UserDefaultsRepository.alertFastRiseReadings.value == 3 && Float(deltas[0]) >= compare && Float(deltas[1]) >= compare)
                        || (UserDefaultsRepository.alertFastRiseReadings.value == 4 && Float(deltas[0]) >= compare && Float(deltas[1]) >= compare && Float(deltas[2]) >= compare) {
                        AlarmSound.whichAlarm = "Fast Rise Alert"
                        //determine if it is day or night and what should happen
                        if UserDefaultsRepository.nightTime.value {
                            if UserDefaultsRepository.alertFastRiseNightTime.value { numLoops = -1 }
                            if !UserDefaultsRepository.alertFastRiseNightTimeAudible.value { playSound = false }
                        } else {
                            if UserDefaultsRepository.alertFastRiseDayTime.value { numLoops = -1 }
                            if !UserDefaultsRepository.alertFastRiseDayTimeAudible.value { playSound = false }
                        }
                        triggerAlarm(sound: UserDefaultsRepository.alertFastRiseSound.value, snooozedBGReadingTime: currentBGTime, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops, snoozeTime: UserDefaultsRepository.alertFastRiseSnooze.value, audio: playSound)
                        return
                    }
                }
            }
            
            
            
        }
        
        // These only get checked and fire if a BG reading doesn't fire
        
        //check for missed reading alert
        if UserDefaultsRepository.alertMissedReadingActive.value && !UserDefaultsRepository.alertMissedReadingIsSnoozed.value && (Double(now - currentBGTime) >= Double(UserDefaultsRepository.alertMissedReading.value * 60)) {
            AlarmSound.whichAlarm = "Missed Reading Alert"
            //determine if it is day or night and what should happen
            if UserDefaultsRepository.nightTime.value {
                if UserDefaultsRepository.alertMissedReadingNightTime.value { numLoops = -1 }
                if !UserDefaultsRepository.alertMissedReadingNightTimeAudible.value { playSound = false }
            } else {
                if UserDefaultsRepository.alertMissedReadingDayTime.value { numLoops = -1 }
                if !UserDefaultsRepository.alertMissedReadingDayTimeAudible.value { playSound = false }
            }
            triggerAlarm(sound: UserDefaultsRepository.alertMissedReadingSound.value, snooozedBGReadingTime: nil, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops, snoozeTime: UserDefaultsRepository.alertMissedReadingSnooze.value, audio: playSound)
            return
        }
        
        //check for not looping alert
        if UserDefaultsRepository.url.value != "" {
            
            if UserDefaultsRepository.alertNotLoopingActive.value
                && !UserDefaultsRepository.alertNotLoopingIsSnoozed.value
                && (Double(dateTimeUtils.getNowTimeIntervalUTC() - UserDefaultsRepository.alertLastLoopTime.value) >= Double(UserDefaultsRepository.alertNotLooping.value * 60))
                && UserDefaultsRepository.alertLastLoopTime.value > 0 {
                
                var trigger = true
                if (UserDefaultsRepository.alertNotLoopingUseLimits.value
                    && (
                        (Float(currentBG) >= UserDefaultsRepository.alertNotLoopingUpperLimit.value
                            && Float(currentBG) <= UserDefaultsRepository.alertNotLoopingLowerLimit.value) ||
                            // Ignore Limits if BG reading is older than non looping time
                            (Double(now - currentBGTime) >= Double(UserDefaultsRepository.alertNotLooping.value * 60))
                    ) ||
                    !UserDefaultsRepository.alertNotLoopingUseLimits.value) {
                    AlarmSound.whichAlarm = "Not Looping Alert"
                    //determine if it is day or night and what should happen
                    if UserDefaultsRepository.nightTime.value {
                        if UserDefaultsRepository.alertNotLoopingNightTime.value { numLoops = -1 }
                        if !UserDefaultsRepository.alertNotLoopingNightTimeAudible.value { playSound = false }
                    } else {
                        if UserDefaultsRepository.alertNotLoopingDayTime.value { numLoops = -1 }
                        if !UserDefaultsRepository.alertNotLoopingDayTimeAudible.value { playSound = false }
                    }
                    triggerAlarm(sound: UserDefaultsRepository.alertNotLoopingSound.value, snooozedBGReadingTime: nil, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops, snoozeTime: UserDefaultsRepository.alertNotLoopingSnooze.value, audio: playSound)
                    return
                }
            }
            
            // check for missed bolus - Only checks within 1 hour of carb entry
            // Only continue if alert is active, not snooozed, we have carb data, and bg is over the ignore limit
            if UserDefaultsRepository.alertMissedBolusActive.value
                && !UserDefaultsRepository.alertMissedBolusIsSnoozed.value
                && carbData.count > 0
                && Float(currentBG) > UserDefaultsRepository.alertMissedBolusLowGramsBG.value {
                
                // Grab the latest carb entry
                let lastCarb = carbData[carbData.count - 1].value
                let lastCarbTime = carbData[carbData.count - 1].date
                let now = dateTimeUtils.getNowTimeIntervalUTC()
                
                //Make sure carb entry is newer than 1 hour, has reached the time length, and is over the ignore limit
                if lastCarbTime > (now - (60 * 60))
                    && lastCarbTime < (now - Double((UserDefaultsRepository.alertMissedBolus.value * 60)))
                    && lastCarb > Double(UserDefaultsRepository.alertMissedBolusLowGrams.value) {
                    
                    // There is a current carb but no boluses data at all
                    if bolusData.count < 1 {
                        AlarmSound.whichAlarm = "Missed Bolus Alert"
                        //determine if it is day or night and what should happen
                        if UserDefaultsRepository.nightTime.value {
                            if UserDefaultsRepository.alertMissedBolusNightTime.value { numLoops = -1 }
                            if !UserDefaultsRepository.alertMissedBolusNightTimeAudible.value { playSound = false }
                        } else {
                            if UserDefaultsRepository.alertMissedBolusDayTime.value { numLoops = -1 }
                            if !UserDefaultsRepository.alertMissedBolusDayTimeAudible.value { playSound = false }
                        }
                        triggerAlarm(sound: UserDefaultsRepository.alertMissedBolusSound.value, snooozedBGReadingTime: nil, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops, snoozeTime: UserDefaultsRepository.alertMissedBolusSnooze.value, audio: playSound)
                        return
                    }
                    
                    // Get the latest bolus over the small bolus exclusion
                    // Start with 0.0 bolus assuming there isn't one to cause a trigger and only add one if found
                    var lastBolus = 0.0
                    var lastBolusTime = 0.0
                    var i = 1
                    // check the boluses in reverse order setting it only if the time is after the carb time minus prebolus time.
                    // This will make the loop stop at the most recent bolus that is over the minimum value or continue through all boluses
                    while lastBolus < UserDefaultsRepository.alertMissedBolusIgnoreBolus.value && i <= bolusData.count {
                        // Set the bolus if it's after the carb time minus prebolus time
                        if (bolusData[bolusData.count - i].date >= lastCarbTime - Double(UserDefaultsRepository.alertMissedBolusPrebolus.value * 60)) {
                            lastBolus = bolusData[bolusData.count - i].value
                            lastBolusTime = bolusData[bolusData.count - i].date
                        }
                        i += 1
                    }
                    
                    // This will trigger is no boluses were set above
                    if (lastBolus == 0.0) {
                        AlarmSound.whichAlarm = "Missed Bolus Alert"
                        //determine if it is day or night and what should happen
                        if UserDefaultsRepository.nightTime.value {
                            if UserDefaultsRepository.alertMissedBolusNightTime.value { numLoops = -1 }
                            if !UserDefaultsRepository.alertMissedBolusNightTimeAudible.value { playSound = false }
                        } else {
                            if UserDefaultsRepository.alertMissedBolusDayTime.value { numLoops = -1 }
                            if !UserDefaultsRepository.alertMissedBolusDayTimeAudible.value { playSound = false }
                        }
                        triggerAlarm(sound: UserDefaultsRepository.alertMissedBolusSound.value, snooozedBGReadingTime: nil, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops, snoozeTime: UserDefaultsRepository.alertMissedBolusSnooze.value, audio: playSound)
                        return
                    }
                    
                }
                
            }
            
            // Check Sage
            if UserDefaultsRepository.alertSAGEActive.value && !UserDefaultsRepository.alertSAGEIsSnoozed.value {
                let insertTime = Double(UserDefaultsRepository.alertSageInsertTime.value)
                let alertDistance = Double(UserDefaultsRepository.alertSAGE.value * 60 * 60)
                let delta = now - insertTime
                let tenDays = 10 * 24 * 60 * 60
                if Double(tenDays) - Double(delta) <= alertDistance {
                    AlarmSound.whichAlarm = "Sensor Change Alert"
                    //determine if it is day or night and what should happen
                    if UserDefaultsRepository.nightTime.value {
                        if UserDefaultsRepository.alertSAGENightTime.value { numLoops = -1 }
                        if !UserDefaultsRepository.alertSAGENightTimeAudible.value { playSound = false }
                    } else {
                        if UserDefaultsRepository.alertSAGEDayTime.value { numLoops = -1 }
                        if !UserDefaultsRepository.alertSAGEDayTimeAudible.value { playSound = false }
                    }
                    triggerAlarm(sound: UserDefaultsRepository.alertSAGESound.value, snooozedBGReadingTime: nil, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops, snoozeTime: UserDefaultsRepository.alertSAGESnooze.value, snoozeIncrement: 1, audio: playSound)
                    return
                }
            }
            
            // Check Cage
            if UserDefaultsRepository.alertCAGEActive.value && !UserDefaultsRepository.alertCAGEIsSnoozed.value {
                let insertTime = Double(UserDefaultsRepository.alertCageInsertTime.value)
                let alertDistance = Double(UserDefaultsRepository.alertCAGE.value * 60 * 60)
                let delta = now - insertTime
                let tenDays = 3 * 24 * 60 * 60
                if Double(tenDays) - Double(delta) <= alertDistance {
                    AlarmSound.whichAlarm = "Pump Change Alert"
                    //determine if it is day or night and what should happen
                    if UserDefaultsRepository.nightTime.value {
                        if UserDefaultsRepository.alertCAGENightTime.value { numLoops = -1 }
                        if !UserDefaultsRepository.alertCAGENightTimeAudible.value { playSound = false }
                    } else {
                        if UserDefaultsRepository.alertCAGEDayTime.value { numLoops = -1 }
                        if !UserDefaultsRepository.alertCAGEDayTimeAudible.value { playSound = false }
                    }
                    triggerAlarm(sound: UserDefaultsRepository.alertCAGESound.value, snooozedBGReadingTime: nil, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops, snoozeTime: UserDefaultsRepository.alertCAGESnooze.value, snoozeIncrement: 1, audio: playSound)
                    return
                }
            }
            
            // Check Pump
            if UserDefaultsRepository.alertPump.value && !UserDefaultsRepository.alertPumpIsSnoozed.value {
                let alertAt = Double(UserDefaultsRepository.alertPumpAt.value)
                if latestPumpVolume <= alertAt {
                    AlarmSound.whichAlarm = "Low Insulin Alert"
                    //determine if it is day or night and what should happen
                    if UserDefaultsRepository.nightTime.value {
                        if UserDefaultsRepository.alertPumpNightTime.value { numLoops = -1 }
                        if !UserDefaultsRepository.alertPumpNightTimeAudible.value { playSound = false }
                    } else {
                        if UserDefaultsRepository.alertPumpDayTime.value { numLoops = -1 }
                        if !UserDefaultsRepository.alertPumpDayTimeAudible.value { playSound = false }
                    }
                    triggerAlarm(sound: UserDefaultsRepository.alertPumpSound.value, snooozedBGReadingTime: nil, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops, snoozeTime: UserDefaultsRepository.alertPumpSnoozeHours.value, snoozeIncrement: 1, audio: playSound)
                    return
                }
            }
        }
        
        
        
        
        // still send persistent notification if no alarms trigger and persistent notification is on
        persistentNotification(bgTime: currentBGTime)
        
    }
       
    func checkOverrideAlarms()
    {
        if UserDefaultsRepository.alertSnoozeAllIsSnoozed.value { return }
        
        let recentOverride = overrideGraphData.last
        let recentStart: TimeInterval = recentOverride?.date ?? 0
        let recentEnd: TimeInterval = recentOverride?.endDate ?? 0
        let now = dateTimeUtils.getNowTimeIntervalUTC()
        
        var triggerStart = false
        var triggerEnd = false
        
        // Trigger newly started override
        if now - recentStart > 0 && now - recentStart <= (15 * 60) && recentStart > lastOverrideAlarm {
            triggerStart = true
        } else if now - recentEnd > 0 && now - recentEnd <= (15 * 60) && recentEnd > lastOverrideAlarm {
            triggerEnd = true
        } else {
            return
        }
        
        let overrideName = recentOverride?.reason as! String
       
        var numLoops = 0
        var playSound = true
        if UserDefaultsRepository.alertOverrideStart.value && !UserDefaultsRepository.alertOverrideStartIsSnoozed.value && triggerStart {
            AlarmSound.whichAlarm = overrideName + " Override Started"
            //determine if it is day or night and what should happen
            if UserDefaultsRepository.nightTime.value {
                if UserDefaultsRepository.alertOverrideStartNightTime.value { numLoops = -1 }
                if !UserDefaultsRepository.alertOverrideStartNightTimeAudible.value { playSound = false }
            } else {
                if UserDefaultsRepository.alertOverrideStartDayTime.value { numLoops = -1 }
                if !UserDefaultsRepository.alertOverrideStartDayTimeAudible.value { playSound = false }
            }
            triggerOneTimeAlarm(sound: UserDefaultsRepository.alertOverrideStartSound.value, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops, audio: playSound)
                lastOverrideStartTime = recentStart
                lastOverrideAlarm = now
        } else if UserDefaultsRepository.alertOverrideEnd.value && !UserDefaultsRepository.alertOverrideEndIsSnoozed.value && triggerEnd {
                AlarmSound.whichAlarm = overrideName + " Override Ended"
            //determine if it is day or night and what should happen
            if UserDefaultsRepository.nightTime.value {
                if UserDefaultsRepository.alertOverrideEndNightTime.value { numLoops = -1 }
                if !UserDefaultsRepository.alertOverrideEndNightTimeAudible.value { playSound = false }
            } else {
                if UserDefaultsRepository.alertOverrideEndDayTime.value { numLoops = -1 }
                if !UserDefaultsRepository.alertOverrideEndDayTimeAudible.value { playSound = false }
            }
            triggerOneTimeAlarm(sound: UserDefaultsRepository.alertOverrideEndSound.value, overrideVolume: UserDefaultsRepository.overrideSystemOutputVolume.value, numLoops: numLoops, audio: playSound)
                lastOverrideEndTime = recentEnd
                lastOverrideAlarm = now
        }
    }
    
    func triggerOneTimeAlarm(sound: String, overrideVolume: Bool, numLoops: Int, audio: Bool = true)
    {
        guard let snoozer = self.tabBarController!.viewControllers?[2] as? SnoozeViewController else { return }
        snoozer.updateDisplayWhenTriggered(bgVal: bgUnits.toDisplayUnits(String(bgData[bgData.count - 1].sgv)), directionVal: latestDirectionString ?? "", deltaVal: bgUnits.toDisplayUnits(latestDeltaString) ?? "", minAgoVal: latestMinAgoString ?? "", alertLabelVal: AlarmSound.whichAlarm)
        if audio && !UserDefaultsRepository.alertMuteAllIsMuted.value {
            AlarmSound.setSoundFile(str: sound)
            AlarmSound.play(overrideVolume: overrideVolume, numLoops: numLoops)
            startAlarmPlayingTimer()
        }
    }
    
    func triggerAlarm(sound: String, snooozedBGReadingTime: TimeInterval?, overrideVolume: Bool, numLoops: Int, snoozeTime: Int = 0, snoozeIncrement: Int = 5, audio: Bool = true)
    {
        guard let snoozer = self.tabBarController!.viewControllers?[2] as? SnoozeViewController else { return }
        snoozer.updateDisplayWhenTriggered(bgVal: bgUnits.toDisplayUnits(String(bgData[bgData.count - 1].sgv)), directionVal: latestDirectionString ?? "", deltaVal: bgUnits.toDisplayUnits(latestDeltaString) ?? "", minAgoVal: latestMinAgoString ?? "", alertLabelVal: AlarmSound.whichAlarm)
        snoozer.SnoozeButton.isHidden = false
        snoozer.AlertLabel.isHidden = false
        snoozer.clockLabel.isHidden = true
        snoozer.debugTextView.isHidden = true
        snoozer.snoozeForMinuteLabel.text = String(snoozeTime)
        snoozer.snoozeForMinuteStepper.value = Double(snoozeTime)
        snoozer.snoozeForMinuteStepper.stepValue = Double(snoozeIncrement)
        if snoozeTime != 0 {
            snoozer.snoozeForMinuteStepper.isHidden = false
            snoozer.snoozeForMinuteLabel.isHidden = false
        }
        
        tabBarController?.selectedIndex = 2
        if snooozedBGReadingTime != nil {
            UserDefaultsRepository.snoozedBGReadingTime.value = snooozedBGReadingTime
        }
        if audio && !UserDefaultsRepository.alertMuteAllIsMuted.value {
            AlarmSound.setSoundFile(str: sound)
            AlarmSound.play(overrideVolume: overrideVolume, numLoops: numLoops)
        }
        let bgSeconds = bgData.last!.date
        let now = Date().timeIntervalSince1970
        let secondsAgo = now - bgSeconds
        var timerLength = 290 - secondsAgo
        if timerLength < 10 { timerLength = 290}
        startAlarmPlayingTimer(time: timerLength)
    }
    
    func stopAlarmAtNextReading(){
        
        AlarmSound.whichAlarm = "none"
        guard let snoozer = self.tabBarController!.viewControllers?[2] as? SnoozeViewController else { return }
        snoozer.updateDisplayWhenTriggered(bgVal: bgUnits.toDisplayUnits(String(bgData[bgData.count - 1].sgv)), directionVal: latestDirectionString ?? "", deltaVal: bgUnits.toDisplayUnits(latestDeltaString) ?? "", minAgoVal: latestMinAgoString ?? "", alertLabelVal: AlarmSound.whichAlarm)
        snoozer.SnoozeButton.isHidden = true
        snoozer.AlertLabel.isHidden = true
        if AlarmSound.isPlaying {
            AlarmSound.stop()
        }
    }
    
    func clearOldSnoozes(){
          let date = Date()
          let now = date.timeIntervalSince1970
          var needsReload: Bool = false
          guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
          
          if date > UserDefaultsRepository.alertSnoozeAllTime.value ?? date {
              UserDefaultsRepository.alertSnoozeAllTime.setNil(key: "alertSnoozeAllTime")
              UserDefaultsRepository.alertSnoozeAllIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertSnoozeAllTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertSnoozeAllIsSnoozed", value: false)
            
          }
          
        if date > UserDefaultsRepository.alertMuteAllTime.value ?? date {
            UserDefaultsRepository.alertMuteAllTime.setNil(key: "alertMuteAllTime")
            UserDefaultsRepository.alertMuteAllIsMuted.value = false
            alarms.reloadMuteTime(key: "alertMuteAllTime", setNil: true)
            alarms.reloadIsMuted(key: "alertMuteAllIsMuted", value: false)
          
        }
        
          if date > UserDefaultsRepository.alertUrgentLowSnoozedTime.value ?? date {
              UserDefaultsRepository.alertUrgentLowSnoozedTime.setNil(key: "alertUrgentLowSnoozedTime")
              UserDefaultsRepository.alertUrgentLowIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertUrgentLowSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertUrgentLowIsSnoozed", value: false)
            
          }
          if date > UserDefaultsRepository.alertLowSnoozedTime.value ?? date {
              UserDefaultsRepository.alertLowSnoozedTime.setNil(key: "alertLowSnoozedTime")
              UserDefaultsRepository.alertLowIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertLowSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertLowIsSnoozed", value: false)
         
          }
          if date > UserDefaultsRepository.alertHighSnoozedTime.value ?? date {
              UserDefaultsRepository.alertHighSnoozedTime.setNil(key: "alertHighSnoozedTime")
              UserDefaultsRepository.alertHighIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertHighSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertHighIsSnoozed", value: false)
            
          }
          if date > UserDefaultsRepository.alertUrgentHighSnoozedTime.value ?? date {
              UserDefaultsRepository.alertUrgentHighSnoozedTime.setNil(key: "alertUrgentHighSnoozedTime")
              UserDefaultsRepository.alertUrgentHighIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertUrgentHighSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertUrgentHighIsSnoozed", value: false)
            
          }
          if date > UserDefaultsRepository.alertFastDropSnoozedTime.value ?? date {
              UserDefaultsRepository.alertFastDropSnoozedTime.setNil(key: "alertFastDropSnoozedTime")
              UserDefaultsRepository.alertFastDropIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertFastDropSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertFastDropIsSnoozed", value: false)
             
          }
          if date > UserDefaultsRepository.alertFastRiseSnoozedTime.value ?? date {
              UserDefaultsRepository.alertFastRiseSnoozedTime.setNil(key: "alertFastRiseSnoozedTime")
              UserDefaultsRepository.alertFastRiseIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertFastRiseSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertFastRiseIsSnoozed", value: false)
             
          }
          if date > UserDefaultsRepository.alertMissedReadingSnoozedTime.value ?? date {
              UserDefaultsRepository.alertMissedReadingSnoozedTime.setNil(key: "alertMissedReadingSnoozedTime")
              UserDefaultsRepository.alertMissedReadingIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertMissedReadingSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertMissedReadingIsSnoozed", value: false)
            
          }
          if date > UserDefaultsRepository.alertNotLoopingSnoozedTime.value ?? date {
              UserDefaultsRepository.alertNotLoopingSnoozedTime.setNil(key: "alertNotLoopingSnoozedTime")
              UserDefaultsRepository.alertNotLoopingIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertNotLoopingSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertNotLoopingIsSnoozed", value: false)
           
              
          }
          if date > UserDefaultsRepository.alertMissedBolusSnoozedTime.value ?? date {
              UserDefaultsRepository.alertMissedBolusSnoozedTime.setNil(key: "alertMissedBolusSnoozedTime")
              UserDefaultsRepository.alertMissedBolusIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertMissedBolusSnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertMissedBolusIsSnoozed", value: false)

          }
          if date > UserDefaultsRepository.alertSAGESnoozedTime.value ?? date {
              UserDefaultsRepository.alertSAGESnoozedTime.setNil(key: "alertSAGESnoozedTime")
              UserDefaultsRepository.alertSAGEIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertSAGESnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertSAGEIsSnoozed", value: false)
    
          }
          if date > UserDefaultsRepository.alertCAGESnoozedTime.value ?? date {
              UserDefaultsRepository.alertCAGESnoozedTime.setNil(key: "alertCAGESnoozedTime")
              UserDefaultsRepository.alertCAGEIsSnoozed.value = false
              alarms.reloadSnoozeTime(key: "alertCAGESnoozedTime", setNil: true)
              alarms.reloadIsSnoozed(key: "alertCAGEIsSnoozed", value: false)

          }
        if date > UserDefaultsRepository.alertOverrideStartSnoozedTime.value ?? date {
            UserDefaultsRepository.alertOverrideStartSnoozedTime.setNil(key: "alertOverrideStartSnoozedTime")
            UserDefaultsRepository.alertOverrideStartIsSnoozed.value = false
            alarms.reloadSnoozeTime(key: "alertOverrideStartSnoozedTime", setNil: true)
            alarms.reloadIsSnoozed(key: "alertOverrideStartIsSnoozed", value: false)
        }
        if date > UserDefaultsRepository.alertOverrideEndSnoozedTime.value ?? date {
            UserDefaultsRepository.alertOverrideEndSnoozedTime.setNil(key: "alertOverrideEndSnoozedTime")
            UserDefaultsRepository.alertOverrideEndIsSnoozed.value = false
            alarms.reloadSnoozeTime(key: "alertOverrideEndSnoozedTime", setNil: true)
            alarms.reloadIsSnoozed(key: "alertOverrideEndIsSnoozed", value: false)

        }
        
        if date > UserDefaultsRepository.alertPumpSnoozedTime.value ?? date {
            UserDefaultsRepository.alertPumpSnoozedTime.setNil(key: "alertPumpSnoozedTime")
            UserDefaultsRepository.alertPumpIsSnoozed.value = false
            alarms.reloadSnoozeTime(key: "alertPumpSnoozedTime", setNil: true)
            alarms.reloadIsSnoozed(key: "alertPumpIsSnoozed", value: false)

        }
        
        
      }
    
    func checkQuietHours() {
        if UserDefaultsRepository.quietHourStart.value == nil || UserDefaultsRepository.quietHourEnd.value == nil { return }
        
        var startDateComponents = DateComponents()
        
        let today = Date()
        let todayCalendar = Calendar.current
        let month = todayCalendar.component(.month, from: today)
        let day = todayCalendar.component(.day, from: today)
        let year = todayCalendar.component(.year, from: today)
        let hour = todayCalendar.component(.hour, from: today)
        let minute = todayCalendar.component(.minute, from: today)
        let todayMinutes = (60 * hour) + minute
        
        let start = UserDefaultsRepository.quietHourStart.value
        let startCalendar = Calendar.current
        let startHour = startCalendar.component(.hour, from: start!)
        let startMinute = startCalendar.component(.minute, from: start!)
        let startMinutes = (60 * startHour) + startMinute
        
        let end = UserDefaultsRepository.quietHourEnd.value
        let endCalendar = Calendar.current
        let endHour = endCalendar.component(.hour, from: end!)
        let endMinute = endCalendar.component(.minute, from: end!)
        let endMinutes = (60 * endHour) + endMinute
        
        if todayMinutes >= startMinutes {
            let tomorrow = Date().addingTimeInterval(86400)
            let tomorrowCalendar = Calendar.current
            let end = UserDefaultsRepository.quietHourEnd.value
            let endCalendar = Calendar.current
            
            var components = DateComponents()
            components.month = tomorrowCalendar.component(.month, from: tomorrow)
            components.day = tomorrowCalendar.component(.day, from: tomorrow)
            components.year = tomorrowCalendar.component(.year, from: tomorrow)
            components.hour = endCalendar.component(.hour, from: end!)
            components.minute = endCalendar.component(.minute, from: end!)
            components.second = endCalendar.component(.second, from: end!)
            let snoozeCalendar = Calendar.current
            let snoozeTime = snoozeCalendar.date(from: components)
            
            UserDefaultsRepository.nightTime.value = true
            guard let snoozer = self.tabBarController!.viewControllers?[2] as? SnoozeViewController else { return }
            snoozer.setPresnoozeNight(snoozeTime: snoozeTime!)
        } else if todayMinutes < endMinutes {
            let today = Date()
            let todayCalendar = Calendar.current
            let end = UserDefaultsRepository.quietHourEnd.value
            let endCalendar = Calendar.current
            
            var components = DateComponents()
            components.month = todayCalendar.component(.month, from: today)
            components.day = todayCalendar.component(.day, from: today)
            components.year = todayCalendar.component(.year, from: today)
            components.hour = endCalendar.component(.hour, from: end!)
            components.minute = endCalendar.component(.minute, from: end!)
            components.second = endCalendar.component(.second, from: end!)
            let snoozeCalendar = Calendar.current
            let snoozeTime = snoozeCalendar.date(from: components)
            
            UserDefaultsRepository.nightTime.value = true
            guard let snoozer = self.tabBarController!.viewControllers?[2] as? SnoozeViewController else { return }
            snoozer.setPresnoozeNight(snoozeTime: snoozeTime!)
        } else {
            let today = Date()
            let todayCalendar = Calendar.current
            let end = UserDefaultsRepository.quietHourStart.value
            let endCalendar = Calendar.current
            
            var components = DateComponents()
            components.month = todayCalendar.component(.month, from: today)
            components.day = todayCalendar.component(.day, from: today)
            components.year = todayCalendar.component(.year, from: today)
            components.hour = endCalendar.component(.hour, from: end!)
            components.minute = endCalendar.component(.minute, from: end!)
            components.second = endCalendar.component(.second, from: end!)
            let snoozeCalendar = Calendar.current
            let snoozeTime = snoozeCalendar.date(from: components)
            
            UserDefaultsRepository.nightTime.value = false
            guard let snoozer = self.tabBarController!.viewControllers?[2] as? SnoozeViewController else { return }
            snoozer.setPreSnoozeDay(snoozeTime: snoozeTime!)
        }
        
    }
    
    
    func speakBG(sgv: Int) {
           var speechSynthesizer = AVSpeechSynthesizer()
           var speechUtterance: AVSpeechUtterance = AVSpeechUtterance(string: "Current BG is " + bgUnits.toDisplayUnits(String(sgv)))
           speechUtterance.rate = AVSpeechUtteranceMaximumSpeechRate / 2
           speechUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")
           speechSynthesizer.speak(speechUtterance)
       }
    
}
