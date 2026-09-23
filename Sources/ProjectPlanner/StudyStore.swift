import Combine
import Foundation

@MainActor
final class StudyStore: ObservableObject {
    @Published private(set) var tasks: [StudyTask]
    @Published private(set) var modules: [StudyModule]
    @Published private(set) var projects: [LargeTaskProject]
    @Published private(set) var records: [PlanningRecord]
    @Published var mode: StudyMode {
        didSet {
            guard !isRestoringMode else { return }
            modesByStudyDay[studyDay] = mode.rawValue
            defaults.set(modesByStudyDay, forKey: Keys.modesByStudyDay)
        }
    }
    @Published var now: Date
    @Published var selectedDate: Date {
        didSet { restoreModeForSelectedDay() }
    }
    @Published var isImporting = false
    @Published var isAITaskInputPresented = false
    @Published var isModuleCreatorPresented = false
    @Published var isSettingsPresented = false
    @Published var isDeletePlansPresented = false
    @Published var editorContext: TaskEditorContext?
    @Published var editingGroup: TaskGroup?
    @Published var presentedError: PresentedError?

    private let defaults: UserDefaults
    private var modesByStudyDay: [String: String]
    private var deletedTemplateKeys: Set<String>
    private var isRestoringMode = false

    init(defaults: UserDefaults = .standard) {
        let initialDate = Date()
        let initialStudyDay = StudyDay.key(for: initialDate)
        var savedModes = defaults.dictionary(forKey: Keys.modesByStudyDay) as? [String: String]
        if savedModes == nil {
            let legacyMode = StudyMode(rawValue: defaults.string(forKey: Keys.legacyMode) ?? "") ?? .full
            savedModes = [initialStudyDay: legacyMode.rawValue]
            defaults.set(savedModes, forKey: Keys.modesByStudyDay)
        }

        self.defaults = defaults
        now = initialDate
        selectedDate = initialDate
        modesByStudyDay = savedModes ?? [:]
        deletedTemplateKeys = Set(defaults.stringArray(forKey: Keys.deletedTemplateKeys) ?? [])
        mode = StudyMode.savedMode(for: initialStudyDay, in: modesByStudyDay)
        if let data = defaults.data(forKey: Keys.modules),
           let savedModules = try? JSONDecoder().decode([StudyModule].self, from: data) {
            modules = savedModules
        } else {
            modules = []
        }
        if let data = defaults.data(forKey: Keys.tasks),
           let savedTasks = try? JSONDecoder().decode([StudyTask].self, from: data) {
            deletedTemplateKeys.formUnion(
                savedTasks.compactMap { task in
                    guard task.isHidden,
                          task.source == .regular,
                          !task.isCustom,
                          let templateID = task.templateID else { return nil }
                    return Self.deletedTemplateKey(
                        studyDay: StudyDay.key(for: task.date),
                        mode: task.mode,
                        templateID: templateID
                    )
                }
            )
            tasks = Self.migrate(savedTasks)
        } else {
            tasks = []
        }
        if let data = defaults.data(forKey: Keys.projects),
           let savedProjects = try? JSONDecoder().decode([LargeTaskProject].self, from: data) {
            projects = savedProjects
        } else {
            projects = []
        }
        if let data = defaults.data(forKey: Keys.records),
           let savedRecords = try? JSONDecoder().decode([PlanningRecord].self, from: data) {
            records = savedRecords
        } else {
            records = []
        }
        save()
    }

    var studyDay: String {
        StudyDay.key(for: selectedDate)
    }

    var visibleTasks: [StudyTask] {
        tasks
            .filter {
                !$0.isHidden &&
                StudyDay.key(for: $0.date) == studyDay &&
                ($0.source == .ai || $0.mode == mode)
            }
            .sorted(by: StudyTask.scheduledBefore)
    }

