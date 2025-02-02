public enum BookMatchError: Error {
    case questionShort
    case noMatchFound
    case networkError(String)
    case invalidResponse
    case rateLimitExceeded
    
    public var description: String {
        switch self {
        case .questionShort:
            return "질문은 최소 5글자 이상으로 해주세요"
        case .noMatchFound:
            return "No matching book found"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response received"
        case .rateLimitExceeded:
            return "API rate limit exceeded"
        }
    }
}
