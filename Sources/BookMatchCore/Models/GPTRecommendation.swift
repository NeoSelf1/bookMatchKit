public struct GPTRecommendation: Codable {
    public let ownedBooks: [OwnedBook]
    public let newBooks: [RawBook]
    
    public init(ownedBooks: [OwnedBook], newBooks: [RawBook]) {
        self.ownedBooks = ownedBooks
        self.newBooks = newBooks
    }
}
