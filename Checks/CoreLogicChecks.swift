import Foundation

@main
enum CoreLogicChecks {
    static func main() throws {
        try checkFullModeDurations()
        try checkSundaySchedule()
        try checkFourAMBoundary()
        try checkTextImport()
        try checkJSONImport()
        try checkAIPlanJSON()
        try checkAIPlanTimeJSON()
        try checkAIPlanSorting()
        try checkAIImageDataURL()
        try checkAIEndpointResolution()
        try checkLegacyTaskDateMigration()
        try checkStudyDayStartIsFourAM()
        try checkLegacyTaskIsVisible()
        try checkWeekContainsSevenIndependentDays()
        try checkRollingDatesStartWithToday()
        try checkModeSelectionIsIndependentByDay()
        try checkExamCountdownUsesSelectedYear()
        try checkTaskTimeSorting()
        try checkStudyModulePersistence()
        print("Core logic checks passed (19/19)")
    }

    private static func checkFullModeDurations() throws {
        let templates = StudySchedule.templates(for: .full, isSunday: false)
        try require(total(for: .math, in: templates) == 180, "数学时长应为 180 分钟")
        try require(total(for: .major, in: templates) == 210, "408 时长应为 210 分钟")
        try require(total(for: .english, in: templates) == 150, "英语时长应为 150 分钟")
        try require(total(for: .review, in: templates) == 30, "复盘时长应为 30 分钟")
    }

    private static func checkSundaySchedule() throws {
        for mode in StudyMode.allCases {
            let templates = StudySchedule.templates(for: mode, isSunday: true)
            try require(!templates.contains { $0.subject == .english }, "周日应隐藏英语")
            try require(templates.contains { $0.id == "sunday-planning" }, "周日应增加周复盘")
        }
    }

