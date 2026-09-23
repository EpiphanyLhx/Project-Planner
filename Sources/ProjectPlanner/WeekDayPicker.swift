import Combine
import SwiftUI

struct WeekDayPicker: View {
    @Binding var selection: Date
    let today: Date
    @StateObject private var navigation = WeekDayPickerNavigationState()

    private var days: [Date] {
        let calendar = Calendar.current
        let todayStart = StudyDay.start(for: today, calendar: calendar)
        let pageStart = calendar.date(
            byAdding: .day,
            value: navigation.dayOffset,
            to: todayStart
        ) ?? todayStart
        return StudyDay.sevenDates(startingAt: pageStart)
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                scroll(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 44)
            .help("向前一天")

            HStack(spacing: 8) {
                ForEach(days, id: \.self) { date in
                    dayButton(date)
                        .transition(dayTransition)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()

            Button {
                navigation.direction = navigation.dayOffset > 0 ? -1 : 1
                withAnimation(.smooth(duration: 0.42)) {
                    selection = today
                    navigation.dayOffset = 0
                }
            } label: {
                Image(systemName: "calendar")
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 44)
            .help("回到今天")

            Button {
                scroll(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 44)
            .help("向后一天")
        }
        .frame(maxWidth: .infinity)
    }

    private func dayButton(_ date: Date) -> some View {
        let isSelected = StudyDay.key(for: date) == StudyDay.key(for: selection)
        let isToday = StudyDay.key(for: date) == StudyDay.key(for: today)
        let isHovered = navigation.hoveredDate.map {
            StudyDay.key(for: $0) == StudyDay.key(for: date)
        } ?? false

        return Button {
            withAnimation(.snappy(duration: 0.25)) {
                selection = date
            }
        } label: {
            VStack(spacing: 3) {
                Text(date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "zh_CN"))))
                    .font(.caption)
                Text(date.formatted(.dateTime.day()))
                    .font(.headline.monospacedDigit())
                Circle()
                    .fill(isToday ? Color.accentColor : .clear)
                    .frame(width: 4, height: 4)
            }
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.12)
                    : isHovered ? Color.primary.opacity(0.06) : .clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .shadow(
                color: isHovered ? Color.black.opacity(0.16) : .clear,
                radius: isHovered ? 5 : 0,
                y: isHovered ? 2 : 0
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                navigation.hoveredDate = hovering ? date : nil
            }
        }
        .accessibilityLabel(date.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN"))))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var dayTransition: AnyTransition {
        let insertionEdge: Edge = navigation.direction > 0 ? .trailing : .leading
        let removalEdge: Edge = navigation.direction > 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private func scroll(by offset: Int) {
        guard let newSelection = Calendar.current.date(
            byAdding: .day,
            value: offset,
            to: selection
        ) else { return }
        navigation.direction = offset
        withAnimation(.smooth(duration: 0.42)) {
            navigation.dayOffset += offset
            selection = newSelection
        }
    }
}

@MainActor
private final class WeekDayPickerNavigationState: ObservableObject {
    @Published var dayOffset = 0
    @Published var direction = 1
    @Published var hoveredDate: Date?
}
