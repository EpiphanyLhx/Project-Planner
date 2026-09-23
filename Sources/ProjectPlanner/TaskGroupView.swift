import SwiftUI

struct TaskGroupView: View {
    let group: TaskGroup
    let onToggleTask: (StudyTask) -> Void
    let onToggleGroup: () -> Void
    let onEditGroup: () -> Void
    let onAddSubtask: () -> Void
    let onEditTask: (StudyTask) -> Void
    let onDelete: (StudyTask) -> Void

    private var isComplete: Bool {
        !group.tasks.isEmpty && group.tasks.allSatisfy(\.isCompleted)
    }

    private var duration: Int {
        group.tasks.reduce(0) { $0 + $1.durationMinutes }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onToggleGroup) {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isComplete ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help(isComplete ? "取消完成整个模块" : "完成整个模块")
                .disabled(group.tasks.isEmpty)

                Image(systemName: group.subject.symbol)
                    .font(.title3)
                    .foregroundStyle(group.subject.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(.headline)
                    if let tag = group.tasks.first(where: { $0.source == .ai })?.projectTag {
                        Label("#\(tag)", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if duration > 0 {
                        Text(duration.formattedDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: onEditGroup) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("编辑模块名称和所需时间")

                Button(action: onAddSubtask) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("添加小任务")
            }
            .padding(16)

            if !group.tasks.isEmpty {
                Divider()
                    .padding(.leading, 52)

                ForEach(group.tasks) { task in
                    TaskRow(
                        task: task,
                        onToggle: { onToggleTask(task) },
                        onEdit: { onEditTask(task) },
                        onDelete: { onDelete(task) }
                    )
                    if task.id != group.tasks.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(group.subject.tint.opacity(0.15))
        }
    }
}

private struct TaskRow: View {
    let task: StudyTask
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? "标记为未完成" : "标记为已完成")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .strikethrough(task.isCompleted, color: .secondary)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)

                    if task.source == .ai {
                        Text("AI")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.12), in: Capsule())
                    }
                }

                Label(task.timeRangeText, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(task.startMinuteOfDay == nil ? .tertiary : .secondary)
            }

            Spacer()

            if task.durationMinutes > 0 {
                Text(task.durationMinutes.formattedDuration)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("编辑小任务")
            .accessibilityLabel("编辑小任务")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("删除任务")
            .accessibilityLabel("删除任务")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .contextMenu {
            Button("编辑小任务", systemImage: "pencil", action: onEdit)

            Divider()

            Button(
                "删除任务",
                systemImage: "trash",
                role: .destructive,
                action: onDelete
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: task.isCompleted ? "取消完成" : "完成", onToggle)
    }
}

private extension StudySubject {
    var tint: Color {
        switch self {
        case .math: .blue
        case .major: .teal
        case .english: .indigo
        case .review: .mint
        case .planning: .orange
        case .custom: .secondary
        }
    }
}

private extension Int {
    var formattedDuration: String {
        guard self >= 60 else { return self == 0 ? "未设置时长" : "\(self) 分钟" }
        let hours = self / 60
        let minutes = self % 60
        return minutes == 0 ? "\(hours) 小时" : "\(hours) 小时 \(minutes) 分钟"
    }
}
