import SwiftUI

struct FloatingTaskWidgetView: View {
    @AppStorage("isWidgetPinned") private var isPinned = true
    @ObservedObject var store: StudyStore

    let onPinChange: (Bool) -> Void
    let onClose: () -> Void

    private var tasks: [StudyTask] {
        store.todayTasks
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .opacity(0.6)

            if tasks.isEmpty {
                ContentUnavailableView(
                    "今日暂无任务",
                    systemImage: "checkmark.circle",
                    description: Text("可在主窗口中添加任务")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(tasks) { task in
                            TaskRowWidgetView(task: task) {
                                let animation: Animation = task.isCompleted
                                    ? .smooth(duration: 0.45)
                                    : .snappy(duration: 0.25)
                                withAnimation(animation) {
                                    store.toggleTask(task)
                                }
                            }

                            if task.id != tasks.last?.id {
                                Divider()
                                    .padding(.leading, 42)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
        .padding(8)
        .frame(minWidth: 220, maxWidth: .infinity, minHeight: 180, maxHeight: .infinity)
        .background(Color.clear)
        .background(
            PanelAccessor { panel in
                panel.level = isPinned ? .floating : .normal
            }
        )
        .onAppear {
            onPinChange(isPinned)
        }
        .onChange(of: isPinned) {
            onPinChange(isPinned)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                WindowDragArea()

                VStack(alignment: .leading, spacing: 2) {
                    Text("今日任务")
                        .font(.headline)
                    Text(store.now.formatted(
                        .dateTime
                            .month(.abbreviated)
                            .day()
                            .weekday(.abbreviated)
                            .locale(Locale(identifier: "zh_CN"))
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                isPinned.toggle()
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin.slash")
                    .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
                    .scaleEffect(isPinned ? 1 : 0.9)
                    .animation(.snappy(duration: 0.2), value: isPinned)
            }
            .buttonStyle(.plain)
            .help(isPinned ? "取消置顶" : "置顶")
            .accessibilityLabel(isPinned ? "取消置顶" : "置顶")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("隐藏悬浮便签")
            .accessibilityLabel("隐藏悬浮便签")
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct TaskRowWidgetView: View {
    let task: StudyTask
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? "标记为未完成" : "标记为已完成")

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.callout)
                    .lineLimit(2)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .opacity(task.isCompleted ? 0.5 : 1)

                if let start = task.startTime, let end = task.endTime {
                    Text("\(TaskTime.text(for: start)) - \(TaskTime.text(for: end))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("未定")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
