import Foundation

struct StudyTask: Codable, Identifiable, Equatable {
    var id: UUID
    /// The normalized study-day start at 04:00, used for date filtering.
    var date: Date
    var studyDay: String
    var modeRawValue: String
    var templateID: String?
    var groupID: String
    var groupTitle: String
    var subjectRawValue: String
    var title: String
    var durationMinutes: Int
    var startTime: Date?
    var endTime: Date?
    var isCompleted: Bool
    var isHidden: Bool
    var sortOrder: Int
    var isCustom: Bool
    var sourceRawValue: String
    var projectID: UUID?
    var projectTag: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date? = nil,
        studyDay: String,
        mode: StudyMode,
        templateID: String? = nil,
        groupID: String,
        groupTitle: String,
        subject: StudySubject,
        title: String,
        durationMinutes: Int,
        startTime: Date? = nil,
        endTime: Date? = nil,
        isCompleted: Bool = false,
        isHidden: Bool = false,
        sortOrder: Int,
        isCustom: Bool,
        source: StudyTaskSource = .regular,
        projectID: UUID? = nil,
        projectTag: String? = nil
    ) {
        self.id = id
        self.date = date ?? StudyDay.date(from: studyDay) ?? StudyDay.start(for: .now)
        self.studyDay = studyDay
        self.modeRawValue = mode.rawValue
        self.templateID = templateID
        self.groupID = groupID
        self.groupTitle = groupTitle
        self.subjectRawValue = subject.rawValue
        self.title = title
        self.durationMinutes = durationMinutes
        self.startTime = startTime.map { TaskTime.normalized($0) }
        self.endTime = endTime.map { TaskTime.normalized($0) }
        self.isCompleted = isCompleted
        self.isHidden = isHidden
        self.sortOrder = sortOrder
        self.isCustom = isCustom
        self.sourceRawValue = source.rawValue
        self.projectID = projectID
        self.projectTag = projectTag
        self.createdAt = .now
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, studyDay, modeRawValue, templateID, groupID, groupTitle
        case subjectRawValue, title, durationMinutes, startTime, endTime, isCompleted, isHidden, sortOrder
        case isCustom, sourceRawValue, projectID, projectTag, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        studyDay = try container.decodeIfPresent(String.self, forKey: .studyDay) ?? ""
        if let savedDate = try container.decodeIfPresent(Date.self, forKey: .date) {
            date = savedDate
        } else if let legacyDate = StudyDay.date(from: studyDay) {
            date = legacyDate
        } else {
            date = StudyDay.start(for: .now)
        }
        modeRawValue = try container.decodeIfPresent(String.self, forKey: .modeRawValue) ?? StudyMode.full.rawValue
        templateID = try container.decodeIfPresent(String.self, forKey: .templateID)
        groupID = try container.decodeIfPresent(String.self, forKey: .groupID) ?? "legacy"
        groupTitle = try container.decodeIfPresent(String.self, forKey: .groupTitle) ?? "任务"
        subjectRawValue = try container.decodeIfPresent(String.self, forKey: .subjectRawValue) ?? StudySubject.custom.rawValue
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "未命名任务"
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 0
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        sourceRawValue = try container.decodeIfPresent(String.self, forKey: .sourceRawValue) ?? StudyTaskSource.regular.rawValue
        projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID)
        projectTag = try container.decodeIfPresent(String.self, forKey: .projectTag)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? date
    }

    var mode: StudyMode {
        StudyMode(rawValue: modeRawValue) ?? .full
    }

    var subject: StudySubject {
        StudySubject(rawValue: subjectRawValue) ?? .custom
    }

    var source: StudyTaskSource {
        StudyTaskSource(rawValue: sourceRawValue) ?? .regular
    }

    var startMinuteOfDay: Int? {
        startTime.map { TaskTime.minuteOfDay($0) }
    }

    var timeRangeText: String {
        guard let startTime, let endTime else { return "未设定时间" }
        return "\(TaskTime.text(for: startTime)) - \(TaskTime.text(for: endTime))"
    }

    static func scheduledBefore(_ lhs: StudyTask, _ rhs: StudyTask) -> Bool {
        switch (lhs.startMinuteOfDay, rhs.startMinuteOfDay) {
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
}

enum TaskTime {
    static func date(hour: Int, minute: Int, calendar: Calendar = .current) -> Date? {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return calendar.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: hour, minute: minute))
    }

    static func date(fromHHmm value: String?, calendar: Calendar = .current) -> Date? {
        guard let value else { return nil }
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        return date(hour: hour, minute: minute, calendar: calendar)
    }

    static func normalized(_ date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return self.date(
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            calendar: calendar
        ) ?? date
    }

    static func minuteOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func text(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }
}

