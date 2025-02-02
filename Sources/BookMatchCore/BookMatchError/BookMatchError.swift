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
            return "검색하신 조건에 맞는 책을 찾지 못했습니다"
        case .networkError:
            return "네트워크 연결이 원활하지 않습니다\n잠시 후 다시 시도해주세요"
        case .invalidResponse:
            return "일시적인 오류가 발생했습니다\n잠시 후 다시 시도해주세요"
        case .rateLimitExceeded:
            return "잠시 요청이 많아 서비스 이용이 어렵습니다\n잠시 후 다시 시도해주세요"
        }
    }
}