    var visibleModules: [StudyModule] {
        modules
            .filter {
                StudyDay.key(for: $0.date) == studyDay &&
                $0.mode == mode
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var todayTasks: [StudyTask] {
        let today = StudyDay.key(for: now)
        let todayMode = StudyMode.savedMode(for: today, in: modesByStudyDay)
        return tasks
            .filter {
                !$0.isHidden &&
                StudyDay.key(for: $0.date) == today &&
                ($0.source == .ai || $0.mode == todayMode)
            }
            .sorted(by: StudyTask.scheduledBefore)
    }

    var completion: Double {
        guard !visibleTasks.isEmpty else { return 0 }
        return Double(visibleTasks.filter(\.isCompleted).count) / Double(visibleTasks.count)
    }

    var hasTasksForSelectedDay: Bool {
        tasks.contains {
            !$0.isHidden && StudyDay.key(for: $0.date) == studyDay
        } || modules.contains {
            StudyDay.key(for: $0.date) == studyDay
        }
    }

    var hasAnyPlans: Bool {
        !tasks.isEmpty || !modules.isEmpty || !projects.isEmpty
    }

    func synchronizeSchedule() {
        let templates = StudySchedule.templates(for: mode, isSunday: StudyDay.isSunday(selectedDate))
        let existingIDs = Set(
            tasks
                .filter {
                    StudyDay.key(for: $0.date) == studyDay &&
                    $0.source == .regular &&
                    $0.mode == mode &&
                    $0.templateID.map {
                        !deletedTemplateKeys.contains(
                            Self.deletedTemplateKey(
                                studyDay: studyDay,
                                mode: mode,
                                templateID: $0
                            )
                        )
                    } ?? true
                }
                .compactMap(\.templateID)
        )

        for template in templates where !existingIDs.contains(template.id) {
            let deletionKey = Self.deletedTemplateKey(
                studyDay: studyDay,
                mode: mode,
                templateID: template.id
            )
            guard !deletedTemplateKeys.contains(deletionKey) else { continue }
            tasks.append(
                StudyTask(
                    date: StudyDay.start(for: selectedDate),
                    studyDay: studyDay,
                    mode: mode,
                    templateID: template.id,
                    groupID: template.groupID,
                    groupTitle: template.groupTitle,
                    subject: template.subject,
                    title: template.title,
                    durationMinutes: template.durationMinutes,
                    sortOrder: template.sortOrder,
                    isCustom: false,
                    source: .regular
                )
            )
        }
        save()
    }

    func tick(_ date: Date) {
        let wasViewingToday = StudyDay.key(for: selectedDate) == StudyDay.key(for: now)
        now = date
        if wasViewingToday {
            selectedDate = date
        }
        synchronizeSchedule()
    }

    func toggleTask(_ task: StudyTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isCompleted.toggle()
        save()
    }

    func toggleGroup(_ group: TaskGroup) {
        let shouldComplete = !group.tasks.allSatisfy(\.isCompleted)
        let ids = Set(group.tasks.map(\.id))
        for index in tasks.indices where ids.contains(tasks[index].id) {
            tasks[index].isCompleted = shouldComplete
        }
        save()
    }

    func addModule(title: String, dates: [Date]) {
        for target in normalizedTargets(from: dates) {
            let nextOrder = max(
                tasks.filter { StudyDay.key(for: $0.date) == target.day }.map(\.sortOrder).max() ?? 400,
                modules.filter { $0.studyDay == target.day }.map(\.sortOrder).max() ?? 400
            ) + 10
            modules.append(
                StudyModule(
                    date: target.date,
                    studyDay: target.day,
                    mode: mode,
                    title: title,
                    sortOrder: nextOrder
                )
            )
        }
        save()
    }

    func addTask(
        title: String,
        minutes: Int,
        groupTitle: String,
        dates: [Date],
        startTime: Date?,
        endTime: Date?,
        context: TaskEditorContext
    ) {
        let groupID = context.groupID ?? "custom-\(UUID().uuidString)"
        for target in normalizedTargets(from: dates) {
            let nextOrder = (tasks.filter { StudyDay.key(for: $0.date) == target.day }.map(\.sortOrder).max() ?? 400) + 10
            tasks.append(
                StudyTask(
                    date: target.date,
                    studyDay: target.day,
                    mode: mode,
                    groupID: groupID,
                    groupTitle: context.groupTitle ?? groupTitle,
                    subject: context.subject ?? .custom,
                    title: title,
                    durationMinutes: minutes,
                    startTime: startTime,
                    endTime: endTime,
                    sortOrder: nextOrder,
                    isCustom: true,
                    source: .regular
                )
            )
        }
        save()
    }

    func editTask(
        _ task: StudyTask,
        title: String,
        minutes: Int,
        dates: [Date],
        startTime: Date?,
        endTime: Date?
    ) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let targets = normalizedTargets(from: dates)
        guard let firstTarget = targets.first else { return }

        tasks[index].title = title
        tasks[index].durationMinutes = minutes
        tasks[index].date = firstTarget.date
        tasks[index].studyDay = firstTarget.day
        tasks[index].startTime = startTime
        tasks[index].endTime = endTime

        // 其余选中日期各生成一个未完成副本。
        for target in targets.dropFirst() {
            var copy = tasks[index]
            copy.id = UUID()
            copy.date = target.date
            copy.studyDay = target.day
            copy.isCompleted = false
            tasks.append(copy)
        }
        save()
    }

    /// 把日历选中的自然日归一化为去重、升序的学习日（当日 4:00）。
    private func normalizedTargets(
        from dates: [Date],
        calendar: Calendar = .current
    ) -> [(date: Date, day: String)] {
        var seen = Set<String>()
        return dates.compactMap { raw in
            let components = calendar.dateComponents(
                [.year, .month, .day],
                from: calendar.startOfDay(for: raw)
            )
            let day = String(
                format: "%04d-%02d-%02d",
                components.year ?? 0,
                components.month ?? 0,
                components.day ?? 0
            )
            guard seen.insert(day).inserted,
                  let targetDate = StudyDay.date(from: day) else { return nil }
            return (targetDate, day)
        }
        .sorted { $0.date < $1.date }
    }

    func deleteTask(_ task: StudyTask) {
        guard tasks.contains(where: { $0.id == task.id }) else { return }

        if task.source == .regular, !task.isCustom, let templateID = task.templateID {
            deletedTemplateKeys.insert(
                Self.deletedTemplateKey(
                    studyDay: StudyDay.key(for: task.date),
                    mode: task.mode,
                    templateID: templateID
                )
            )
        }
        tasks.removeAll { $0.id == task.id }
        save()
    }

    /// 将未完成任务后推一天；若后续日期存在相同标题的未完成任务，则链式一并后推。
    func postponeTask(_ task: StudyTask) {
        guard !task.isCompleted else { return }
        let taskTitle = task.title
        let calendar = Calendar.current

        // 从任务当天起，收集连续日期中所有相同标题的未完成任务。
        var tasksToPostpone: [StudyTask] = []
        var cursor = task.date
        while true {
            let dayKey = StudyDay.key(for: cursor)
            let dayTasks = tasks.filter {
                StudyDay.key(for: $0.date) == dayKey &&
                $0.title == taskTitle &&
                !$0.isCompleted
            }
            guard !dayTasks.isEmpty else { break }
            tasksToPostpone.append(contentsOf: dayTasks)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        // 从最远日期开始依次后移，避免同一天内重复移动。
        for item in tasksToPostpone.reversed() {
            guard let index = tasks.firstIndex(where: { $0.id == item.id }),
                  let target = calendar.date(byAdding: .day, value: 1, to: tasks[index].date) else { continue }
            tasks[index].date = StudyDay.start(for: target)
            tasks[index].studyDay = StudyDay.key(for: target)
            tasks[index].isCompleted = false
        }
        save()
    }

    func deleteAllTasksForSelectedDay() {
        let selectedStudyDay = studyDay

        let selectedTasks = tasks.filter {
            StudyDay.key(for: $0.date) == selectedStudyDay
        }
        for task in selectedTasks {
            if task.source == .regular, !task.isCustom, let templateID = task.templateID {
                deletedTemplateKeys.insert(
                    Self.deletedTemplateKey(
                        studyDay: StudyDay.key(for: task.date),
                        mode: task.mode,
                        templateID: templateID
                    )
                )
            }
        }
        tasks.removeAll { StudyDay.key(for: $0.date) == selectedStudyDay }
        modules.removeAll {
            StudyDay.key(for: $0.date) == selectedStudyDay
        }
        save()
    }

    func deleteAllPlans() {
        for task in tasks {
            if task.source == .regular, !task.isCustom, let templateID = task.templateID {
                deletedTemplateKeys.insert(
                    Self.deletedTemplateKey(
                        studyDay: StudyDay.key(for: task.date),
                        mode: task.mode,
                        templateID: templateID
                    )
                )
            }
        }
        tasks.removeAll()
        modules.removeAll()
        projects.removeAll()
        save()
    }

    func editModule(
        groupID: String,
        taskIDs: Set<UUID>,
        title: String,
        durations: [TaskDurationUpdate]
    ) {
        let durationByID = Dictionary(uniqueKeysWithValues: durations.map { ($0.id, $0.minutes) })
        if let moduleIndex = modules.firstIndex(where: { $0.id == groupID }) {
            modules[moduleIndex].title = title
        }
        tasks = tasks.map { task in
            guard taskIDs.contains(task.id) else { return task }
            var updatedTask = task
            updatedTask.groupTitle = title
            if let minutes = durationByID[task.id] {
                updatedTask.durationMinutes = minutes
            }
            return updatedTask
        }
        save()
    }

    func importTasks(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }

            let drafts = try TaskImporter.parse(
                data: Data(contentsOf: url),
                fileExtension: url.pathExtension
            )
            let grouped = Dictionary(grouping: drafts, by: \.module)
            var order = (visibleTasks.map(\.sortOrder).max() ?? 400) + 10

            for module in drafts.map(\.module).uniqued() {
                let groupID = "imported-\(UUID().uuidString)"
                for draft in grouped[module, default: []] {
                    tasks.append(
                        StudyTask(
                            date: StudyDay.start(for: selectedDate),
                            studyDay: studyDay,
                            mode: mode,
                            groupID: groupID,
                            groupTitle: module,
                            subject: .custom,
                            title: draft.title,
                            durationMinutes: draft.minutes,
                            sortOrder: order,
                            isCustom: true,
                            source: .regular
                        )
                    )
                    order += 1
                }
                order += 10
            }
            save()
        } catch {
            presentedError = PresentedError(message: error.localizedDescription)
        }
    }

