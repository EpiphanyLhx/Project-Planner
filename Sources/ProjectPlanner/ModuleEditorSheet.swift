import Combine
import SwiftUI

struct TaskDurationUpdate: Identifiable {
    let id: UUID
    var minutes: Int
}

struct ModuleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (String, [TaskDurationUpdate]) -> Void

    @StateObject private var model: ModuleEditorModel

    init(
        group: TaskGroup,
        onSave: @escaping (String, [TaskDurationUpdate]) -> Void
    ) {
        self.onSave = onSave
        _model = StateObject(wrappedValue: ModuleEditorModel(group: group))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("编辑模块")
                .font(.title2.weight(.semibold))

            Form {
                TextField("模块名称", text: $model.title)

                Section("所需时间") {
                    ForEach(model.tasks.indices, id: \.self) { index in
                        Stepper(
                            "\(model.tasks[index].taskTitle) · \(model.tasks[index].minutes) 分钟",
                            value: $model.tasks[index].minutes,
                            in: 0...720,
                            step: 5
                        )
                    }

                    LabeledContent("合计", value: "\(model.totalMinutes) 分钟")
                        .fontWeight(.medium)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    onSave(model.trimmedTitle, model.durationUpdates)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(model.trimmedTitle.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}

@MainActor
private final class ModuleEditorModel: ObservableObject {
    struct EditableTask: Identifiable {
        let id: UUID
        let taskTitle: String
        var minutes: Int
    }

    @Published var title: String
    @Published var tasks: [EditableTask]

    init(group: TaskGroup) {
        title = group.title
        tasks = group.tasks.map {
            EditableTask(id: $0.id, taskTitle: $0.title, minutes: $0.durationMinutes)
        }
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var totalMinutes: Int {
        tasks.reduce(0) { $0 + $1.minutes }
    }

    var durationUpdates: [TaskDurationUpdate] {
        tasks.map { TaskDurationUpdate(id: $0.id, minutes: $0.minutes) }
    }
}
