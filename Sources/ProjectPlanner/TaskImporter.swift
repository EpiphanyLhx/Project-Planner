import Foundation

struct ImportedTaskDraft: Equatable {
    let module: String
    let title: String
    let minutes: Int
}

enum TaskImportError: LocalizedError {
    case emptyFile
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .emptyFile: "文件中没有可导入的任务。"
        case .invalidJSON: "JSON 格式不正确。请使用包含 module、title（或 task）和 minutes 的对象数组。"
        }
    }
}

enum TaskImporter {
    static func parse(data: Data, fileExtension: String) throws -> [ImportedTaskDraft] {
        if fileExtension.lowercased() == "json" {
            return try parseJSON(data)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw TaskImportError.emptyFile
        }
        return try parseText(text)
    }

    static func parseText(_ text: String) throws -> [ImportedTaskDraft] {
        var module = "导入任务"
        var tasks: [ImportedTaskDraft] = []

        for rawLine in text.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("#") {
                module = String(line.drop(while: { $0 == "#" }))
                    .trimmingCharacters(in: .whitespaces)
                if module.isEmpty { module = "导入任务" }
                continue
            }

            for prefix in ["- [ ] ", "- [x] ", "- [X] ", "- ", "* "] where line.hasPrefix(prefix) {
                line.removeFirst(prefix.count)
                break
            }

            let parts = line.split(separator: "|", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            let title = parts[0]
            guard !title.isEmpty else { continue }
            let minutes = parts.count == 2 ? Int(parts[1]) ?? 0 : 0
            tasks.append(.init(module: module, title: title, minutes: max(0, minutes)))
        }

        guard !tasks.isEmpty else { throw TaskImportError.emptyFile }
        return tasks
    }

    private static func parseJSON(_ data: Data) throws -> [ImportedTaskDraft] {
        struct Payload: Decodable {
            let module: String?
            let title: String?
            let task: String?
            let minutes: Int?
        }

        let payloads: [Payload]
        do {
            payloads = try JSONDecoder().decode([Payload].self, from: data)
        } catch {
            throw TaskImportError.invalidJSON
        }

        let tasks = payloads.compactMap { payload -> ImportedTaskDraft? in
            guard let title = payload.title ?? payload.task, !title.isEmpty else { return nil }
            let module = payload.module.flatMap { $0.isEmpty ? nil : $0 } ?? "导入任务"
            return .init(
                module: module,
                title: title,
                minutes: max(0, payload.minutes ?? 0)
            )
        }
        guard !tasks.isEmpty else { throw TaskImportError.emptyFile }
        return tasks
    }
}
