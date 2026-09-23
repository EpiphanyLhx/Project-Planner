import SwiftUI
import Combine

struct TaskEditorContext: Identifiable {
    let id = UUID()
    let groupID: String?
    let groupTitle: String?
    let subject: StudySubject?
    let initialDate: Date
    let editingTask: StudyTask?

    init(
        groupID: String? = nil,
        groupTitle: String? = nil,
        subject: StudySubject? = nil,
        initialDate: Date,
        editingTask: StudyTask? = nil
    ) {
        self.groupID = groupID
        self.groupTitle = groupTitle
        self.subject = subject
        self.initialDate = initialDate
        self.editingTask = editingTask
    }

    init(editing task: StudyTask) {
        groupID = task.groupID
        groupTitle = task.groupTitle
        subject = task.subject
        initialDate = task.date
        editingTask = task
    }
}

struct TaskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let context: TaskEditorContext
    let onSave: (String, Int, String, [Date], Date?, Date?) -> Void

    @StateObject private var model: TaskEditorModel

    init(context: TaskEditorContext, onSave: @escaping (String, Int, String, [Date], Date?, Date?) -> Void) {
        self.context = context
        self.onSave = onSave
        _model = StateObject(wrappedValue: TaskEditorModel(context: context))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(sheetTitle)
                .font(.title2.weight(.semibold))

            subtaskForm

            HStack {
                Spacer()

                Button("取消", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(context.editingTask == nil ? "添加小任务" : "保存") {
                    saveTask()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isTaskInputInvalid)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private var subtaskForm: some View {
        Form {
            LabeledContent("所属模块", value: context.groupTitle ?? model.trimmedGroupTitle)

            Section("执行日期") {
                MultiDatePicker(dates: $model.dates, monthAnchor: $model.monthAnchor)
            }

            TextField("小任务名称", text: $model.title)
            LabeledContent("预计时长") {
                HStack(spacing: 8) {
                    TextField("分钟", text: minutesTextBinding)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .accessibilityLabel("预计时长（分钟）")
                        .frame(width: 72)
                        .multilineTextAlignment(.trailing)
                    Text("分钟")
                        .foregroundStyle(.secondary)
                    Stepper("调整时长", value: model.stepperMinutes, in: 0...720, step: 5)
                        .labelsHidden()
                }
            }

            if model.minutes == nil {
                Text("时长需在 0 到 720 分钟之间")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Section("计划时间") {
                Toggle("设定时间段", isOn: hasTimeSlotBinding)

                if model.hasTimeSlot {
                    DatePicker(
                        "开始时间",
                        selection: startTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "结束时间",
                        selection: endTimeBinding,
                        displayedComponents: .hourAndMinute
                    )

                    Text("修改时长或开始时间会自动更新结束时间；修改结束时间会自动更新时长。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !model.isTimeSlotValid {
                        Text("结束时间需晚于开始时间")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button("清除时间", systemImage: "xmark.circle", role: .destructive) {
                        model.hasTimeSlot = false
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var sheetTitle: String {
        context.editingTask == nil ? "添加小任务" : "编辑小任务"
    }

    private var isTaskInputInvalid: Bool {
        model.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        model.trimmedGroupTitle.isEmpty ||
        model.minutes == nil ||
        model.dates.isEmpty ||
        !model.isTimeSlotValid
    }

    private func saveTask() {
        guard let minutes = model.minutes else { return }
        onSave(
            model.title.trimmingCharacters(in: .whitespacesAndNewlines),
            minutes,
            model.trimmedGroupTitle,
            model.sortedDates,
            model.hasTimeSlot ? TaskTime.normalized(model.startTime) : nil,
            model.hasTimeSlot ? TaskTime.normalized(model.endTime) : nil
        )
        dismiss()
    }

    // MARK: 联动绑定

    private var minutesTextBinding: Binding<String> {
        Binding(
            get: { model.minutesText },
            set: {
                model.minutesText = $0
                model.resyncEndFromDuration()
            }
        )
    }

    private var hasTimeSlotBinding: Binding<Bool> {
        Binding(
            get: { model.hasTimeSlot },
            set: {
                model.hasTimeSlot = $0
                if $0 { model.resyncEndFromStart() }
            }
        )
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { model.startTime },
            set: {
                model.startTime = $0
                model.resyncEndFromStart()
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { model.endTime },
            set: {
                model.endTime = $0
                model.resyncMinutesFromEnd()
            }
        )
    }
}

@MainActor
private final class TaskEditorModel: ObservableObject {
    @Published var groupTitle: String
    @Published var title: String
    @Published var dates: Set<Date>
    @Published var monthAnchor: Date
    @Published var minutesText: String
    @Published var hasTimeSlot: Bool
    @Published var startTime: Date
    @Published var endTime: Date

    init(context: TaskEditorContext) {
        groupTitle = context.groupTitle ?? ""
        title = context.editingTask?.title ?? ""
        let day = Calendar.current.startOfDay(for: context.initialDate)
        dates = [day]
        monthAnchor = day
        minutesText = String(context.editingTask?.durationMinutes ?? 30)
        if let start = context.editingTask?.startTime,
           let end = context.editingTask?.endTime {
            hasTimeSlot = true
            startTime = start
            endTime = end
        } else {
            hasTimeSlot = false
            startTime = TaskTime.date(hour: 9, minute: 0) ?? Date()
            endTime = TaskTime.date(hour: 10, minute: 0) ?? Date()
        }
    }

    var minutes: Int? {
        guard let value = Int(minutesText.trimmingCharacters(in: .whitespacesAndNewlines)),
              (0...720).contains(value) else {
            return nil
        }
        return value
    }

    var trimmedGroupTitle: String {
        groupTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var sortedDates: [Date] {
        dates.sorted()
    }

    var stepperMinutes: Binding<Int> {
        Binding(
            get: { self.minutes ?? 0 },
            set: {
                self.minutesText = String($0)
                self.resyncEndFromDuration()
            }
        )
    }

    var isTimeSlotValid: Bool {
        !hasTimeSlot || TaskTime.minuteOfDay(endTime) > TaskTime.minuteOfDay(startTime)
    }

    // MARK: 时长 ↔ 时间段联动

    /// 时长变化：开始时间不动，结束时间 = 开始 + 时长。
    func resyncEndFromDuration() {
        guard hasTimeSlot, let minutes else { return }
        endTime = Self.clampedEnd(from: startTime, minutes: minutes)
    }

    /// 开始时间变化：时长不动，结束时间随动。
    func resyncEndFromStart() {
        guard hasTimeSlot, let minutes else { return }
        endTime = Self.clampedEnd(from: startTime, minutes: minutes)
    }

    /// 结束时间变化：时长 = 结束 − 开始。
    func resyncMinutesFromEnd() {
        guard hasTimeSlot else { return }
        let difference = Int(endTime.timeIntervalSince(startTime) / 60)
        minutesText = String(max(0, difference))
    }

    /// 计算开始时间加上时长后的结束时间，越过当天 23:59 时钳制到 23:59（不支持跨天）。
    private static func clampedEnd(
        from start: Date,
        minutes: Int,
        calendar: Calendar = .current
    ) -> Date {
        guard let nextMidnight = calendar.date(
            byAdding: .day, value: 1, to: calendar.startOfDay(for: start)
        ), let dayEnd = calendar.date(byAdding: .minute, value: -1, to: nextMidnight) else {
            return start
        }
        let proposed = start.addingTimeInterval(TimeInterval(minutes * 60))
        return min(proposed, dayEnd)
    }
}
