import SwiftUI

struct StudySidebar: View {
    @AppStorage("exam.year") private var examYear = 2027

    let now: Date
    let mode: StudyMode
    let completion: Double

    private var daysRemaining: Int {
        ExamCountdown.daysRemaining(from: now, examYear: examYear)
    }

    private var selectableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: now)
        return Array(currentYear...(currentYear + 10))
    }

    private var progressTint: Color {
        if completion >= 1 { return .green }
        return mode == .full ? .accentColor : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("研途")
                    .font(.title2.weight(.semibold))
                Spacer()
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("考研倒计时", systemImage: "calendar")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        ForEach(selectableYears, id: \.self) { year in
                            Button {
                                examYear = year
                            } label: {
                                if year == examYear {
                                    Label {
                                        Text(verbatim: "\(year) 年")
                                    } icon: {
                                        Image(systemName: "checkmark")
                                    }
                                } else {
                                    Text(verbatim: "\(year) 年")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(verbatim: "\(examYear) 年")
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("选择考研年份")
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(daysRemaining, format: .number)
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .contentTransition(.numericText(value: Double(daysRemaining)))
                    Text("天")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .animation(.smooth(duration: 0.5), value: daysRemaining)

                Text(verbatim: "目标日期 · \(examYear) 年 12 月 19 日")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.06))
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Label(mode.shortTitle, systemImage: mode == .full ? "bolt.fill" : "leaf.fill")
                        .font(.headline)
                        .foregroundStyle(progressTint)
                    Spacer()
                    Text(completion, format: .percent.precision(.fractionLength(0)))
                        .font(.callout.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: completion))
                        .animation(.smooth(duration: 0.5), value: completion)
                }
                SmoothProgressBar(value: completion, tint: progressTint)
            }

            Spacer()

            Label("每日 4:00 自动开启新一天", systemImage: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }
}
