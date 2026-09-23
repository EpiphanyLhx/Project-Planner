import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct AITaskInputView: View {
    @Environment(\.dismiss) private var dismiss

    let onApply: (LargeTaskProject, [AIPlanItem]) -> Void
    private let service: AITaskService
    @ObservedObject private var store: StudyStore

    @StateObject private var model = AITaskInputModel()

    init(
        service: AITaskService = AITaskService(),
        store: StudyStore,
        onApply: @escaping (LargeTaskProject, [AIPlanItem]) -> Void
    ) {
        self.service = service
        self.store = store
        self.onApply = onApply
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(20)

            Divider()

            switch model.viewMode {
            case .compose:
                composeContent
            case .list:
                recordList
            case .detail:
                if let record = model.viewingRecord {
                    recordDetail(record)
                } else {
                    Text("记录不存在")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 720, height: 640)
        .alert(
            "AI 拆分失败",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("好") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "未知错误")
        }
        .alert(
            "删除规划记录",
            isPresented: Binding(
                get: { model.recordToDelete != nil },
                set: { if !$0 { model.recordToDelete = nil } }
            )
        ) {
            Button("取消", role: .cancel) { model.recordToDelete = nil }
            Button("仅删除记录") {
                if let record = model.recordToDelete {
                    store.deleteRecord(record.id, deleteTasks: false)
                    if model.viewingRecord?.id == record.id {
                        model.viewingRecord = nil
                        model.viewMode = .list
                    }
                }
                model.recordToDelete = nil
            }
            Button("连同任务一起删除", role: .destructive) {
                if let record = model.recordToDelete {
                    store.deleteRecord(record.id, deleteTasks: true)
                    if model.viewingRecord?.id == record.id {
                        model.viewingRecord = nil
                        model.viewMode = .list
                    }
                }
                model.recordToDelete = nil
            }
        } message: {
            Text("删除后无法恢复。已应用到日历的任务可以选择保留或一并删除。")
        }
    }

    private var composeContent: some View {
        VStack(spacing: 14) {
            conversation

            if let previewPlan = model.previewPlan, let project = model.project {
                preview(project: project, plan: previewPlan)
            } else {
                Spacer(minLength: 0)
            }

            composer
        }
        .padding(20)
    }

    private var header: some View {
        HStack {
            switch model.viewMode {
            case .compose:
                Label("AI 任务规划", systemImage: "sparkles")
                    .font(.headline)
            case .list:
                Label("规划记录", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
            case .detail:
                Label(model.viewingRecord?.title ?? "规划详情", systemImage: "doc.text")
                    .font(.headline)
                    .lineLimit(1)
            }

            Spacer()

            switch model.viewMode {
            case .compose:
                if !store.records.isEmpty {
                    Button {
                        model.viewMode = .list
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.plain)
                    .help("查看规划记录")
                }
            case .list:
                Button("返回") { model.viewMode = .compose }
                    .buttonStyle(.plain)
            case .detail:
                Button("返回") { model.viewMode = .list }
                    .buttonStyle(.plain)
            }

            Button("取消") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .padding(.leading, 8)
        }
    }

    private var conversation: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 24, height: 24)

                    Text("告诉我你的学习目标、材料范围和每天可用时间，我会拆成可以直接执行的每日任务。")
                        .padding(12)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    Spacer(minLength: 72)
                }

                if let message = model.submittedMessage {
                    HStack(alignment: .top) {
                        Spacer(minLength: 72)
                        VStack(alignment: .trailing, spacing: 8) {
                            if !model.submittedImages.isEmpty {
                                attachmentGrid(model.submittedImages, removable: false)
                            }
                            Text(message.isEmpty ? "请根据图片生成学习计划" : message)
                                .textSelection(.enabled)
                                .padding(12)
                                .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                if model.isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在生成排期...")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.leading, 34)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 90, maxHeight: model.previewPlan == nil ? .infinity : 180)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.attachments.isEmpty {
                attachmentGrid(model.attachments, removable: true)
            }

            MultilineTextInput(
                placeholder: "输入学习目标、资料范围和排期偏好...",
                text: $model.description,
                height: 86,
                onPasteImage: { data in
                    model.addPastedImage(data)
                }
            )

            HStack(spacing: 12) {
                Button(action: chooseImages) {
                    Image(systemName: "paperclip")
                }
                .buttonStyle(.plain)
                .help("添加图片")
                .disabled(model.isLoading || model.attachments.count >= 4)

                HStack(spacing: 8) {
                    DayCountStepper(
                        value: $model.expectedDays,
                        range: 1...90,
                        disabled: model.isLoading
                    )

                    Text("AI 将任务分摊到这些天数")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .help("期望完成天数：可点数字直接输入，或用 +/− 调整（1–90 天）")

                Spacer()

                Button(action: generatePlan) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .keyboardShortcut(.return, modifiers: [.command])
                .help("发送")
                .disabled(model.isLoading || !model.canSend)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.1))
        }
    }

    private func attachmentGrid(_ attachments: [AIImageAttachment], removable: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 86, maximum: 110))], spacing: 8) {
            ForEach(attachments) { attachment in
                ZStack(alignment: .topTrailing) {
                    if let image = NSImage(data: attachment.data) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 68)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    if removable {
                        Button {
                            model.attachments.removeAll { $0.id == attachment.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.65))
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                        .help("移除图片")
                    }
                }
                .help(attachment.name)
            }
        }
    }

    private func chooseImages() {
        let panel = NSOpenPanel()
        panel.title = "添加图片"
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else { return }
        let remainingCount = max(0, 4 - model.attachments.count)
        for url in panel.urls.prefix(remainingCount) {
            do {
                let data = try Data(contentsOf: url)
                guard data.count <= 10 * 1_024 * 1_024 else {
                    model.errorMessage = "每张图片不能超过 10 MB。"
                    continue
                }
                guard NSImage(data: data) != nil else {
                    model.errorMessage = "无法读取图片：\(url.lastPathComponent)"
                    continue
                }
                model.attachments.append(
                    AIImageAttachment(
                        name: url.lastPathComponent,
                        mimeType: mimeType(for: url.pathExtension),
                        data: data
                    )
                )
            } catch {
                model.errorMessage = "无法读取图片：\(url.lastPathComponent)"
            }
        }
    }

    private func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "jpg", "jpeg": "image/jpeg"
        case "gif": "image/gif"
        case "webp": "image/webp"
        default: "image/png"
        }
    }

    private func preview(project: LargeTaskProject, plan: [AIPlanItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("排期预览：\(project.title)", systemImage: "calendar.badge.clock")
                .font(.headline)

            HStack(spacing: 8) {
                Text("开始日期")
                    .font(.subheadline)
                DatePicker(
                    "",
                    selection: Binding(
                        get: { model.planStartDate },
                        set: { model.planStartDate = StudyDay.start(for: $0) }
                    ),
                    in: StudyDay.start(for: Date())...,
                    displayedComponents: .date
                )
                .labelsHidden()
                Spacer()
            }

            List {
                ForEach(Dictionary(grouping: plan, by: \.dayOffset).keys.sorted(), id: \.self) { offset in
                    Section(dayTitle(for: offset)) {
                        ForEach(Dictionary(grouping: plan, by: \.dayOffset)[offset] ?? []) { item in
                            HStack(spacing: 12) {
                                Text(item.taskName)
                                    .lineLimit(2)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(item.estimatedMinutes) 分钟")
                                    if let start = item.parsedStartTime,
                                       let end = item.parsedEndTime {
                                        Text("\(TaskTime.text(for: start)) - \(TaskTime.text(for: end))")
                                    } else {
                                        Text("未设定时间")
                                    }
                                }
                                .foregroundStyle(.secondary)
                                .font(.caption.monospacedDigit())

                                Button {
                                    model.editingItem = item
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .help("编辑任务详情")
                                .accessibilityLabel("编辑 \(item.taskName)")
                            }
                            .contextMenu {
                                Button("编辑任务详情", systemImage: "pencil") {
                                    model.editingItem = item
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            .sheet(item: $model.editingItem) { item in
                AIPreviewTaskEditor(
                    item: item,
                    maximumDays: project.expectedDays
                ) { updatedItem in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        model.updatePreviewItem(updatedItem)
                    }
                }
            }

            HStack {
                Button("重新生成") {
                    model.description = model.submittedMessage ?? ""
                    model.attachments = model.submittedImages
                    model.previewPlan = nil
                    model.project = nil
                }
                Spacer()
                Button("应用", systemImage: "checkmark") {
                    var appliedProject = project
                    appliedProject.startDate = StudyDay.start(for: model.planStartDate)
                    // 同步更新规划记录的状态与最新排期。
                    if let index = store.records.firstIndex(where: { $0.project.id == project.id }) {
                        var updated = store.records[index]
                        updated.isApplied = true
                        updated.plan = plan
                        updated.project = appliedProject
                        updated.startDate = appliedProject.startDate
                        store.saveRecord(updated)
                    }
                    onApply(appliedProject, plan)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func generatePlan() {
        model.isLoading = true
        model.errorMessage = nil
        let taskDescription = model.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let images = model.attachments
        model.submittedMessage = taskDescription
        model.submittedImages = images

        // 重规划时复用原记录的 project.id，保证应用后覆盖旧任务。
        let reusedProjectID = model.editingRecordID
            .flatMap { rid in store.records.first { $0.id == rid }?.project.id }
        let recordID = model.editingRecordID ?? UUID()

        Task {
            defer { model.isLoading = false }
            do {
                let plan = try await service.breakdown(
                    description: taskDescription,
                    expectedDays: model.expectedDays,
                    workloadPreference: "",
                    images: images
                )
                let project = LargeTaskProject(
                    id: reusedProjectID ?? UUID(),
                    title: projectTitle(from: taskDescription),
                    expectedDays: model.expectedDays,
                    workloadPreference: taskDescription
                )
                model.project = project
                model.previewPlan = plan
                model.description = ""
                model.attachments = []

                // 保存规划记录（图片写磁盘，记录存 UserDefaults）。
                let imageNames = store.saveRecordImages(images.map { $0.data }, for: recordID)
                let record = PlanningRecord(
                    id: recordID,
                    title: project.title,
                    description: taskDescription,
                    expectedDays: model.expectedDays,
                    startDate: StudyDay.start(for: model.planStartDate),
                    plan: plan,
                    project: project,
                    isApplied: false,
                    imageFileNames: imageNames
                )
                store.saveRecord(record)
                model.editingRecordID = nil
            } catch {
                model.errorMessage = error.localizedDescription
            }
        }
    }

    private func projectTitle(from message: String) -> String {
        let firstLine = message.split(separator: "\n").first.map(String.init) ?? "图片学习计划"
        return String(firstLine.prefix(40))
    }

    /// 预览中某一天的标题：第 N 天 · M月D日 周X。
    private func dayTitle(for offset: Int, startDate: Date) -> String {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: startDate) ?? startDate
        let dateText = date.formatted(
            .dateTime.month(.abbreviated).day().weekday(.short)
                .locale(Locale(identifier: "zh_CN"))
        )
        return "第 \(offset + 1) 天 · \(dateText)"
    }

    private func dayTitle(for offset: Int) -> String {
        dayTitle(for: offset, startDate: model.planStartDate)
    }

    // MARK: - 规划记录列表与详情

    private var recordList: some View {
        VStack(spacing: 0) {
            if store.records.isEmpty {
                Text("暂无规划记录")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.records) { record in
                        recordRow(record)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(20)
    }

    private func recordRow(_ record: PlanningRecord) -> some View {
        Button {
            model.viewingRecord = record
            model.viewMode = .detail
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text(record.createdAt.formatted(
                        .dateTime.year().month().day().hour().minute()
                            .locale(Locale(identifier: "zh_CN"))
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text("\(record.expectedDays) 天 · \(record.plan.count) 项任务")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge(record.isApplied)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("编辑并重新规划", systemImage: "pencil") {
                editRecordForReplanning(record)
            }
            Button("删除", systemImage: "trash", role: .destructive) {
                model.recordToDelete = record
            }
        }
    }

    private func statusBadge(_ applied: Bool) -> some View {
        Text(applied ? "已应用" : "草稿")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                applied ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.2),
                in: Capsule()
            )
            .foregroundStyle(applied ? Color.accentColor : .secondary)
    }

    private func recordDetail(_ record: PlanningRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("原始要求")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(record.description.isEmpty ? "（仅根据图片生成）" : record.description)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                if !record.imageFileNames.isEmpty {
                    attachmentGrid(recordAttachments(record), removable: false)
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            recordDetailPreview(record)

            HStack {
                Button {
                    model.recordToDelete = record
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("删除此记录")

                Spacer()

                Button("编辑并重新规划", systemImage: "pencil") {
                    editRecordForReplanning(record)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }

    private func recordAttachments(_ record: PlanningRecord) -> [AIImageAttachment] {
        store.loadRecordImages(for: record).enumerated().map { index, data in
            AIImageAttachment(name: "记录图片 \(index + 1)", mimeType: "image/png", data: data)
        }
    }

    private func recordDetailPreview(_ record: PlanningRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("排期预览")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let start = record.startDate {
                    let startText = start.formatted(
                        .dateTime.month(.abbreviated).day().weekday(.short)
                            .locale(Locale(identifier: "zh_CN"))
                    )
                    Text("开始于 \(startText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            List {
                ForEach(Dictionary(grouping: record.plan, by: \.dayOffset).keys.sorted(), id: \.self) { offset in
                    Section(dayTitle(for: offset, startDate: record.startDate ?? StudyDay.start(for: Date()))) {
                        ForEach(Dictionary(grouping: record.plan, by: \.dayOffset)[offset] ?? []) { item in
                            HStack(spacing: 12) {
                                Text(item.taskName)
                                    .lineLimit(2)
                                Spacer()
                                Text("\(item.estimatedMinutes) 分钟")
                                    .foregroundStyle(.secondary)
                                    .font(.caption.monospacedDigit())
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            .frame(maxHeight: .infinity)
        }
    }

    /// 把历史记录的要求预填到输入态，供用户修改后重新规划（复用原记录 id）。
    private func editRecordForReplanning(_ record: PlanningRecord) {
        model.editingRecordID = record.id
        model.description = record.description
        model.expectedDays = record.expectedDays
        model.planStartDate = record.startDate ?? StudyDay.start(for: Date())
        model.attachments = recordAttachments(record)
        model.previewPlan = nil
        model.project = nil
        model.submittedMessage = nil
        model.submittedImages = []
        model.viewingRecord = nil
        model.viewMode = .compose
    }
}

private struct MultilineTextInput: View {
    let placeholder: String
    @Binding var text: String
    let height: CGFloat
    var onPasteImage: (Data) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            PasteableTextEditor(text: $text, onPasteImage: onPasteImage)
                .font(.body)
        }
        .frame(height: height)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.primary.opacity(0.16))
        }
    }
}

/// 天数选择器：点 +/− 调整时数字带滚动翻牌动画；点数字可直接键入。
private struct DayCountStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var disabled: Bool = false

    // 本机仅安装了 Command Line Tools（无完整 Xcode），命令行 swift build 找不到
    // SwiftUI 的 State 宏插件，因此这里手写 @State 宏展开后的等价存储与访问器。
    private var _isEditing = State(initialValue: false)
    private var isEditing: Bool {
        get { _isEditing.wrappedValue }
        nonmutating set { _isEditing.wrappedValue = newValue }
    }

    private var _draftText = State(initialValue: "")
    private var draftText: String {
        get { _draftText.wrappedValue }
        nonmutating set { _draftText.wrappedValue = newValue }
    }

    var body: some View {
        HStack(spacing: 0) {
            stepButton(systemName: "minus", enabled: value > range.lowerBound) {
                adjust(by: -1)
            }

            Divider()
                .frame(height: 14)
                .padding(.horizontal, 3)

            HStack(spacing: 2) {
                ZStack {
                    if isEditing {
                        DayNumberField(
                            text: _draftText.projectedValue,
                            onCommit: commit,
                            onCancel: cancel
                        )
                        .frame(width: 34)
                    } else {
                        Text("\(value)")
                            .monospacedDigit()
                            .frame(width: 34)
                            .contentTransition(.numericText())
                            .onTapGesture(perform: beginEditing)
                    }
                }
                .frame(height: 24)

                Text("天")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 3)
            .allowsHitTesting(!disabled)

            Divider()
                .frame(height: 14)
                .padding(.horizontal, 3)

            stepButton(systemName: "plus", enabled: value < range.upperBound) {
                adjust(by: 1)
            }
        }
        .fixedSize()
        .opacity(disabled ? 0.5 : 1)
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.primary.opacity(0.18))
        }
    }

    private func stepButton(
        systemName: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled && !disabled ? Color.primary : Color.secondary.opacity(0.35))
        .disabled(!enabled || disabled)
    }

    private func adjust(by delta: Int) {
        let target = value + delta
        guard range.contains(target) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
            value = target
        }
    }

    private func beginEditing() {
        guard !isEditing, !disabled else { return }
        draftText = String(value)
        isEditing = true
    }

    private func commit() {
        guard isEditing else { return }
        if let number = Int(draftText) {
            let clamped = min(max(number, range.lowerBound), range.upperBound)
            if clamped != value {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                    value = clamped
                }
            }
        }
        isEditing = false
    }

    private func cancel() {
        isEditing = false
    }
}

/// 天数编辑用的无边框 NSTextField：进入窗口即由 AppKit 主动获取焦点并全选，
/// 回车提交、Esc 取消、失焦提交；只接受数字输入。
private struct DayNumberField: NSViewRepresentable {
    @Binding var text: String
    let onCommit: () -> Void
    var onCancel: (() -> Void)?

    func makeNSView(context: Context) -> DayNumberTextField {
        let textField = DayNumberTextField()
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.alignment = .center
        textField.font = NSFont.preferredFont(forTextStyle: .body)
        textField.delegate = context.coordinator
        textField.setContentHuggingPriority(.required, for: .horizontal)
        textField.setContentCompressionResistancePriority(.required, for: .horizontal)
        return textField
    }

    func updateNSView(_ textField: DayNumberTextField, context: Context) {
        if textField.stringValue != text {
            textField.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit, onCancel: onCancel)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        let onCommit: () -> Void
        let onCancel: (() -> Void)?

        init(text: Binding<String>, onCommit: @escaping () -> Void, onCancel: (() -> Void)?) {
            _text = text
            self.onCommit = onCommit
            self.onCancel = onCancel
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            let filtered = String(textField.stringValue.filter(\.isNumber))
            if filtered != textField.stringValue {
                textField.stringValue = filtered
            }
            text = textField.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            onCommit()
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onCommit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                onCancel?()
                return true
            }
            return false
        }
    }
}

/// 进入窗口后立即让自己成为第一响应者并全选文本，保证单击数字即可直接键入。
private final class DayNumberTextField: NSTextField {
    private var didFocus = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard !didFocus, window != nil else { return }
        didFocus = true
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
            self.currentEditor()?.selectAll(nil)
        }
    }
}

/// 支持在粘贴时识别剪贴板中的图片并转为附件的多行文本编辑器。
private struct PasteableTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onPasteImage: ((Data) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        // 必须显式实例化自定义子类；NSTextView.scrollableTextView() 只创建普通 NSTextView，
        // 会导致重写的 paste(_:) 永远不被调用。
        let textView = PasteableTextView(frame: CGRect(x: 0, y: 0, width: 100, height: 86))
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 100,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textContainerInset = NSSize(width: 5, height: 6)
        textView.textColor = .labelColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.onPasteImage = onPasteImage

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? PasteableTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.onPasteImage = onPasteImage
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

/// 重写 paste 方法：剪贴板含图片时回调图片数据，否则走默认文本粘贴。
final class PasteableTextView: NSTextView {
    var onPasteImage: ((Data) -> Void)?

    /// NSTextView 默认只声明文本类型，剪贴板仅有图片时系统会据此把 Paste 菜单置灰，
    /// Cmd+V 也就不会调用 paste(_:)。追加图片类型让菜单验证放行；
    /// 实际粘贴仍由下面重写的 paste(_:) 拦截，不会把图片插进文本。
    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        super.readablePasteboardTypes + [
            NSPasteboard.PasteboardType(rawValue: "public.image"),
            .png,
            .tiff,
            NSPasteboard.PasteboardType(rawValue: "public.jpeg")
        ]
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        if let imageData = Self.extractImageData(from: pasteboard) {
            onPasteImage?(imageData)
            return
        }
        super.paste(sender)
    }

    /// 从剪贴板提取图片数据，统一转为 PNG；无图片时返回 nil。
    private static func extractImageData(from pasteboard: NSPasteboard) -> Data? {
        if let data = pasteboard.data(forType: .png), NSImage(data: data) != nil {
            return data
        }
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(rawValue: "public.jpeg")),
           NSImage(data: data) != nil {
            return data
        }
        if let objects = pasteboard.readObjects(forClasses: [NSImage.self], options: nil),
           let image = objects.first as? NSImage,
           let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            return pngData
        }
        return nil
    }
}

@MainActor
private final class AITaskInputModel: ObservableObject {
    enum ViewMode { case compose, list, detail }

    @Published var viewMode: ViewMode = .compose
    @Published var viewingRecord: PlanningRecord?
    /// 正在编辑重规划的历史记录 id；nil 表示全新规划。
    @Published var editingRecordID: UUID?
    @Published var recordToDelete: PlanningRecord?

    @Published var description = ""
    @Published var expectedDays = 7
    @Published var planStartDate: Date = StudyDay.start(for: Date())
    @Published var attachments: [AIImageAttachment] = []
    @Published var submittedMessage: String?
    @Published var submittedImages: [AIImageAttachment] = []
    @Published var previewPlan: [AIPlanItem]?
    @Published var project: LargeTaskProject?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var editingItem: AIPlanItem?

    var canSend: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty
    }

    /// 将剪贴板中提取到的图片作为附件加入，复用与文件选择一致的上限与体积校验。
    func addPastedImage(_ data: Data) {
        guard !isLoading else { return }
        guard attachments.count < 4 else {
            errorMessage = "最多只能添加 4 张图片。"
            return
        }
        guard data.count <= 10 * 1_024 * 1_024 else {
            errorMessage = "每张图片不能超过 10 MB。"
            return
        }
        guard NSImage(data: data) != nil else {
            errorMessage = "无法读取粘贴的图片。"
            return
        }
        let number = attachments.count + 1
        attachments.append(
            AIImageAttachment(
                name: "粘贴的图片 \(number)",
                mimeType: "image/png",
                data: data
            )
        )
    }

    func updatePreviewItem(_ updatedItem: AIPlanItem) {
        guard let index = previewPlan?.firstIndex(where: { $0.id == updatedItem.id }) else { return }
        previewPlan?[index] = updatedItem
        previewPlan?.sort(by: AIPlanItem.scheduledBefore)
    }
}

private struct AIPreviewTaskEditor: View {
    @Environment(\.dismiss) private var dismiss

    let item: AIPlanItem
    let maximumDays: Int
    let onSave: (AIPlanItem) -> Void

    @StateObject private var model: AIPreviewTaskEditorModel

    init(
        item: AIPlanItem,
        maximumDays: Int,
        onSave: @escaping (AIPlanItem) -> Void
    ) {
        self.item = item
        self.maximumDays = maximumDays
        self.onSave = onSave
        _model = StateObject(wrappedValue: AIPreviewTaskEditorModel(item: item))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("编辑 AI 任务")
                .font(.title2.weight(.semibold))

            Form {
                TextField("任务名称", text: $model.taskName)

                Stepper(
                    "安排在第 \(model.dayNumber) 天",
                    value: $model.dayNumber,
                    in: 1...maximumDays
                )

                LabeledContent("预计时长") {
                    HStack(spacing: 8) {
                        TextField("分钟", text: $model.minutesText)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                        Text("分钟")
                            .foregroundStyle(.secondary)
                        Stepper(
                            "调整时长",
                            value: model.stepperMinutes,
                            in: 1...720,
                            step: 5
                        )
                        .labelsHidden()
                    }
                }

                if model.minutes == nil {
                    Text("时长需在 1 到 720 分钟之间")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Section("计划时间") {
                    Toggle("设定时间段", isOn: $model.hasTimeSlot)

                    if model.hasTimeSlot {
                        DatePicker(
                            "开始时间",
                            selection: $model.startTime,
                            displayedComponents: .hourAndMinute
                        )
                        DatePicker(
                            "结束时间",
                            selection: $model.endTime,
                            displayedComponents: .hourAndMinute
                        )

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

            HStack {
                Spacer()
                Button("取消", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(model.isInvalid)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func save() {
        guard let minutes = model.minutes else { return }
        var updatedItem = item
        updatedItem.taskName = model.taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedItem.dayOffset = model.dayNumber - 1
        updatedItem.estimatedMinutes = minutes
        updatedItem.startTime = model.hasTimeSlot ? TaskTime.text(for: model.startTime) : nil
        updatedItem.endTime = model.hasTimeSlot ? TaskTime.text(for: model.endTime) : nil
        onSave(updatedItem)
        dismiss()
    }
}

@MainActor
private final class AIPreviewTaskEditorModel: ObservableObject {
    @Published var taskName: String
    @Published var dayNumber: Int
    @Published var minutesText: String
    @Published var hasTimeSlot: Bool
    @Published var startTime: Date
    @Published var endTime: Date

    init(item: AIPlanItem) {
        taskName = item.taskName
        dayNumber = item.dayOffset + 1
        minutesText = String(item.estimatedMinutes)
        if let start = item.parsedStartTime, let end = item.parsedEndTime {
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
              (1...720).contains(value) else { return nil }
        return value
    }

    var stepperMinutes: Binding<Int> {
        Binding(
            get: { self.minutes ?? 1 },
            set: { self.minutesText = String($0) }
        )
    }

    var isTimeSlotValid: Bool {
        !hasTimeSlot || TaskTime.minuteOfDay(endTime) > TaskTime.minuteOfDay(startTime)
    }

    var isInvalid: Bool {
        taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        minutes == nil ||
        !isTimeSlotValid
    }
}
