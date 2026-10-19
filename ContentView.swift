import SwiftUI
import UserNotifications

@MainActor
final class IntervalModel: ObservableObject {
    @Published var walkMinutes = 2
    @Published var runMinutes = 5
    @Published var repeats = 6
    @Published var running = false
    @Published var paused = false
    @Published var elapsed: TimeInterval = 0
    @Published var notificationAllowed = false

    private var startedAt: Date?
    private var accumulated: TimeInterval = 0
    private var timer: Timer?
    private let notificationCenter = UNUserNotificationCenter.current()
    private let prefix = "mdrun."

    var totalSeconds: TimeInterval { TimeInterval((walkMinutes + runMinutes) * 60 * repeats) }
    private var walkSeconds: TimeInterval { TimeInterval(walkMinutes * 60) }
    private var runSeconds: TimeInterval { TimeInterval(runMinutes * 60) }
    private var cycleSeconds: TimeInterval { walkSeconds + runSeconds }
    var complete: Bool { elapsed >= totalSeconds && totalSeconds > 0 }
    var currentCycle: Int { min(repeats, Int(min(elapsed, max(0,totalSeconds-0.001)) / cycleSeconds) + 1) }
    var walking: Bool { elapsed.truncatingRemainder(dividingBy: cycleSeconds) < walkSeconds }
    var phaseName: String { complete ? "운동 완료" : (walking ? "걷기" : "달리기") }
    var phaseRemaining: Int {
        if complete { return 0 }
        let inside = elapsed.truncatingRemainder(dividingBy: cycleSeconds)
        return max(0, Int(ceil((walking ? walkSeconds - inside : cycleSeconds - inside))))
    }
    var overallRemaining: Int { max(0, Int(ceil(totalSeconds - elapsed))) }
    var progress: Double { totalSeconds == 0 ? 0 : min(1, elapsed / totalSeconds) }

    func requestPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async { self?.notificationAllowed = granted }
        }
    }

    func start() {
        if complete { reset() }
        if running { return }
        running = true
        paused = false
        startedAt = Date()
        scheduleNotifications()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tick()
    }

    func pause() {
        tick()
        accumulated = elapsed
        startedAt = nil
        running = false
        paused = true
        timer?.invalidate()
        timer = nil
        clearNotifications()
    }

    func reset() {
        running = false
        paused = false
        startedAt = nil
        accumulated = 0
        elapsed = 0
        timer?.invalidate()
        timer = nil
        clearNotifications()
    }

    private func tick() {
        if let startedAt { elapsed = min(totalSeconds, accumulated + Date().timeIntervalSince(startedAt)) }
        if complete {
            running = false
            paused = false
            timer?.invalidate()
            timer = nil
            startedAt = nil
            accumulated = totalSeconds
        }
    }

    private func clearNotifications() {
        let ids = (0..<65).map { "\(prefix)\($0)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ids)
    }

    private func scheduleNotifications() {
        clearNotifications()
        // iOS allows approximately 64 pending local notifications per app.
        // 30 sets = 60 transitions + one finish notification.
        let current = elapsed
        var events: [(TimeInterval, String, String)] = []
        for index in 0..<repeats {
            let base = TimeInterval(index) * cycleSeconds
            let runStart = base + walkSeconds
            if runStart > current + 0.5 {
                events.append((runStart-current, "달리기 시작", "\(index+1)/\(repeats)세트 · \(runMinutes)분 달리세요."))
            }
            let nextWalk = base + cycleSeconds
            if index < repeats-1 && nextWalk > current + 0.5 {
                events.append((nextWalk-current, "걷기 시작", "\(index+2)/\(repeats)세트 · \(walkMinutes)분 걸으세요."))
            }
        }
        if totalSeconds > current + 0.5 { events.append((totalSeconds-current, "운동 완료", "오늘의 인터벌 운동을 마쳤습니다.")) }
        for (index, event) in events.prefix(64).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = event.1
            content.body = event.2
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, event.0), repeats: false)
            notificationCenter.add(UNNotificationRequest(identifier: "\(prefix)\(index)", content: content, trigger: trigger))
        }
    }
}

struct ContentView: View {
    @StateObject private var model = IntervalModel()
    private func clock(_ seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("M&D RUN TIMER").font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("걷기 · 달리기 인터벌").foregroundStyle(.gray)
                VStack(spacing: 10) {
                    Text(model.phaseName).font(.system(size: 35, weight: .bold))
                        .foregroundStyle(model.complete ? .yellow : (model.walking ? .mint : .orange))
                    Text(clock(model.phaseRemaining)).font(.system(size: 78, weight: .bold, design: .monospaced))
                        .minimumScaleFactor(0.6).lineLimit(1).foregroundStyle(.white)
                    ProgressView(value: model.progress).tint(.mint)
                    Text("\(model.currentCycle) / \(model.repeats) 세트")
                        .font(.title3.bold()).foregroundStyle(.white)
                    Text("전체 남은 시간  \(clock(model.overallRemaining))")
                        .foregroundStyle(.gray)
                }
                .padding(22).frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))

                VStack(spacing: 16) {
                    settingRow("걷기", value: $model.walkMinutes, range: 1...60, unit: "분", disabled: model.running || model.paused)
                    settingRow("달리기", value: $model.runMinutes, range: 1...60, unit: "분", disabled: model.running || model.paused)
                    settingRow("반복", value: $model.repeats, range: 1...30, unit: "회", disabled: model.running || model.paused)
                }
                .padding(16).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))

                HStack(spacing: 12) {
                    Button(model.running ? "일시정지" : (model.paused ? "계속" : "시작")) {
                        model.running ? model.pause() : model.start()
                    }
                    .buttonStyle(BigButton(color: .mint))
                    Button("초기화") { model.reset() }.buttonStyle(BigButton(color: .gray))
                }
                Text("총 운동 시간: \((model.walkMinutes + model.runMinutes) * model.repeats)분")
                    .foregroundStyle(.white)
                Text("화면이 꺼져 있을 때는 iOS 알림음으로 단계 전환을 안내합니다. 알림 허용과 무음 모드 설정을 확인하세요. 알림은 음성 낭독이 아닙니다.")
                    .font(.footnote).foregroundStyle(.gray)
            }
            .padding(20)
        }
        .background(Color(red: 0.055, green: 0.085, blue: 0.13).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { model.requestPermission() }
    }

    private func settingRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String, disabled: Bool) -> some View {
        HStack {
            Text(title).font(.title3.bold()).foregroundStyle(.white)
            Spacer()
            Button { value.wrappedValue = max(range.lowerBound, value.wrappedValue-1) } label: {
                Image(systemName: "minus.circle.fill").font(.title)
            }.disabled(disabled || value.wrappedValue == range.lowerBound)
            Text("\(value.wrappedValue)\(unit)").font(.title3.monospacedDigit()).frame(width: 75)
                .foregroundStyle(.white)
            Button { value.wrappedValue = min(range.upperBound, value.wrappedValue+1) } label: {
                Image(systemName: "plus.circle.fill").font(.title)
            }.disabled(disabled || value.wrappedValue == range.upperBound)
        }.foregroundStyle(.mint)
    }
}

private struct BigButton: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.title3.bold()).foregroundStyle(.black)
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .background(color.opacity(configuration.isPressed ? 0.65 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}
