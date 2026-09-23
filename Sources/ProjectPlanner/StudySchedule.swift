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
    /// 默认不内置任何模板任务，所有计划由用户自行创建。
    static func templates(for mode: StudyMode, isSunday: Bool) -> [TaskTemplate] {
        []
    }
}
