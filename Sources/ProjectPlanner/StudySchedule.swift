import Foundation

struct TaskTemplate: Equatable {
    let id: String
    let groupID: String
    let groupTitle: String
    let subject: StudySubject
    let title: String
    let durationMinutes: Int
    let sortOrder: Int
}

enum StudySchedule {
    static func templates(for mode: StudyMode, isSunday: Bool) -> [TaskTemplate] {
        var result: [TaskTemplate]

        switch mode {
        case .full:
            result = [
                task("math-review", "math", "数学 · 3 小时", .math, "复盘", 45, 100),
                task("math-course", "math", "数学 · 3 小时", .math, "看课", 75, 110),
                task("math-practice", "math", "数学 · 3 小时", .math, "做题", 60, 120),
                task("major-review", "major", "408 专业课 · 3.5 小时", .major, "滚动复习", 60, 200),
                task("major-course", "major", "408 专业课 · 3.5 小时", .major, "新课", 90, 210),
                task("major-choice", "major", "408 专业课 · 3.5 小时", .major, "选择题", 60, 220),
                task("english-words", "english", "英语 · 2.5 小时", .english, "单词", 30, 300),
                task("english-reading", "english", "英语 · 2.5 小时", .english, "阅读精读", 120, 310),
                task("night-review", "night-review", "睡前复盘 · 30 分钟", .review, "回顾今日完成情况", 30, 400)
            ]
        case .baseline:
            result = [
                task("baseline-math", "baseline-math", "数学 · 2 小时", .math, "保底做题", 120, 100),
                task("baseline-major", "baseline-major", "408 专业课 · 2 小时", .major, "保底看课 / 复习", 120, 200)
            ]
        }

        if isSunday {
            result.removeAll { $0.subject == .english }
            result.append(
                task(
                    "sunday-planning",
                    "sunday-planning",
                    "周日专项 · 半天",
                    .planning,
                    "本周数学错题回看与下周规划",
                    240,
                    350
                )
            )
        }

        return result.sorted { $0.sortOrder < $1.sortOrder }
    }

    private static func task(
        _ id: String,
        _ groupID: String,
        _ groupTitle: String,
        _ subject: StudySubject,
        _ title: String,
        _ durationMinutes: Int,
        _ sortOrder: Int
    ) -> TaskTemplate {
        TaskTemplate(
            id: id,
            groupID: groupID,
            groupTitle: groupTitle,
            subject: subject,
            title: title,
            durationMinutes: durationMinutes,
            sortOrder: sortOrder
        )
    }
}
