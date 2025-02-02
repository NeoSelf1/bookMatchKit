public enum BookMatchError: Error {
    case invalidInput
    case noMatchFound
    case networkError(String)
    case invalidResponse
    case rateLimitExceeded
    case unauthorized
    
    public var description: String {
        switch self {
        case .invalidInput:
            return "Invalid input provided"
        case .noMatchFound:
            return "No matching book found"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response received"
        case .rateLimitExceeded:
            return "API rate limit exceeded"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}