    func applyAIPlan(project: LargeTaskProject, plan: [AIPlanItem]) {
        // 覆盖：先删除同一项目已落库的任务，再写入新排期。
        tasks.removeAll { $0.projectID == project.id }
        let baseDate = StudyDay.start(for: project.startDate ?? now)
        var order = 500

        for item in plan {
            guard item.dayOffset >= 0, item.dayOffset < project.expectedDays else { continue }
            let taskDate = Calendar.current.date(byAdding: .day, value: item.dayOffset, to: baseDate) ?? baseDate
            let dayKey = StudyDay.key(for: taskDate)
            tasks.append(
                StudyTask(
                    date: taskDate,
                    studyDay: dayKey,
                    mode: mode,
                    groupID: "ai-project-\(project.id.uuidString)",
                    groupTitle: project.title,
                    subject: .custom,
                    title: item.taskName,
                    durationMinutes: item.estimatedMinutes,
                    startTime: item.parsedStartTime,
                    endTime: item.parsedEndTime,
                    sortOrder: order,
                    isCustom: true,
                    source: .ai,
                    projectID: project.id,
                    projectTag: project.title
                )
            )
            order += 1
        }

        var appliedProject = project
        appliedProject.isApplied = true
        projects.removeAll { $0.id == project.id }
        projects.append(appliedProject)
        save()
    }

