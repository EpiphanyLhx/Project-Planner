import Foundation

struct AIImageAttachment: Identifiable {
    let id = UUID()
    let name: String
    let mimeType: String
    let data: Data

    var dataURL: String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }
}

struct AIServiceConfiguration: Equatable {
    var apiURL: String
    var apiKey: String
    var model: String

    static let `default` = AIServiceConfiguration(
        apiURL: "https://api.openai.com/v1/chat/completions",
        apiKey: "",
        model: "gpt-4o-mini"
    )

    static func load(from defaults: UserDefaults = .standard) -> AIServiceConfiguration {
        AIServiceConfiguration(
            apiURL: defaults.string(forKey: SettingsStore.apiURLKey) ?? Self.default.apiURL,
            apiKey: defaults.string(forKey: SettingsStore.apiKeyKey) ?? "",
            model: defaults.string(forKey: SettingsStore.modelKey) ?? Self.default.model
        )
    }

    static func resolvedEndpointURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host != nil else {
            return nil
        }

        var path = components.path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }

        if components.host?.lowercased() == "api.deepseek.com" && path == "/anthropic" {
            path = "/v1/chat/completions"
        } else if !path.lowercased().hasSuffix("/chat/completions") {
            path = path.isEmpty || path == "/"
                ? "/v1/chat/completions"
                : path + "/chat/completions"
        }

        components.path = path
        return components.url
    }
}

struct AIPlanItem: Codable, Identifiable, Equatable {
    let id = UUID()
    var dayOffset: Int
    var taskName: String
    var estimatedMinutes: Int
    var startTime: String?
    var endTime: String?

    enum CodingKeys: String, CodingKey {
        case dayOffset = "day_offset"
        case taskName = "task_name"
        case estimatedMinutes = "estimated_minutes"
        case startTime = "start_time"
        case endTime = "end_time"
    }

    var parsedStartTime: Date? { TaskTime.date(fromHHmm: startTime) }
    var parsedEndTime: Date? { TaskTime.date(fromHHmm: endTime) }

    var hasValidTimeSlot: Bool {
        if startTime == nil, endTime == nil { return true }
        guard let start = parsedStartTime, let end = parsedEndTime else { return false }
        return TaskTime.minuteOfDay(end) > TaskTime.minuteOfDay(start)
    }

    static func scheduledBefore(_ lhs: AIPlanItem, _ rhs: AIPlanItem) -> Bool {
        if lhs.dayOffset != rhs.dayOffset {
            return lhs.dayOffset < rhs.dayOffset
        }
        switch (lhs.parsedStartTime, rhs.parsedStartTime) {
        case let (left?, right?) where left != right:
            return TaskTime.minuteOfDay(left) < TaskTime.minuteOfDay(right)
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.taskName < rhs.taskName
        }
    }
}

enum AITaskServiceError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case requestTimedOut
    case httpStatus(Int, String)
    case invalidJSON
    case emptyPlan

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "请先在设置中填写 API Key。"
        case .invalidURL: "API URL 无效。"
        case .invalidResponse: "AI 服务返回了无法识别的响应。"
        case .requestTimedOut: "AI 请求超时（超过 120 秒）。请检查网络、API 地址和模型名称，或缩短任务描述后重试。"
        case let .httpStatus(status, message):
            if status == 404 {
                "AI 接口地址不存在（HTTP 404）。请在 AI 设置中填写 OpenAI 兼容地址，例如 https://api.deepseek.com。"
            } else {
                "AI 服务请求失败（HTTP \(status)）：\(message)"
            }
        case .invalidJSON: "AI 返回的内容不是符合约束的 JSON 任务数组。"
        case .emptyPlan: "AI 没有生成任何任务。"
        }
    }
}

@MainActor
final class AITaskService {
    private let session: URLSession
    private let defaults: UserDefaults