    private static func checkFourAMBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try require(TimeZone(identifier: "Asia/Shanghai"), "无效时区")
        let before = try require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 3, minute: 59)),
            "无法创建测试日期"
        )
        let after = try require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 4)),
            "无法创建测试日期"
        )
        try require(StudyDay.key(for: before, calendar: calendar) == "2026-09-17", "4 点前不应重置")
        try require(StudyDay.key(for: after, calendar: calendar) == "2026-09-18", "4 点时应重置")
    }

    private static func checkTextImport() throws {
        let tasks = try TaskImporter.parseText(
            """
            # 数学强化
            - [ ] 高数错题 | 45
            - 线代练习 | 30
            # 英语
            阅读一篇 | 60
            """
        )
        try require(tasks.count == 3, "文本导入数量错误")
        try require(tasks[0] == .init(module: "数学强化", title: "高数错题", minutes: 45), "文本导入内容错误")
        try require(tasks[2].module == "英语", "文本模块分组错误")
    }

    private static func checkJSONImport() throws {
        let data = Data(#"[{"module":"408","title":"操作系统","minutes":50}]"#.utf8)
        let tasks = try TaskImporter.parse(data: data, fileExtension: "json")
        try require(tasks == [.init(module: "408", title: "操作系统", minutes: 50)], "JSON 导入内容错误")
    }

    private static func checkAIPlanJSON() throws {
        let data = Data(#"[{"day_offset":0,"task_name":"第一章例题1-10","estimated_minutes":60}]"#.utf8)
        let plan = try require(try? JSONDecoder().decode([AIPlanItem].self, from: data), "AI JSON 无法解析")
        try require(plan.count == 1 && plan[0].dayOffset == 0 && plan[0].estimatedMinutes == 60, "AI JSON 字段映射错误")
        try require(plan[0].startTime == nil && plan[0].endTime == nil, "旧 AI JSON 应保持未设定时间")
    }

    private static func checkAIPlanTimeJSON() throws {
        let data = Data(#"[{"day_offset":0,"task_name":"第一章例题","estimated_minutes":90,"start_time":"09:15","end_time":"10:45"}]"#.utf8)
        let plan = try require(try? JSONDecoder().decode([AIPlanItem].self, from: data), "带时间的 AI JSON 无法解析")
        try require(plan.count == 1 && plan[0].hasValidTimeSlot, "AI 推荐时间段无效")
        let start = try require(plan[0].parsedStartTime, "AI 开始时间无法解析")
        let end = try require(plan[0].parsedEndTime, "AI 结束时间无法解析")
        try require(TaskTime.text(for: start) == "09:15", "AI 开始时间错误")
        try require(TaskTime.text(for: end) == "10:45", "AI 结束时间错误")
    }

    private static func checkAIPlanSorting() throws {
        let plan = [
            AIPlanItem(dayOffset: 1, taskName: "第二天", estimatedMinutes: 30),
            AIPlanItem(dayOffset: 0, taskName: "未定时间", estimatedMinutes: 30),
            AIPlanItem(
                dayOffset: 0,
                taskName: "上午任务",
                estimatedMinutes: 30,
                startTime: "09:00",
                endTime: "09:30"
            )
        ].sorted(by: AIPlanItem.scheduledBefore)
        try require(plan.map(\.taskName) == ["上午任务", "未定时间", "第二天"], "AI 预览修改后排序错误")
    }

    private static func checkAIImageDataURL() throws {
        let attachment = AIImageAttachment(
            name: "目录.png",
            mimeType: "image/png",
            data: Data([0x01, 0x02, 0x03])
        )
        try require(
            attachment.dataURL == "data:image/png;base64,AQID",
            "AI 图片 Data URL 编码错误"
        )
    }

    private static func checkAIEndpointResolution() throws {
        let deepSeekBase = AIServiceConfiguration.resolvedEndpointURL(from: "https://api.deepseek.com")
        try require(deepSeekBase?.absoluteString == "https://api.deepseek.com/v1/chat/completions", "DeepSeek 基础地址补全错误")

        let deepSeekAnthropic = AIServiceConfiguration.resolvedEndpointURL(from: "https://api.deepseek.com/anthropic")
        try require(deepSeekAnthropic?.absoluteString == "https://api.deepseek.com/v1/chat/completions", "DeepSeek Anthropic 地址迁移错误")

        let zhipuBase = AIServiceConfiguration.resolvedEndpointURL(from: "https://open.bigmodel.cn/api/paas/v4/")
        try require(zhipuBase?.absoluteString == "https://open.bigmodel.cn/api/paas/v4/chat/completions", "智谱基础地址补全错误")

        let fullEndpoint = AIServiceConfiguration.resolvedEndpointURL(from: "https://api.openai.com/v1/chat/completions")
        try require(fullEndpoint?.absoluteString == "https://api.openai.com/v1/chat/completions", "完整接口地址不应改变")
    }

    private static func checkLegacyTaskDateMigration() throws {
        let data = Data("""
        {"id":"00000000-0000-0000-0000-000000000001","studyDay":"2026-09-18","modeRawValue":"full","groupID":"math","groupTitle":"数学","subjectRawValue":"math","title":"做题","durationMinutes":30,"isCompleted":false,"sortOrder":100,"isCustom":false}
        """.utf8)
        let task = try require(try? JSONDecoder().decode(StudyTask.self, from: data), "旧任务无法迁移")
        try require(StudyDay.key(for: task.date) == task.studyDay, "旧任务 date 回退错误: \(task.studyDay) -> \(StudyDay.key(for: task.date))")
        try require(task.startTime == nil && task.endTime == nil, "旧任务应迁移为未设定时间")
    }

    private static func checkStudyDayStartIsFourAM() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try require(TimeZone(identifier: "Asia/Shanghai"), "无效时区")
        let noon = try require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 19, hour: 12)),
            "无法创建测试日期"
        )
        let start = StudyDay.start(for: noon, calendar: calendar)
        try require(calendar.component(.hour, from: start) == 4, "学习日起点应为 4:00")
        try require(StudyDay.key(for: start, calendar: calendar) == "2026-09-19", "任务日期不应被筛选到前一天")
    }

    private static func checkLegacyTaskIsVisible() throws {
        let data = Data("""
        {"studyDay":"2026-09-19","modeRawValue":"full","groupID":"math","groupTitle":"数学","subjectRawValue":"math","title":"做题","durationMinutes":30,"isCompleted":false,"sortOrder":100,"isCustom":false}
        """.utf8)
        let task = try require(try? JSONDecoder().decode(StudyTask.self, from: data), "旧任务无法解析")
        try require(!task.isHidden, "旧任务不应在升级后被隐藏")
    }

    private static func checkWeekContainsSevenIndependentDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try require(TimeZone(identifier: "Asia/Shanghai"), "无效时区")
        let saturday = try require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 19, hour: 12)),
            "无法创建测试日期"
        )
        let days = StudyDay.weekDates(containing: saturday, calendar: calendar)
        try require(days.count == 7, "一周应包含七天")
        try require(StudyDay.key(for: days[0], calendar: calendar) == "2026-09-14", "一周应从周一开始")
        try require(StudyDay.key(for: days[6], calendar: calendar) == "2026-09-20", "一周应在周日结束")
        try require(Set(days.map { StudyDay.key(for: $0, calendar: calendar) }).count == 7, "七天日期必须相互独立")
    }

    private static func checkRollingDatesStartWithToday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try require(TimeZone(identifier: "Asia/Shanghai"), "无效时区")
        let saturday = try require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 19, hour: 12)),
            "无法创建测试日期"
        )
        let days = StudyDay.sevenDates(startingAt: saturday, calendar: calendar)
        try require(days.count == 7, "连续日期应包含七天")
        try require(StudyDay.key(for: days[0], calendar: calendar) == "2026-09-19", "今天应为日期栏第一项")
        try require(StudyDay.key(for: days[6], calendar: calendar) == "2026-09-25", "日期栏应连续显示未来六天")
    }

    private static func checkModeSelectionIsIndependentByDay() throws {
        let savedModes = [
            "2026-09-19": StudyMode.baseline.rawValue,
            "2026-09-20": StudyMode.full.rawValue
        ]
        try require(StudyMode.savedMode(for: "2026-09-19", in: savedModes) == .baseline, "周六应恢复底线模式")
        try require(StudyMode.savedMode(for: "2026-09-20", in: savedModes) == .full, "周日应恢复满负荷模式")
        try require(StudyMode.savedMode(for: "2026-09-21", in: savedModes) == .full, "未设置日期应默认为满负荷模式")
    }

    private static func checkExamCountdownUsesSelectedYear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try require(TimeZone(identifier: "Asia/Shanghai"), "无效时区")
        let date = try require(
            calendar.date(from: DateComponents(year: 2027, month: 9, day: 19)),
            "无法创建测试日期"
        )
        let examDate = ExamCountdown.examDate(for: 2027, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day], from: examDate)
        try require(components.year == 2027 && components.month == 12 && components.day == 19, "考研日期应为所选年份的 12 月 19 日")
        try require(ExamCountdown.daysRemaining(from: date, examYear: 2027, calendar: calendar) == 91, "考研倒计时天数错误")
    }

    private static func checkTaskTimeSorting() throws {
        let early = try require(TaskTime.date(hour: 8, minute: 30), "无法创建开始时间")
        let late = try require(TaskTime.date(hour: 14, minute: 0), "无法创建开始时间")
        let studyDay = "2026-09-19"
        let tasks = [
            StudyTask(
                studyDay: studyDay,
                mode: .full,
                groupID: "test",
                groupTitle: "测试",
                subject: .custom,
                title: "未排时间",
                durationMinutes: 30,
                sortOrder: 1,
                isCustom: true
            ),
            StudyTask(
                studyDay: studyDay,
                mode: .full,
                groupID: "test",
                groupTitle: "测试",
                subject: .custom,
                title: "下午任务",
                durationMinutes: 30,
                startTime: late,
                sortOrder: 2,
                isCustom: true
            ),
            StudyTask(
                studyDay: studyDay,
                mode: .full,
                groupID: "test",
                groupTitle: "测试",
                subject: .custom,
                title: "上午任务",
                durationMinutes: 30,
                startTime: early,
                sortOrder: 3,
                isCustom: true
            )
        ].sorted(by: StudyTask.scheduledBefore)

        try require(tasks.map(\.title) == ["上午任务", "下午任务", "未排时间"], "任务未按开始时间排序")
    }

    private static func checkStudyModulePersistence() throws {
        let date = try require(StudyDay.date(from: "2026-09-19"), "无法创建模块日期")
        let module = StudyModule(
            id: "custom-test",
            date: date,
            studyDay: "2026-09-19",
            mode: .baseline,
            title: "数学强化",
            sortOrder: 410
        )
        let data = try JSONEncoder().encode(module)
        let decoded = try JSONDecoder().decode(StudyModule.self, from: data)
        try require(decoded == module, "空模块无法持久化")
        try require(decoded.mode == .baseline && decoded.subject == .custom, "模块属性恢复错误")
    }

    private static func total(for subject: StudySubject, in templates: [TaskTemplate]) -> Int {
        templates.filter { $0.subject == subject }.map(\.durationMinutes).reduce(0, +)
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw CheckError.failed(message) }
    }

    private static func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw CheckError.failed(message) }
        return value
    }
}

private enum CheckError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case let .failed(message): message
        }
    }
}
