//
//  ContentView.swift
//  MiniClock
//

import SwiftUI
import SwiftData
#if !os(macOS)
import AudioToolbox
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorldClock.displayOrder) private var worldClocks: [WorldClock]
    @Query(sort: \Alarm.hour) private var alarms: [Alarm]
    
    @State private var currentTime = Date()
    @State private var showingAddWorldClock = false
    @State private var showingAddAlarm = false
    @State private var firedAlarm: Alarm?
    @State private var selectedCity = "Asia/Shanghai"
    @State private var customCityName = ""
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private let presetCities: [(String, String)] = [
        ("北京", "Asia/Shanghai"),
        ("纽约", "America/New_York"),
        ("伦敦", "Europe/London"),
        ("东京", "Asia/Tokyo"),
        ("巴黎", "Europe/Paris"),
        ("悉尼", "Australia/Sydney"),
        ("莫斯科", "Europe/Moscow"),
        ("迪拜", "Asia/Dubai"),
        ("洛杉矶", "America/Los_Angeles"),
        ("新加坡", "Asia/Singapore"),
    ]
    
    var body: some View {
        TabView {
            // MARK: - Clock Tab
            ClockTabView(currentTime: currentTime)
                .tabItem {
                    Label("时钟", systemImage: "clock")
                }
            
            // MARK: - World Clock Tab
            WorldClockTabView(
                worldClocks: worldClocks,
                currentTime: currentTime,
                onDelete: deleteClocks,
                onMove: moveClocks,
                onAdd: { showingAddWorldClock = true }
            )
            .tabItem {
                Label("世界时钟", systemImage: "globe")
            }
            
            // MARK: - Alarm Tab
            AlarmTabView(
                alarms: alarms,
                onToggle: { alarm in
                    alarm.isEnabled.toggle()
                },
                onDelete: deleteAlarms,
                onAdd: { showingAddAlarm = true },
                onFire: { alarm in
                    firedAlarm = alarm
                }
            )
            .tabItem {
                Label("闹钟", systemImage: "alarm.fill")
            }
            
            // MARK: - Stopwatch Tab
            StopwatchTabView()
                .tabItem {
                    Label("秒表", systemImage: "stopwatch.fill")
                }
            
            // MARK: - Timer Tab
            TimerTabView()
                .tabItem {
                    Label("计时器", systemImage: "timer")
                }
        }
        .onReceive(timer) { input in
            currentTime = input
            checkAlarms(at: input)
        }
        .sheet(isPresented: $showingAddWorldClock) {
            AddWorldClockSheet(
                presetCities: presetCities,
                selectedCity: $selectedCity,
                customCityName: $customCityName,
                onAdd: addWorldClock,
                onCancel: { showingAddWorldClock = false }
            )
        }
        .sheet(isPresented: $showingAddAlarm) {
            AddAlarmSheet(
                onAdd: addAlarm,
                onCancel: { showingAddAlarm = false }
            )
        }
        .alert(item: $firedAlarm) { alarm in
            Alert(
                title: Text(alarm.label),
                message: Text("时间到了！\n\(alarm.timeString)"),
                dismissButton: .default(Text("知道了")) {
                    alarm.lastFiredAt = Date()
                    if alarm.repeatDays.allSatisfy({ !$0 }) {
                        alarm.isEnabled = false
                    }
                }
            )
        }
    }
    
    // MARK: - Alarm Checking
    private func checkAlarms(at date: Date) {
        for alarm in alarms where alarm.shouldFire(at: date) {
            alarm.lastFiredAt = date
            firedAlarm = alarm
            playAlarmSound()
            if alarm.repeatDays.allSatisfy({ !$0 }) {
                alarm.isEnabled = false
            }
        }
    }
    
    private func playAlarmSound() {
        #if os(macOS)
        NSSound.beep()
        #else
        AudioServicesPlaySystemSound(1304)
        #endif
    }
    
    // MARK: - World Clock Actions
    private func addWorldClock() {
        let preset = presetCities.first { $0.1 == selectedCity }
        let name = customCityName.isEmpty ? (preset?.0 ?? selectedCity) : customCityName
        let newClock = WorldClock(
            cityName: name,
            timeZoneIdentifier: selectedCity,
            displayOrder: worldClocks.count
        )
        modelContext.insert(newClock)
        showingAddWorldClock = false
        customCityName = ""
    }
    
    private func deleteClocks(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(worldClocks[index])
        }
    }
    
    private func moveClocks(from source: IndexSet, to destination: Int) {
        var updated = worldClocks
        updated.move(fromOffsets: source, toOffset: destination)
        for (index, clock) in updated.enumerated() {
            clock.displayOrder = index
        }
    }
    
    // MARK: - Alarm Actions
    private func addAlarm(hour: Int, minute: Int, label: String, repeatDays: [Bool]) {
        let alarm = Alarm(hour: hour, minute: minute, label: label, repeatDays: repeatDays)
        modelContext.insert(alarm)
        showingAddAlarm = false
    }
    
    private func deleteAlarms(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(alarms[index])
        }
    }
}