    // MARK: - Planning records

    /// 保存或更新一条规划记录（按 id 去重），按创建时间倒序排列。
    func saveRecord(_ record: PlanningRecord) {
        records.removeAll { $0.id == record.id }
        records.append(record)
        records.sort { $0.createdAt > $1.createdAt }
        persistRecords()
    }

    /// 删除规划记录；deleteTasks 为 true 时连同已落到日历的任务一起删除。
    func deleteRecord(_ id: UUID, deleteTasks: Bool) {
        guard let record = records.first(where: { $0.id == id }) else { return }
        if deleteTasks {
            tasks.removeAll { $0.projectID == record.project.id }
        }
        records.removeAll { $0.id == id }
        deleteRecordImages(for: id)
        persistRecords()
        save()
    }

    /// 将图片数据写入该记录的磁盘目录，返回文件名列表。
    func saveRecordImages(_ images: [Data], for recordID: UUID) -> [String] {
        let dir = recordImageDirectory(for: recordID)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var names: [String] = []
        for (index, data) in images.enumerated() {
            let name = "image-\(index).png"
            do {
                try data.write(to: dir.appendingPathComponent(name))
                names.append(name)
            } catch {
                continue
            }
        }
        return names
    }

    /// 读取记录关联的图片数据。
    func loadRecordImages(for record: PlanningRecord) -> [Data] {
        let dir = recordImageDirectory(for: record.id)
        return record.imageFileNames.compactMap { name in
            try? Data(contentsOf: dir.appendingPathComponent(name))
        }
    }

