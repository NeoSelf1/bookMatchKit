import Foundation

public struct BookMatchConfiguration : Sendable{
    public let similarityThreshold: Double
    public let maxRetries: Int
    
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
