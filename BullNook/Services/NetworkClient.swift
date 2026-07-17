import Foundation

enum NetworkError: Error {
    case invalidResponse
    case httpError(Int)
    case decodingFailure
    case missingData
    case apiError(statusCode: Int, message: String)

    var localizedDescription: String {
        switch self {
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP error \(code)"
        case .decodingFailure:
            return "Failed to decode response"
        case .missingData:
            return "Missing data"
        case .apiError(let code, let message):
            return "API error \(code): \(message)"
        }
    }
}

actor NetworkClient {
    static let shared = NetworkClient()

    private var lastRequestTime: Date = .distantPast
    private let minInterval: TimeInterval = 0.3

    func fetch(_ url: URL, headers: [String: String] = [:], retries: Int = 3, delay: TimeInterval = 1.0) async throws -> Data {
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return try await fetch(request, retries: retries, delay: delay)
    }

    func fetch(_ request: URLRequest, retries: Int = 3, delay: TimeInterval = 1.0) async throws -> Data {
        var mutableRequest = request
        // URLRequest 默认超时 60s，未显式设置时统一改为 15s，避免数据源异常时长时间挂起
        if mutableRequest.timeoutInterval == 60 {
            mutableRequest.timeoutInterval = 15
        }

        var attempt = 0
        var lastError: Error?

        while attempt < retries {
            await throttle()
            do {
                let (data, response) = try await URLSession.shared.data(for: mutableRequest)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                guard (200..<300).contains(httpResponse.statusCode) else {
                    throw NetworkError.httpError(httpResponse.statusCode)
                }
                return data
            } catch {
                lastError = error
                attempt += 1
                if attempt < retries {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw lastError ?? NetworkError.missingData
    }

    func fetchString(_ url: URL, headers: [String: String] = [:], retries: Int = 3, delay: TimeInterval = 1.0) async throws -> String {
        let data = try await fetch(url, headers: headers, retries: retries, delay: delay)
        // Sina APIs return GBK/GB2312; UTF-8 decoding keeps ASCII digits/commas intact,
        // so numeric parsing still works. Try UTF-8 first, then fall back to GB18030.
        if let string = String(data: data, encoding: .utf8) {
            return string
        }
        let gbEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        guard let string = String(data: data, encoding: String.Encoding(rawValue: gbEncoding)) else {
            throw NetworkError.decodingFailure
        }
        return string
    }

    func fetchString(_ request: URLRequest, retries: Int = 3, delay: TimeInterval = 1.0) async throws -> String {
        let data = try await fetch(request, retries: retries, delay: delay)
        if let string = String(data: data, encoding: .utf8) {
            return string
        }
        let gbEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        guard let string = String(data: data, encoding: String.Encoding(rawValue: gbEncoding)) else {
            throw NetworkError.decodingFailure
        }
        return string
    }

    private func throttle() async {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRequestTime)
        if elapsed < minInterval {
            try? await Task.sleep(nanoseconds: UInt64((minInterval - elapsed) * 1_000_000_000))
        }
        lastRequestTime = Date()
    }
}
