//
//  Alarm.swift
//  MiniClock
//

import Foundation
import SwiftData

@Model
final class Alarm {
    var id: UUID
    var hour: Int
    var minute: Int
    var label: String
    var isEnabled: Bool
    var repeatDays: [Bool] // [日, 一, 二, 三, 四, 五, 六]
    var soundName: String
    var createdAt: Date
    var lastFiredAt: Date?
    
    init(
        hour: Int = 7,
        minute: Int = 0,
        label: String = "闹钟",
        repeatDays: [Bool] = [false, true, true, true, true, true, false],
        soundName: String = "default"
    ) {
        self.id = UUID()
        self.hour = hour
        self.minute = minute
        self.label = label
        self.isEnabled = true
        self.repeatDays = repeatDays
        self.soundName = soundName
        self.createdAt = Date()
        self.lastFiredAt = nil
    }
    
    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }
    
    var repeatDescription: String {
        let dayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let activeDays = repeatDays.enumerated().compactMap { $1 ? dayNames[$0] : nil }
        if activeDays.count == 7 {
            return "每天"
        } else if activeDays.count == 0 {
            return "仅一次"
        } else if Set(activeDays) == Set(["周一", "周二", "周三", "周四", "周五"]) {
            return "工作日"
        } else if Set(activeDays) == Set(["周六", "周日"]) {
            return "周末"
        } else {
            return activeDays.joined(separator: " ")
        }
    }
    
    func shouldFire(at date: Date) -> Bool {
        guard isEnabled else { return false }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        guard let currentHour = components.hour,
              let currentMinute = components.minute,
              let weekday = components.weekday else { return false }
        
        // weekday: 1=Sunday, 2=Monday, ..., 7=Saturday
        // repeatDays: 0=Sunday, 1=Monday, ..., 6=Saturday
        let repeatIndex = weekday - 1
        let shouldRepeatToday = repeatDays[repeatIndex]
        
        // Check if time matches
        let timeMatches = currentHour == hour && currentMinute == minute
        
        if !timeMatches { return false }
        
        // Check if we already fired this minute
        if let lastFired = lastFiredAt {
            let lastComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: lastFired)
            let nowComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            if lastComponents.year == nowComponents.year &&
               lastComponents.month == nowComponents.month &&
               lastComponents.day == nowComponents.day &&
               lastComponents.hour == nowComponents.hour &&
               lastComponents.minute == nowComponents.minute {
                return false
            }
        }
        
        // If no repeat days are set, fire once
        if repeatDays.allSatisfy({ !$0 }) {
            return true
        }
        
        // Fire if today is in repeat days
        return shouldRepeatToday
    }
    
    func nextFireDate(from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        guard let baseDate = calendar.date(from: components) else { return nil }
        
        // If time already passed today, start from tomorrow
        var checkDate = baseDate
        if checkDate <= date {
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate)!
        }
        
        // Find next valid day
        for _ in 0..<14 {
            let weekday = calendar.component(.weekday, from: checkDate) - 1
            if repeatDays[weekday] {
                return checkDate
            }
            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate)!
        }
        
        return nil
    }
}
