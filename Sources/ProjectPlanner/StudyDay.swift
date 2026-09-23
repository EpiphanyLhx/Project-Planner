import Foundation

enum StudyDay {
    static func start(for date: Date, calendar: Calendar = .current) -> Date {
        let shifted = calendar.date(byAdding: .hour, value: -4, to: date) ?? date
        let midnight = calendar.startOfDay(for: shifted)
        return calendar.date(byAdding: .hour, value: 4, to: midnight) ?? midnight
    }

    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: start(for: date, calendar: calendar))
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        guard let midnight = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else {
            return nil
        }
        return calendar.date(byAdding: .hour, value: 4, to: midnight)
    }

    static func isSunday(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.component(.weekday, from: start(for: date, calendar: calendar)) == 1
    }

    static func weekDates(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let studyDate = start(for: date, calendar: calendar)
        let weekday = calendar.component(.weekday, from: studyDate)
        let daysAfterMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysAfterMonday, to: studyDate) ?? studyDate
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monday)
        }
    }

    static func sevenDates(startingAt date: Date, calendar: Calendar = .current) -> [Date] {
        let firstDate = start(for: date, calendar: calendar)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: firstDate)
        }
    }
}

enum ExamCountdown {
    static func examDate(for year: Int, calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: 12, day: 19)) ?? Date(timeIntervalSince1970: 0)
    }

    static func daysRemaining(from date: Date, examYear: Int, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: date)
        let target = calendar.startOfDay(for: examDate(for: examYear, calendar: calendar))
        return max(0, calendar.dateComponents([.day], from: today, to: target).day ?? 0)
    }
}
