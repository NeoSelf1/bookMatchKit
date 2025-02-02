public struct BookItem: Codable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let link: String
    public let image: String
    public let author: String
    public let discount: String?
    public let publisher: String
    public let isbn: String
    public let description: String
    public let pubdate: String?
    
    public init(
        id: String,
        title: String,
        link: String,
        image: String,
        author: String,
        discount: String? = nil,
        publisher: String,
        isbn: String,
        description: String,
        pubdate: String? = nil
    ) {
        self.id = id
        self.title = title
        self.link = link
        self.image = image
        self.author = author
        self.discount = discount
        self.publisher = publisher
        self.isbn = isbn
        self.description = description
        self.pubdate = pubdate
    }
}

public struct RawBook: Codable, Hashable {
    public let title: String
    public let author: String
    
    public init(title: String, author: String) {
        self.title = title
        self.author = author
    }
}

public struct OwnedBook: Codable, Identifiable, Hashable {
    public let id: String /// ISBN
    public let title: String
    public let author: String
}
