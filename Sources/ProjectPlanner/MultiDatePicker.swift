import SwiftUI

/// 月历式多日期选择器：点击日期切换选中，可切换月份。
/// `dates` 中的日期以当日 startOfDay 归一化。
struct MultiDatePicker: View {
    @Binding var dates: Set<Date>
    @Binding var monthAnchor: Date

    private let calendar: Calendar = .current
    private let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    init(dates: Binding<Set<Date>>, monthAnchor: Binding<Date>) {
        _dates = dates
        _monthAnchor = monthAnchor
    }

    var body: some View {
        VStack(spacing: 10) {
            header

            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                ForEach(monthCells.chunked(into: 7), id: \.self) { week in
                    GridRow {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                            if let date {
                                dayButton(date)
                            } else {
                                Color.clear.frame(height: 32)
                            }
                        }
                    }
                }
            }

            HStack {
                Text("已选 \(dates.count) 天")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("清除") { dates.removeAll() }
                    .font(.caption)
                    .disabled(dates.isEmpty)
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                monthAnchor = calendar.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor
            } label: {
                Label("上个月", systemImage: "chevron.left")
            }
            .help("上个月")

            Spacer()

            Text(monthTitle)
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button {
                monthAnchor = calendar.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor
            } label: {
                Label("下个月", systemImage: "chevron.right")
            }
            .help("下个月")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    private func dayButton(_ date: Date) -> some View {
        let day = calendar.component(.day, from: date)
        let isSelected = dates.contains(calendar.startOfDay(for: date))
        let isToday = calendar.isDateInToday(date)

        return Button {
            let key = calendar.startOfDay(for: date)
            if isSelected {
                dates.remove(key)
            } else {
                dates.insert(key)
            }
        } label: {
            Text("\(day)")
                .font(.subheadline)
                .frame(height: 32)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .foregroundStyle(
                    isSelected ? Color.white :
                    isToday ? Color.accentColor : Color.primary
                )
        }
        .buttonStyle(.plain)
        .help(date.formatted(date: .abbreviated, time: .omitted))
    }

    private var monthTitle: String {
        let components = calendar.dateComponents([.year, .month], from: monthAnchor)
        return "\(components.year ?? 0) 年 \(components.month ?? 0) 月"
    }

    /// 当月日历网格：前置和尾部用 nil 补齐为整周。
    private var monthCells: [Date?] {
        guard let firstOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: monthAnchor)
        ) else { return [] }

        let leadingEmpty = calendar.component(.weekday, from: firstOfMonth) - 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 0

        var cells: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for day in 1...daysInMonth {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth))
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