// MARK: - Clock Tab
struct ClockTabView: View {
    let currentTime: Date
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text(currentTime, format: .dateTime.hour().minute().second())
                .font(.system(size: 64, weight: .thin, design: .rounded))
                .monospacedDigit()
            
            Text(currentTime, format: .dateTime.year().month().day().weekday())
                .font(.title2)
                .foregroundStyle(.secondary)
            
            AnalogClockView(currentTime: currentTime)
                .frame(width: 200, height: 200)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - World Clock Tab
struct WorldClockTabView: View {
    let worldClocks: [WorldClock]
    let currentTime: Date
    let onDelete: (IndexSet) -> Void
    let onMove: (IndexSet, Int) -> Void
    let onAdd: () -> Void
    
    var body: some View {
        NavigationSplitView {
            List {
                Section("本地时间") {
                    LocalClockRow(currentTime: currentTime)
                }
                
                Section("世界时钟") {
                    ForEach(worldClocks) { clock in
                        WorldClockRow(clock: clock, currentTime: currentTime)
                    }
                    .onDelete(perform: onDelete)
                    .onMove(perform: onMove)
                }
            }
            .navigationTitle("世界时钟")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onAdd) {
                        Label("添加", systemImage: "plus")
                    }
                }
            }
        } detail: {
            VStack(spacing: 20) {
                AnalogClockView(currentTime: currentTime)
                    .frame(width: 250, height: 250)
                Text(currentTime, style: .date)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

struct LocalClockRow: View {
    let currentTime: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(currentTime, format: .dateTime.hour().minute().second())
                .font(.system(size: 32, weight: .thin, design: .rounded))
                .monospacedDigit()
            Text(currentTime, format: .dateTime.year().month().day().weekday())
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct WorldClockRow: View {
    let clock: WorldClock
    let currentTime: Date
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(clock.cityName)
                    .font(.headline)
                Text(clock.timeOffsetString())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(clock.currentTimeString())
                    .font(.system(.title2, design: .rounded))
                    .monospacedDigit()
                Text(clock.currentDateString())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Alarm Tab
struct AlarmTabView: View {
    let alarms: [Alarm]
    let onToggle: (Alarm) -> Void
    let onDelete: (IndexSet) -> Void
    let onAdd: () -> Void
    let onFire: (Alarm) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                if alarms.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "alarm.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("无闹钟")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("点击右上角 + 添加闹钟")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                } else {
                    Section {
                        ForEach(alarms) { alarm in
                            AlarmRow(alarm: alarm, onToggle: { onToggle(alarm) })
                        }
                        .onDelete(perform: onDelete)
                    }
                }
            }
            .navigationTitle("闹钟")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onAdd) {
                        Label("添加", systemImage: "plus")
                    }
                }
            }
        }
    }
}

