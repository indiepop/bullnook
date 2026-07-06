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

    func fetch(_ url: URL, retries: Int = 3, delay: TimeInterval = 1.0) async throws -> Data {
        var attempt = 0
        var lastError: Error?

        while attempt < retries {
            await throttle()
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
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

    func fetchString(_ url: URL, retries: Int = 3, delay: TimeInterval = 1.0) async throws -> String {
        let data = try await fetch(url, retries: retries, delay: delay)
        guard let string = String(data: data, encoding: .utf8) else {
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
