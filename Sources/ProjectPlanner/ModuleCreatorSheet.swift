import Combine
import SwiftUI

struct ModuleCreatorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialDate: Date
    let onSave: (String, [Date]) -> Void

    @StateObject private var model: ModuleCreatorModel

    init(initialDate: Date, onSave: @escaping (String, [Date]) -> Void) {
        self.initialDate = initialDate
        self.onSave = onSave
        _model = StateObject(wrappedValue: ModuleCreatorModel(initialDate: initialDate))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("添加模块")
                .font(.title2.weight(.semibold))

            Form {
                TextField("模块名称", text: $model.title)

                Section("执行日期") {
                    MultiDatePicker(dates: $model.dates, monthAnchor: $model.monthAnchor)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("添加模块") {
                    onSave(model.trimmedTitle, model.sortedDates)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(model.trimmedTitle.isEmpty || model.dates.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}

@MainActor
private final class ModuleCreatorModel: ObservableObject {
    @Published var title = ""
    @Published var dates: Set<Date>
    @Published var monthAnchor: Date

    init(initialDate: Date) {
        let day = Calendar.current.startOfDay(for: initialDate)
        dates = [day]
        monthAnchor = day
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var sortedDates: [Date] {
        dates.sorted()
    }
}
