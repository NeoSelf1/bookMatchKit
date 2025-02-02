import XCTest
@testable import BookMatchKit
@testable import BookMatchCore
@testable import BookMatchAPI

final class BookMatchKitTests: XCTestCase {
    var sut: BookMatchModule!
    fileprivate var mockAPIClient: MockAPIClient!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        sut = BookMatchModule(
            apiClient: mockAPIClient,
            configuration: .init(
                titleSimilarityThreshold: 0.4,
                authorSimilarityThreshold: 0.8,
                maxRetries: 3
            )
        )
    }
    
    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        super.tearDown()
    }
    
    // MARK: - processBookRecommendation Tests
    
    func test_processBookRecommendation_WithValidInput_ReturnsExpectedOutput() async throws {
        // Given
        let input = BookMatchModuleInput(
            question: "프로그래밍 입문서 추천해주세요",
            ownedBooks: [
                OwnedBook(id: "1", title: "Swift 기초", author: "김철수")
            ]
        )
        
        let expectedGPTRecommendation = GPTRecommendation(
            ownedBooks: [
                OwnedBook(id:"1", title: "Swift 기초", author: "김철수")
            ],
            newBooks: [
                RawBook(title: "Python 입문", author: "이영희")
            ]
        )
        
        let expectedSearchResults = [
            BookItem(id: "2", title: "Python 입문", link:"asdf", image:"asdf", author: "이영희", publisher: "코딩출판사", isbn: "456", description: "파이썬 기초")
        ]
        
        mockAPIClient.mockGPTRecommendation = expectedGPTRecommendation
        mockAPIClient.mockSearchResults = expectedSearchResults
        mockAPIClient.mockDescription = "추천 도서 설명입니다."
        
        // When
        let result = try await sut.processBookRecommendation(input)
        
        // Then
        XCTAssertEqual(result.ownedISBNs, ["1"])
        XCTAssertEqual(result.newBooks.count, 1)
        XCTAssertEqual(result.newBooks.first?.title, "Python 입문")
        XCTAssertEqual(result.description, "추천 도서 설명입니다.")
    }

    func test_processBookRecommendation_WithNoMatches_RetriesAndUsesBestCandidate() async throws {
        
        let client = DefaultAPIClient(configuration: config)
        let module = BookMatchModule(apiClient:client)
        
        let input = BookMatchModuleInput(
            question: "프로그래밍 입문서 추천해주세요",
            ownedBooks: []
        )
        
        let result = try await module.processBookRecommendation(input)
        print(result)
        
//        XCTAssertEqual(result.newBooks.count, 1)
//        XCTAssertTrue(mockAPIClient.getAdditionalBookCallCount > 0)
    }
//
//    // MARK: - processBookMatch Tests
//    
//    func test_processBookMatch_WithHighSimilarity_ReturnsMatch() async throws {
//        // Given
//        let input = RawBook(title: "Python 입문", author: "이영희")
//        let searchResults = [
//            BookItem(id: "1", title: "Python 입문", author: "이영희", isbn: "123",
//                    description: nil, publisher: "출판사")
//        ]
//        mockAPIClient.mockSearchResults = searchResults
//        
//        // When
//        let result = try await sut.processBookMatch(input)
//        
//        // Then
//        XCTAssertTrue(result.isMatching)
//        XCTAssertEqual(result.book?.title, "Python 입문")
//    }
//    
//    func test_processBookMatch_WithLowSimilarity_ReturnsNoMatch() async throws {
//        // Given
//        let input = RawBook(title: "Python 입문", author: "이영희")
//        let searchResults = [
//            BookItem(id: "1", title: "Java 기초", author: "박지성", isbn: "123",
//                    description: nil, publisher: "출판사")
//        ]
//        mockAPIClient.mockSearchResults = searchResults
//        
//        // When
//        let result = try await sut.processBookMatch(input)
//        
//        // Then
//        XCTAssertFalse(result.isMatching)
//    }
//    
//    func test_processBookMatch_WithEmptySearchResults_ReturnsNoMatch() async throws {
//        // Given
//        let input = RawBook(title: "존재하지 않는 책", author: "없는 저자")
//        mockAPIClient.mockSearchResults = []
//        
//        // When
//        let result = try await sut.processBookMatch(input)
//        
//        // Then
//        XCTAssertFalse(result.isMatching)
//        XCTAssertNil(result.book)
//    }
}
    
// MARK: - Mock APIClient
    
private final class MockAPIClient: APIClientProtocol {
    var mockSearchResults: [BookItem] = []
    var mockGPTRecommendation: GPTRecommendation?
    var mockAdditionalBook: RawBook?
    var mockDescription: String = ""
    
    var getAdditionalBookCallCount = 0
    
    func searchBooks(query: String, limit: Int) async throws -> [BookItem] {
        return mockSearchResults
    }
    
    func getBookRecommendation(
        question: String,
        ownedBooks: [OwnedBook]
    ) async throws -> GPTRecommendation {
        guard let recommendation = mockGPTRecommendation else {
            throw BookMatchError.invalidResponse
        }
        return recommendation
    }
    
    func getAdditionalBook(
        question: String,
        previousBooks: [RawBook]
    ) async throws -> RawBook {
        getAdditionalBookCallCount += 1
        guard let book = mockAdditionalBook else {
            throw BookMatchError.invalidResponse
        }
        return book
    }
    
    func getDescription(
        question: String,
        books: [RawBook]
    ) async throws -> String {
        return mockDescription
    }
}
