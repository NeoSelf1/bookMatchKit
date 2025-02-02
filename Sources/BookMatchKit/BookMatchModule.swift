import BookMatchCore
import BookMatchAPI
import BookMatchStrategy

public final class BookMatchModule: BookMatchable {
    private let apiClient: APIClientProtocol
    private let titleStrategy: SimilarityCalculatable
    private let authorStrategy: SimilarityCalculatable
    private let configuration: BookMatchConfiguration
    
    public init(
        apiClient: APIClientProtocol,
        titleStrategy: SimilarityCalculatable = LevenshteinStrategyWithNoParenthesis(),
        authorStrategy: SimilarityCalculatable = LevenshteinStrategy(),
        configuration: BookMatchConfiguration = .default
    ) {
        self.apiClient = apiClient
        self.titleStrategy = titleStrategy
        self.authorStrategy = authorStrategy
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    public func processBookRecommendation(_ input: BookMatchModuleInput) async throws -> BookMatchModuleOutput {
        guard input.question.count >= 4 else {
            throw BookMatchError.questionShort
        }
        
        let recommendation = try await apiClient.getBookRecommendation(
            question: input.question,
            ownedBooks: input.ownedBooks
        )
        
        var validNewBooks = [BookItem]()
        var previousBooks = recommendation.newBooks
        
        for book in recommendation.newBooks {
            var retryCount = 0
            var currentBook = book
            var candidates = [(BookItem, Double)]()
            
            do {
                while retryCount <= configuration.maxRetries {
                    if retryCount == configuration.maxRetries {
                        candidates.sort(by: { $0.1 > $1.1 })
                        if let bestCandidate = candidates.first {
                            validNewBooks.append(bestCandidate.0)
                        }
                        
                        break
                    }
                    
                    let (isMatching, matchedBook, similarity) = try await processBookMatch(currentBook)
                    previousBooks.append(currentBook)
                    
                    if isMatching, let matchedBook {
                        validNewBooks.append(matchedBook)
                        
                        break
                    } else if !isMatching, let matchedBook {
                        candidates.append((matchedBook, similarity))
                        
                        currentBook = try await apiClient.getAdditionalBook(
                            question: input.question,
                            previousBooks: previousBooks
                        )
                        
                        retryCount += 1
                    }
                }
            } catch {
                print("Error during book matching: \(error)")
                continue
            }
        }
        
        let ownedRaws = recommendation.ownedBooks.map { RawBook(title: $0.title, author: $0.author) }
        let validNewRaws = validNewBooks.map { RawBook(title: $0.title, author: $0.author) }
        
        let description = try await apiClient.getDescription(
            question: input.question,
            books: ownedRaws + validNewRaws
        )
        
        return BookMatchModuleOutput(
            ownedISBNs: input.ownedBooks.map { $0.id },
            newBooks: Array(Set(validNewBooks)),
            description: description
        )
    }
    
    public func processBookMatch(_ input: RawBook) async throws -> (isMatching: Bool, book: BookItem?, similarity: Double) {
        let searchResults = try await searchOverallBooks(from: input)
        
        guard !searchResults.isEmpty else {
            return (isMatching: false, book: nil, similarity: 0.0)
        }
        
        let results = searchResults.map { book -> (BookItem, [Double]) in
            let similarities = [
                titleStrategy.calculateSimilarity(book.title, input.title),
                authorStrategy.calculateSimilarity(book.author, input.author)
            ]
            
            return (book, similarities)
        }
        
        let sortedResults = results.sorted {
            weightedTotalScore($0.1) > weightedTotalScore($1.1)
        }
        
        guard let bestMatch = sortedResults.first else {
            return (isMatching: false, book: nil, similarity: 0.0)
        }
        
        let totalSimilarity = weightedTotalScore(bestMatch.1)
        let isMatching = bestMatch.1[0] >= configuration.similarityThreshold && bestMatch.1[1] > 0.4
        
        return (
            isMatching: isMatching,
            book: bestMatch.0,
            similarity: totalSimilarity
        )
    }
    
    // MARK: - Private Methods
    
    private func searchOverallBooks(from sourceBook: RawBook) async throws -> [BookItem] {
        // MARK: async let 사용 시 self를 통한 apiClient 접근이 여러 동시 태스크에서 데이터 무결성을 보장하지 않을 수 있음
        try await Task.sleep(nanoseconds: 500_000_000) // 속도 제한 초과 에러 방지
        let titleResults = try await apiClient.searchBooks(query: sourceBook.title, limit: 10)
        let authorResults = try await apiClient.searchBooks(query: sourceBook.author, limit: 10)
        
        var searchedResults = [BookItem]()
        
        searchedResults.append(contentsOf: titleResults)
        searchedResults.append(contentsOf: authorResults)
        
        let subTitleDivider = [":", "|", "-"]
        
        /// 제목 내부에 부제 이전에 오는 특수문자 존재할 경우
        if searchedResults.isEmpty,
           !subTitleDivider.filter({ sourceBook.title.contains($0) }).isEmpty {
            if let divider = subTitleDivider.first(where: { sourceBook.title.contains($0) }),
               let title = sourceBook.title.split(separator: divider).first {
                searchedResults = try await apiClient.searchBooks(query:String(title), limit:10)
            }
        }
        
        return searchedResults
    }
    
    private func weightedTotalScore(_ similarities: [Double]) -> Double {
        let weights = [0.8, 0.2] // 제목 가중치 0.8, 저자 가중치 0.2
        return zip(similarities, weights)
            .map { $0.0 * $0.1 }
            .reduce(0, +)
    }
}
