//
//  MiniClockApp.swift
//  MiniClock
//

import SwiftUI
import SwiftData

@main
struct MiniClockApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorldClock.self,
            Alarm.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 900, height: 600)
    }
}