    init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.session = session
        self.defaults = defaults
    }

    func breakdown(
        description: String,
        expectedDays: Int,
        workloadPreference: String,
        images: [AIImageAttachment] = []
    ) async throws -> [AIPlanItem] {
        let configuration = AIServiceConfiguration.load(from: defaults)
        guard !configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AITaskServiceError.missingAPIKey
        }
        guard let url = AIServiceConfiguration.resolvedEndpointURL(from: configuration.apiURL) else {
            throw AITaskServiceError.invalidURL
        }

        let systemPrompt = "你是考研学习计划拆分器。用户可能附带教材目录、课程表或笔记图片；若有图片，请结合图片中的可见内容制定计划。你只能返回一个 JSON 数组，不能返回 Markdown、代码围栏、解释、前后缀或任何额外文本。数组每一项必须严格包含 day_offset（从 0 开始的整数）、task_name（字符串）、estimated_minutes（正整数）、start_time 和 end_time 五个字段。start_time 和 end_time 可以是 HH:mm 格式的推荐时间字符串，也可以同时为 null；结束时间必须晚于开始时间。day_offset 必须在 0 到 " + String(max(0, expectedDays - 1)) + " 之间。任务要可执行、颗粒度适中，并遵守用户给出的每日负荷偏好。只输出 JSON。"
        let userPrompt = "大任务：" + description + "\n期望完成天数：" + String(expectedDays) + "\n每日负荷偏好或备注：" + (workloadPreference.isEmpty ? "无" : workloadPreference)
        let requestBody = ChatCompletionRequest(
            model: configuration.model,
            temperature: 0.2,
            messages: [
                .init(role: "system", content: .text(systemPrompt)),
                .init(
                    role: "user",
                    content: images.isEmpty
                        ? .text(userPrompt)
                        : .parts(
                            [.text(userPrompt)] + images.map {
                                .imageURL(.init(url: $0.dataURL))
                            }
                        )
                )
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw AITaskServiceError.requestTimedOut
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AITaskServiceError.httpStatus(0, error.localizedDescription)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AITaskServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "未知错误"
            throw AITaskServiceError.httpStatus(httpResponse.statusCode, message)
        }

        let completion: ChatCompletionResponse
        do {
            completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw AITaskServiceError.invalidResponse
        }

        guard let content = completion.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else {
            throw AITaskServiceError.invalidResponse
        }

        let plan: [AIPlanItem]
        do {
            plan = try JSONDecoder().decode([AIPlanItem].self, from: contentData)
        } catch {
            throw AITaskServiceError.invalidJSON
        }
        guard !plan.isEmpty else { throw AITaskServiceError.emptyPlan }
        guard plan.allSatisfy({
            $0.dayOffset >= 0 && $0.dayOffset < expectedDays &&
            !$0.taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            $0.estimatedMinutes > 0 &&
            $0.hasValidTimeSlot
        }) else {
            throw AITaskServiceError.invalidJSON
        }
        return plan.sorted(by: AIPlanItem.scheduledBefore)
    }
}

private struct ChatCompletionRequest: Encodable {
    var model: String
    var temperature: Double
    var messages: [ChatRequestMessage]
}

private struct ChatRequestMessage: Encodable {
    var role: String
    var content: ChatRequestContent
}

private enum ChatRequestContent: Encodable {
    case text(String)
    case parts([ChatContentPart])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .text(value):
            try container.encode(value)
        case let .parts(parts):
            try container.encode(parts)
        }
    }
}

private struct ChatContentPart: Encodable {
    let type: String
    var text: String?
    var imageURL: ImageURL?

    struct ImageURL: Encodable {
        let url: String
    }

    enum CodingKeys: String, CodingKey {
        case type, text
        case imageURL = "image_url"
    }

    static func text(_ value: String) -> ChatContentPart {
        ChatContentPart(type: "text", text: value)
    }

    static func imageURL(_ value: ImageURL) -> ChatContentPart {
        ChatContentPart(type: "image_url", imageURL: value)
    }
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}
