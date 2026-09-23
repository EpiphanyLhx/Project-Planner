import SwiftUI

struct TaskGroup: Identifiable {
    let id: String
    let title: String
    let subject: StudySubject
    let sortOrder: Int
    let tasks: [StudyTask]
}

struct DashboardView: View {
    let now: Date
    @Binding var selectedDate: Date
    @Binding var mode: StudyMode
    let tasks: [StudyTask]
    let modules: [StudyModule]
    let onToggleTask: (StudyTask) -> Void
    let onToggleGroup: (TaskGroup) -> Void
    let onEditGroup: (TaskGroup) -> Void
    let onAddSubtask: (TaskGroup) -> Void
    let onEditTask: (StudyTask) -> Void
    let onDelete: (StudyTask) -> Void

    private var groups: [TaskGroup] {
        let groupedTasks = Dictionary(grouping: tasks, by: \.groupID)
        let moduleByID = Dictionary(uniqueKeysWithValues: modules.map { ($0.id, $0) })
        let groupIDs = Set(groupedTasks.keys).union(moduleByID.keys)

        return groupIDs.compactMap { id in
            let groupTasks = groupedTasks[id, default: []]
            let firstTask = groupTasks.first
            guard let title = moduleByID[id]?.title ?? firstTask?.groupTitle,
                  let subject = moduleByID[id]?.subject ?? firstTask?.subject else {
                return nil
            }
            return TaskGroup(
                id: id,
                title: title,
                subject: subject,
                sortOrder: moduleByID[id]?.sortOrder ?? groupTasks.map(\.sortOrder).min() ?? 0,
                tasks: groupTasks.sorted(by: StudyTask.scheduledBefore)
            )
        }
        .sorted(by: groupScheduledBefore)
    }

    private var completedCount: Int {
        tasks.filter(\.isCompleted).count
    }

    private var completion: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedCount) / Double(tasks.count)
    }

    private var isComplete: Bool {
        !tasks.isEmpty && completedCount == tasks.count
    }

    private var isViewingToday: Bool {
        StudyDay.key(for: selectedDate) == StudyDay.key(for: now)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                header
                WeekDayPicker(selection: $selectedDate, today: now)
                progressPanel

                if isComplete {
                    completionBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                ForEach(groups) { group in
                    TaskGroupView(
                        group: group,
                        onToggleTask: onToggleTask,
                        onToggleGroup: { onToggleGroup(group) },
                        onEditGroup: { onEditGroup(group) },
                        onAddSubtask: { onAddSubtask(group) },
                        onEditTask: onEditTask,
                        onDelete: onDelete
                    )
                }
            }
            .padding(24)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
            .animation(
                .easeInOut(duration: 0.35),
                value: modules.map { "module:\($0.id)" } + tasks.map { "task:\($0.id.uuidString)" }
            )
        }
        .background(
            (isComplete ? Color.green.opacity(0.07) : Color(nsColor: .windowBackgroundColor))
                .animation(.easeInOut(duration: 0.4), value: isComplete)
        )
        .navigationTitle(isViewingToday ? "今日打卡" : "学习打卡")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDate.formatted(.dateTime.month(.wide).day().weekday(.wide).locale(Locale(identifier: "zh_CN"))))
                    .font(.title2.weight(.semibold))
                Text(dayDescription)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(
                isOn: Binding(
                    get: { mode == .full },
                    set: { mode = $0 ? .full : .baseline }
                )
            ) {
                Label(mode.title, systemImage: mode == .full ? "bolt.fill" : "leaf.fill")
            }
            .toggleStyle(.switch)
            .tint(.accentColor)
            .help("切换满负荷模式与底线模式")
        }
    }

    private var dayDescription: String {
        if StudyDay.isSunday(selectedDate) { return "周日复盘日" }
        return isViewingToday ? "稳稳推进今天的计划" : "为这一天安排任务"
    }

    private func groupScheduledBefore(_ lhs: TaskGroup, _ rhs: TaskGroup) -> Bool {
        let leftTime = lhs.tasks.compactMap(\.startMinuteOfDay).min()
        let rightTime = rhs.tasks.compactMap(\.startMinuteOfDay).min()

        switch (leftTime, rightTime) {
        case let (left?, right?) where left != right:
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private var progressPanel: some View {
        HStack(spacing: 18) {
            Gauge(value: completion) {
                Text("今日进度")
            } currentValueLabel: {
                Text(completion, format: .percent.precision(.fractionLength(0)))
                    .font(.headline.monospacedDigit())
                    .contentTransition(.numericText(value: completion))
                    .animation(.smooth(duration: 0.5), value: completion)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(isComplete ? .green : .accentColor)
            .scaleEffect(1.25)
            .frame(width: 72, height: 72)
            .animation(.smooth(duration: 0.5), value: completion)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("今日进度")
                        .font(.headline)
                    Spacer()
                    Text("\(completedCount) / \(tasks.count) 项")
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: Double(completedCount)))
                        .animation(.smooth(duration: 0.5), value: completedCount)
                }
                SmoothProgressBar(
                    value: completion,
                    tint: isComplete ? .green : .accentColor
                )
                Text(progressDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var progressDescription: String {
        if isComplete { return "今日任务全部完成" }
        if completedCount == 0 { return "从第一项开始" }
        return "还剩 \(tasks.count - completedCount) 项"
    }

    private var completionBanner: some View {
        Label("今日任务全部完成，辛苦了", systemImage: "party.popper.fill")
            .font(.headline)
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .symbolEffect(.bounce, value: isComplete)
    }
}
