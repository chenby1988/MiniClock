//
//  WorldClock.swift
//  MiniClock
//

import Foundation
import SwiftData

@Model
final class WorldClock {
    var cityName: String
    var timeZoneIdentifier: String
    var displayOrder: Int
    var addedAt: Date
    
    init(cityName: String, timeZoneIdentifier: String, displayOrder: Int = 0) {
        self.cityName = cityName
        self.timeZoneIdentifier = timeZoneIdentifier
        self.displayOrder = displayOrder
        self.addedAt = Date()
    }
    
    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
    }
    
    func currentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "MM月dd日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: Date())
    }
    
    func timeOffsetString() -> String {
        let localOffset = TimeZone.current.secondsFromGMT()
        let targetOffset = timeZone.secondsFromGMT()
        let diff = (targetOffset - localOffset) / 3600
        if diff == 0 {
            return "当地时间"
        } else if diff > 0 {
            return "+\(diff)小时"
        } else {
            return "\(diff)小时"
        }
    }
}
