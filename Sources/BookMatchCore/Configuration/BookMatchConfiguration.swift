// 타입이 동시성 환경에서 안전하게 전달될 수 있음을 나타내는 프로토콜인 Sendable을 채택해야 해결이 가능합니다.
//  Static property 'default' is not concurrency-safe because non-'Sendable' type 'APIConfiguration' may have shared mutable state

public struct BookMatchConfiguration : Sendable {
    public let similarityThreshold: Double
    public let maxRetries: Int
    
    /// 예약어와 이름이 충돌하므로, 백틱을 통해 변수명임을 명시합니다.
    public static let `default` = BookMatchConfiguration(
        similarityThreshold: 0.8,
        maxRetries: 3
    )
    
    public init(
        similarityThreshold: Double = 0.8,
        maxRetries: Int = 3
    ) {
        self.similarityThreshold = similarityThreshold
        self.maxRetries = maxRetries
    }
}