    private func recordImageDirectory(for recordID: UUID) -> URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        return appSupport
            .appendingPathComponent("ProjectPlanner", isDirectory: true)
            .appendingPathComponent("PlanningRecords", isDirectory: true)
            .appendingPathComponent(recordID.uuidString, isDirectory: true)
    }

    private func deleteRecordImages(for recordID: UUID) {
        let dir = recordImageDirectory(for: recordID)
        try? FileManager.default.removeItem(at: dir)
    }

    private func persistRecords() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Keys.records)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        defaults.set(data, forKey: Keys.tasks)
        defaults.set(Array(deletedTemplateKeys).sorted(), forKey: Keys.deletedTemplateKeys)
        if let moduleData = try? JSONEncoder().encode(modules) {
            defaults.set(moduleData, forKey: Keys.modules)
        }
        if let projectData = try? JSONEncoder().encode(projects) {
            defaults.set(projectData, forKey: Keys.projects)
        }
        if let recordData = try? JSONEncoder().encode(records) {
            defaults.set(recordData, forKey: Keys.records)
        }
    }

    private func restoreModeForSelectedDay() {
        let savedMode = StudyMode.savedMode(for: studyDay, in: modesByStudyDay)
        guard savedMode != mode else { return }

        isRestoringMode = true
        mode = savedMode
        isRestoringMode = false
    }

    private static func migrate(_ savedTasks: [StudyTask]) -> [StudyTask] {
        var regularTasks: [String: StudyTask] = [:]
        var dynamicTasks: [StudyTask] = []

        for savedTask in savedTasks {
            var task = savedTask
            guard !task.isHidden else { continue }
            if !task.studyDay.isEmpty,
               StudyDay.key(for: task.date) != task.studyDay,
               let correctedDate = StudyDay.date(from: task.studyDay) {
                task.date = correctedDate
            }

            guard task.source == .regular, !task.isCustom, let templateID = task.templateID else {
                dynamicTasks.append(task)
                continue
            }

            let key = "\(task.studyDay)|\(task.modeRawValue)|\(templateID)"
            if var existing = regularTasks[key] {
                existing.isCompleted = existing.isCompleted || task.isCompleted
                if task.createdAt < existing.createdAt {
                    existing.createdAt = task.createdAt
                }
                regularTasks[key] = existing
            } else {
                regularTasks[key] = task
            }
        }

        return (Array(regularTasks.values) + dynamicTasks).sorted {
            if $0.date == $1.date { return $0.sortOrder < $1.sortOrder }
            return $0.date < $1.date
        }
    }

    private enum Keys {
        static let tasks = "studyTasks"
        static let modules = "studyModules"
        static let projects = "largeTaskProjects"
        static let records = "planningRecords"
        static let legacyMode = "selectedStudyMode"
        static let modesByStudyDay = "studyModesByDay"
        static let deletedTemplateKeys = "deletedStudyTemplateKeys"
    }

    private static func deletedTemplateKey(
        studyDay: String,
        mode: StudyMode,
        templateID: String
    ) -> String {
        "\(studyDay)|\(mode.rawValue)|\(templateID)"
    }
}

struct PresentedError: Identifiable {
    let id = UUID()
    let message: String
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
