public struct BookMatchModuleInput {
    public let question: String
    public let ownedBooks: [OwnedBook]
}

public struct BookMatchModuleOutput {
    public let ownedISBNs: [String] // isbn 코드 배열
    public let newBooks: [BookItem]
    public let description: String
    
    public init(
        ownedISBNs: [String],
        newBooks: [BookItem],
        description: String
    ) {
        self.ownedISBNs = ownedISBNs
        self.newBooks = newBooks
        self.description = description
    }
}