struct AlarmRow: View {
    let alarm: Alarm
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.timeString)
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundStyle(alarm.isEnabled ? .primary : .secondary)
                    .monospacedDigit()
                
                HStack(spacing: 4) {
                    Text(alarm.label)
                    Text("·")
                    Text(alarm.repeatDescription)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Stopwatch Tab
struct StopwatchTabView: View {
    @State private var isRunning = false
    @State private var startTime: Date?
    @State private var pausedElapsed: TimeInterval = 0
    @State private var displayedElapsed: TimeInterval = 0
    @State private var laps: [StopwatchLap] = []
    @State private var timer: Timer?
    
    private var mainButtonTitle: String {
        isRunning ? "停止" : (displayedElapsed > 0 ? "继续" : "启动")
    }
    
    private var mainButtonColor: Color {
        isRunning ? .red : .green
    }
    
    private var secondaryButtonTitle: String {
        isRunning ? "分段" : (displayedElapsed > 0 ? "复位" : "分段")
    }
    
    private var secondaryButtonEnabled: Bool {
        isRunning || displayedElapsed > 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Time Display
            VStack(spacing: 16) {
                Spacer()
                
                Text(formattedTime(displayedElapsed))
                    .font(.system(size: 72, weight: .thin, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(isRunning ? .primary : .secondary)
                
                if let lastLap = laps.last {
                    Text("分段 \(laps.count): \(formattedTime(lastLap.lapTime, showHours: false))")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            
            // Buttons
            HStack(spacing: 60) {
                // Secondary button (Lap / Reset)
                StopwatchButton(
                    title: secondaryButtonTitle,
                    color: .gray,
                    isEnabled: secondaryButtonEnabled
                ) {
                    if isRunning {
                        recordLap()
                    } else {
                        resetStopwatch()
                    }
                }
                
                // Main button (Start / Stop)
                StopwatchButton(
                    title: mainButtonTitle,
                    color: mainButtonColor,
                    isEnabled: true
                ) {
                    toggleStopwatch()
                }
            }
            .padding(.vertical, 30)
            
            // Lap List
            if !laps.isEmpty {
                Divider()
                
                List {
                    ForEach(laps.reversed()) { lap in
                        LapRowView(lap: lap, totalLaps: laps.count)
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: 250)
            }
            
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear {
            stopTimer()
        }
    }
    
    // MARK: - Timer Logic
    private func startTimer() {
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            if let start = startTime {
                displayedElapsed = pausedElapsed + Date().timeIntervalSince(start)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        if let start = startTime {
            pausedElapsed += Date().timeIntervalSince(start)
        }
        startTime = nil
    }
    
    private func toggleStopwatch() {
        if isRunning {
            stopTimer()
            isRunning = false
        } else {
            startTimer()
            isRunning = true
        }
    }
    
    private func recordLap() {
        let lapNumber = laps.count + 1
        let totalTime = displayedElapsed
        let lapTime: TimeInterval
        
        if let previousLap = laps.last {
            lapTime = totalTime - previousLap.totalTime
        } else {
            lapTime = totalTime
        }
        
        let newLap = StopwatchLap(
            number: lapNumber,
            lapTime: lapTime,
            totalTime: totalTime
        )
        laps.append(newLap)
    }
    
    private func resetStopwatch() {
        stopTimer()
        isRunning = false
        displayedElapsed = 0
        pausedElapsed = 0
        laps = []
        startTime = nil
    }
    
    // MARK: - Formatting
    private func formattedTime(_ interval: TimeInterval, showHours: Bool = true) -> String {
        let totalMilliseconds = Int(interval * 100)
        let hours = totalMilliseconds / 360000
        let minutes = (totalMilliseconds % 360000) / 6000
        let seconds = (totalMilliseconds % 6000) / 100
        let centiseconds = totalMilliseconds % 100
        
        if showHours && hours > 0 {
            return String(format: "%02d:%02d:%02d.%02d", hours, minutes, seconds, centiseconds)
        } else {
            return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
        }
    }
}

// MARK: - Stopwatch Button
// MARK: - Timer Tab
struct TimerTabView: View {
    @State private var hours = 0
    @State private var minutes = 1
    @State private var seconds = 0
    @State private var totalSeconds: TimeInterval = 60
    @State private var remainingSeconds: TimeInterval = 60
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var timer: Timer?
    @State private var label = "计时器"
    @State private var showFinishedAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("计时器")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 20)
            
            Spacer()
            
            // Time Display or Picker
            if isRunning || isPaused || remainingSeconds < totalSeconds {
                // Countdown display
                VStack(spacing: 16) {
                    Text(formattedTime(remainingSeconds))
                        .font(.system(size: 72, weight: .thin, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(isRunning ? .primary : .secondary)
                    
                    if isRunning {
                        Text("计时中...")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    } else if isPaused {
                        Text("已暂停")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }
                }
            } else {
                // Time picker
                HStack(spacing: 20) {
                    VStack {
                        Picker("小时", selection: $hours) {
                            ForEach(0..<24) { h in
                                Text("\(h)").tag(h)
                            }
                        }
                        .frame(width: 80)
                        Text("小时")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack {
                        Picker("分钟", selection: $minutes) {
                            ForEach(0..<60) { m in
                                Text("\(m)").tag(m)
                            }
                        }
                        .frame(width: 80)
                        Text("分钟")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack {
                        Picker("秒", selection: $seconds) {
                            ForEach(0..<60) { s in
                                Text("\(s)").tag(s)
                            }
                        }
                        .frame(width: 80)
                        Text("秒")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 180)
            }
            
            Spacer()
            
            // Buttons
            HStack(spacing: 60) {
                // Left button (Cancel)
                TimerControlButton(
                    title: "取消",
                    color: .gray,
                    isEnabled: isRunning || isPaused || remainingSeconds < totalSeconds
                ) {
                    cancelTimer()
                }
                
                // Right button (Start / Pause / Resume)
                if isRunning {
                    TimerControlButton(
                        title: "暂停",
                        color: .orange,
                        isEnabled: true
                    ) {
                        pauseTimer()
                    }
                } else {
                    TimerControlButton(
                        title: isPaused ? "继续" : "开始计时",
                        color: .green,
                        isEnabled: true
                    ) {
                        startTimer()
                    }
                }
            }
            .padding(.vertical, 30)
            
            // Label
            HStack {
                Text("标签")
                Spacer()
                TextField("计时器", text: $label)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 150)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear {
            stopTimer()
        }
        .alert("计时结束", isPresented: $showFinishedAlert) {
            Button("知道了", role: .cancel) {
                cancelTimer()
            }
        } message: {
            Text("\(label) 时间到了！")
        }
    }
    
    // MARK: - Timer Logic
    private func startTimer() {
        if !isPaused {
            // Starting fresh
            totalSeconds = TimeInterval(hours * 3600 + minutes * 60 + seconds)
            remainingSeconds = totalSeconds
        }
        
        isRunning = true
        isPaused = false
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                timerFinished()
            }
        }
    }
    
    private func pauseTimer() {
        isRunning = false
        isPaused = true
        timer?.invalidate()
        timer = nil
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func cancelTimer() {
        stopTimer()
        isRunning = false
        isPaused = false
        remainingSeconds = totalSeconds
        showFinishedAlert = false
    }
    
    private func timerFinished() {
        stopTimer()
        isRunning = false
        isPaused = false
        showFinishedAlert = true
        playTimerSound()
    }
    
    private func playTimerSound() {
        #if os(macOS)
        NSSound.beep()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSSound.beep()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSSound.beep()
        }
        #else
        AudioServicesPlaySystemSound(1304)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AudioServicesPlaySystemSound(1304)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            AudioServicesPlaySystemSound(1304)
        }
        #endif
    }
    
    // MARK: - Formatting
    private func formattedTime(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}

// MARK: - Timer Control Button
struct TimerControlButton: View {
    let title: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title2)
                .fontWeight(.medium)
                .frame(width: 110, height: 90)
                .foregroundColor(color == .gray ? .primary : Color.white)
                .background(color.opacity(isEnabled ? 1.0 : 0.3))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct StopwatchButton: View {
    let title: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.title2)
                .fontWeight(.medium)
                .frame(width: 90, height: 90)
                .foregroundColor(color == .gray ? .primary : Color.white)
                .background(color.opacity(isEnabled ? 1.0 : 0.3))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Stopwatch Lap
struct StopwatchLap: Identifiable {
    let id = UUID()
    let number: Int
    let lapTime: TimeInterval
    let totalTime: TimeInterval
}

struct LapRowView: View {
    let lap: StopwatchLap
    let totalLaps: Int
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let totalMilliseconds = Int(interval * 100)
        let hours = totalMilliseconds / 360000
        let minutes = (totalMilliseconds % 360000) / 6000
        let seconds = (totalMilliseconds % 6000) / 100
        let centiseconds = totalMilliseconds % 100
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%02d", hours, minutes, seconds, centiseconds)
        } else {
            return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
        }
    }
    
    var body: some View {
        HStack {
            Text("分段 \(lap.number)")
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            
            HStack(spacing: 20) {
                Text(formatTime(lap.lapTime))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(lap.number == totalLaps ? .secondary : .primary)
                
                Text(formatTime(lap.totalTime))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 100, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Analog Clock View
struct AnalogClockView: View {
    let currentTime: Date
    
    private var calendar: Calendar { Calendar.current }
    private var hour: Double {
        Double(calendar.component(.hour, from: currentTime) % 12)
        + Double(calendar.component(.minute, from: currentTime)) / 60.0
    }
    private var minute: Double {
        Double(calendar.component(.minute, from: currentTime))
        + Double(calendar.component(.second, from: currentTime)) / 60.0
    }
    private var second: Double {
        Double(calendar.component(.second, from: currentTime))
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 2)
                .foregroundStyle(.primary)
            
            ForEach(0..<12) { i in
                Rectangle()
                    .frame(width: i % 3 == 0 ? 3 : 1, height: i % 3 == 0 ? 12 : 6)
                    .offset(y: -85)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            
            ClockHand(length: 50, width: 4, angle: hour * 30)
            ClockHand(length: 75, width: 2, angle: minute * 6)
            ClockHand(length: 80, width: 1, angle: second * 6, color: .red)
            
            Circle()
                .frame(width: 8, height: 8)
                .foregroundStyle(.red)
        }
    }
}

struct ClockHand: View {
    let length: CGFloat
    let width: CGFloat
    let angle: Double
    var color: Color = .primary
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
    }
}

// MARK: - Add World Clock Sheet
struct AddWorldClockSheet: View {
    let presetCities: [(String, String)]
    @Binding var selectedCity: String
    @Binding var customCityName: String
    let onAdd: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("选择时区") {
                    Picker("城市", selection: $selectedCity) {
                        ForEach(presetCities, id: \.1) { city in
                            Text(city.0).tag(city.1)
                        }
                    }
                }
                Section("自定义名称（可选）") {
                    TextField("留空则使用默认名称", text: $customCityName)
                }
            }
            .navigationTitle("添加世界时钟")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加", action: onAdd)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

// MARK: - Add Alarm Sheet
struct AddAlarmSheet: View {
    let onAdd: (Int, Int, String, [Bool]) -> Void
    let onCancel: () -> Void
    
    @State private var alarmTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
    @State private var label = "闹钟"
    @State private var repeatDays = [false, true, true, true, true, true, false]
    
    private let dayNames = ["日", "一", "二", "三", "四", "五", "六"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("时间", selection: $alarmTime, displayedComponents: .hourAndMinute)
#if os(macOS)
                        .datePickerStyle(.field)
#endif
                        .font(.system(size: 48, weight: .light, design: .rounded))
                }
                
                Section("标签") {
                    TextField("闹钟", text: $label)
                }
                
                Section("重复") {
                    HStack(spacing: 8) {
                        ForEach(0..<7) { index in
                            Button(action: { repeatDays[index].toggle() }) {
                                Text(dayNames[index])
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(repeatDays[index] ? .white : .primary)
                                    .background(repeatDays[index] ? Color.orange : Color.secondary.opacity(0.2))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    HStack {
                        Text("重复")
                        Spacer()
                        Text(repeatDescription)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("添加闹钟")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("存储") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: alarmTime)
                        onAdd(components.hour ?? 7, components.minute ?? 0, label, repeatDays)
                    }
                }
            }
        }
        .frame(minWidth: 450, minHeight: 400)
    }
    
    private var repeatDescription: String {
        if repeatDays.allSatisfy({ $0 }) {
            return "每天"
        } else if repeatDays.allSatisfy({ !$0 }) {
            return "永不"
        } else if repeatDays == [false, true, true, true, true, true, false] {
            return "工作日"
        } else {
            let active = repeatDays.enumerated().compactMap { $1 ? dayNames[$0] : nil }
            return active.joined(separator: " ")
        }
    }
}

extension Alarm: Identifiable {}

#Preview {
    ContentView()
        .modelContainer(for: [WorldClock.self, Alarm.self], inMemory: true)
}