enum StudyTaskSource: String, Codable {
    case regular
    case ai
}

struct StudyModule: Codable, Identifiable, Equatable {
    var id: String
    var date: Date
    var studyDay: String
    var modeRawValue: String
    var title: String
    var subjectRawValue: String
    var sortOrder: Int

    init(
        id: String = "custom-\(UUID().uuidString)",
        date: Date,
        studyDay: String,
        mode: StudyMode,
        title: String,
        subject: StudySubject = .custom,
        sortOrder: Int
    ) {
        self.id = id
        self.date = date
        self.studyDay = studyDay
        self.modeRawValue = mode.rawValue
        self.title = title
        self.subjectRawValue = subject.rawValue
        self.sortOrder = sortOrder
    }

    var mode: StudyMode {
        StudyMode(rawValue: modeRawValue) ?? .full
    }

    var subject: StudySubject {
        StudySubject(rawValue: subjectRawValue) ?? .custom
    }
}

struct LargeTaskProject: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var expectedDays: Int
    var workloadPreference: String
    var createdAt: Date
    var isApplied: Bool
    /// 计划开始执行的日期（当天 4:00 基准）；旧数据或未设置时回退为应用当天。
    var startDate: Date?

    init(
        id: UUID = UUID(),
        title: String,
        expectedDays: Int,
        workloadPreference: String,
        createdAt: Date = .now,
        isApplied: Bool = false,
        startDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.expectedDays = expectedDays
        self.workloadPreference = workloadPreference
        self.createdAt = createdAt
        self.isApplied = isApplied
        self.startDate = startDate
    }
}

/// AI 规划记录：保存原始要求、生成的排期、项目和图片引用，支持回看、编辑重规划和删除。
struct PlanningRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var createdAt: Date
    var title: String
    var description: String
    var expectedDays: Int
    var startDate: Date?
    var plan: [AIPlanItem]
    var project: LargeTaskProject
    var isApplied: Bool
    /// 图片文件名，存于 Application Support/ProjectPlanner/PlanningRecords/<id>/。
    var imageFileNames: [String]

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        title: String,
        description: String,
        expectedDays: Int,
        startDate: Date? = nil,
        plan: [AIPlanItem],
        project: LargeTaskProject,
        isApplied: Bool = false,
        imageFileNames: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.description = description
        self.expectedDays = expectedDays
        self.startDate = startDate
        self.plan = plan
        self.project = project
        self.isApplied = isApplied
        self.imageFileNames = imageFileNames
    }
}

enum StudyMode: String, CaseIterable, Identifiable {
    case full
    case baseline

    var id: String { rawValue }

    static func savedMode(for studyDay: String, in valuesByStudyDay: [String: String]) -> StudyMode {
        StudyMode(rawValue: valuesByStudyDay[studyDay] ?? "") ?? .full
    }

    var title: String {
        switch self {
        case .full: "满负荷模式"
        case .baseline: "底线模式"
        }
    }

    var shortTitle: String {
        switch self {
        case .full: "满负荷"
        case .baseline: "底线"
        }
    }
}

enum StudySubject: String {
    case math
    case major
    case english
    case review
    case planning
    case custom

    var title: String {
        switch self {
        case .math: "数学"
        case .major: "408 专业课"
        case .english: "英语"
        case .review: "睡前复盘"
        case .planning: "周复盘"
        case .custom: "自定义"
        }
    }

    var symbol: String {
        switch self {
        case .math: "function"
        case .major: "desktopcomputer"
        case .english: "character.book.closed"
        case .review: "moon.stars"
        case .planning: "calendar.badge.checkmark"
        case .custom: "checklist"
        }
    }
}
