import BookMatchCore
import BookMatchAPI
import BookMatchStrategy
import CoreFoundation
import UIKit

/// 도서 매칭 및 추천 기능의 핵심 모듈입니다.
/// 사용자의 요청을 처리하고, 도서 검색, 매칭, 추천 기능을 조율합니다.
public final class BookMatchModule: BookMatchable {
    private let apiClient: APIClientProtocol
    private let titleStrategy: SimilarityCalculatable
    private let authorStrategy: SimilarityCalculatable
    private let configuration: BookMatchConfiguration
    private let imageStrategy: ImageSimilarityCalculatable
    
    public init(
        apiClient: APIClientProtocol,
        titleStrategy: SimilarityCalculatable = LevenshteinStrategyWithNoParenthesis(),
        authorStrategy: SimilarityCalculatable = LevenshteinStrategy(),
        imageStrategy: ImageSimilarityCalculatable = BookImageSimilarityCalculator(),
        configuration: BookMatchConfiguration = .default
    ) {
        self.apiClient = apiClient
        self.titleStrategy = titleStrategy
        self.authorStrategy = authorStrategy
        self.imageStrategy = imageStrategy
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// `보유 도서 목록`을 기반으로 새로운 도서를 `추천`합니다.
    ///
    /// - Parameters:
    ///   - ownedBooks: 사용자가 보유한 도서 목록
    /// - Returns: 추천된 도서 목록
    public func recommendBooks(from ownedBooks: [OwnedBook]) async -> [BookItem] {
        do {
            let startTime = Date().timeIntervalSince1970
            let result = try await apiClient.getBookRecommendation(ownedBooks: ownedBooks)
            
            var validNewBooks = [BookItem]()
            var previousBooks = result.books
            
            for book in result.books {
                var retryCount = 0
                var candidates = [(BookItem, Double)]()
                
                while retryCount <= configuration.maxRetries {
                    if retryCount == configuration.maxRetries {
                        candidates.sort(by: { $0.1 > $1.1 })
                        if let bestCandidate = candidates.first {
                            validNewBooks.append(bestCandidate.0)
                        }
                        break
                    }
                    
                    let (isMatching, matchedBook, similarity) = try await convertToRealBook(book)
                    previousBooks.append(book)
                    
                    if isMatching, let matchedBook {
                        validNewBooks.append(matchedBook)
                        break
                    } else if !isMatching, let matchedBook {
                        candidates.append((matchedBook, similarity))
                        retryCount += 1
                    }
                }
            }
            print("elapsedTime:\(Date().timeIntervalSince1970-startTime)")
            return Array(Set(validNewBooks))
        } catch {
            print("error in recommendBooksFromOwnedBooks")
            return []
        }
    }
    
    /// 사용자의 `질문`과 보유 도서를 기반으로 도서를 `추천`합니다.
    ///
    /// - Parameters:
    ///   - input: 사용자의 질문과 보유 도서 정보를 포함한 입력 데이터
    /// - Returns: 추천된 도서 목록과 설명을 포함한 출력 데이터
    /// - Throws: BookMatchError.questionShort (질문이 4글자 미만인 경우)
    public func recommendBooks(for input: BookMatchModuleInput) async -> BookMatchModuleOutput {
        do {
            let startTime = Date().timeIntervalSince1970
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
                
                while retryCount <= configuration.maxRetries {
                    if retryCount == configuration.maxRetries {
                        candidates.sort(by: { $0.1 > $1.1 })
                        if let bestCandidate = candidates.first {
                            validNewBooks.append(bestCandidate.0)
                        }
                        break
                    }
                    
                    let (isMatching, matchedBook, similarity) = try await convertToRealBook(currentBook)
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
            }
            
            let ownedRaws = recommendation.ownedBooks.map { RawBook(title: $0.title, author: $0.author) }
            let validNewRaws = validNewBooks.map { RawBook(title: $0.title, author: $0.author) }
            
            let description = try await apiClient.getDescription(
                question: input.question,
                books: ownedRaws + validNewRaws
            )
            
            print("elapsedTime:\(Date().timeIntervalSince1970-startTime)")
            
            return BookMatchModuleOutput(
                ownedISBNs: input.ownedBooks.map { $0.id },
                newBooks: Array(Set(validNewBooks)),
                description: description
            )
        } catch {
            let description: String
            
            if let bookMatchError = error as? BookMatchError {
                description = bookMatchError.description
            } else {
                description = error.localizedDescription
            }
            
            return BookMatchModuleOutput(
                ownedISBNs: [],
                newBooks: [],
                description: description
            )
        }
    }
    
    /// `OCR로 인식된 텍스트 데이터와 이미지`를 기반으로 실제 도서를 `매칭`합니다.
    ///
    /// - Parameters:
    ///   - rawData: OCR로 인식된 텍스트 데이터 배열
    ///   - image: 도서 표지 이미지
    /// - Returns: 매칭된 도서 정보 또는 nil
    public func matchBook(_ rawData: [[String]], image: UIImage) async -> BookItem? {
        do {
            let textData = rawData.flatMap{$0}
            
            let searchResults = try await searchOverallBooks(from: textData)
            
            // 검색 결과가 있는 경우에만 유사도 계산 수행
            guard !searchResults.isEmpty else {
                throw BookMatchError.noMatchFound
            }
            
            var similarityResults = [(BookItem, Double)]()
            
            for book in searchResults {
                let similarity = await imageStrategy.calculateImageSimilarity(
                    image1: image,
                    imageURL2: book.image
                )
                
                similarityResults.append((book, similarity))
            }
            
            let sortedResults = similarityResults.sorted { $0.1 > $1.1 }
            
            return sortedResults[0].0
        } catch {
            print("error in procesBookMatch")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    /// RawBook을 실제 BookItem으로 변환합니다.
    /// - Note:``recommendBooks(for:)``, ``recommendBooks(from:)`` 메서드에 사용됩니다.
    ///
    /// - Parameters:
    ///   - input: 변환할 기본 도서 정보
    /// - Returns: 매칭 결과, 찾은 도서 정보, 유사도 점수를 포함한 튜플
    /// - Throws: BookMatchError
    private func convertToRealBook(_ input: RawBook) async throws -> (isMatching: Bool, book: BookItem?, similarity: Double) {
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
        let isMatching = bestMatch.1[0] >= configuration.titleSimilarityThreshold && bestMatch.1[1] >= configuration.authorSimilarityThreshold

        
        return (
            isMatching: isMatching,
            book: bestMatch.0,
            similarity: totalSimilarity
        )
    }
    
    /// `제목 & 저자`로 도서를 검색합니다.
    /// - Note: ``convertToRealBook()`` 메서드에 사용됩니다.
    ///
    /// - Parameters:
    ///   - sourceBook: 검색할 도서의 기본 정보
    /// - Returns: 검색된 도서 목록
    /// - Throws: BookMatchError
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
    
    /// `OCR로 검출된 텍스트 배열`로 도서를 검색합니다.
    /// - Note:``matchBook(_:, image:)`` 메서드에 사용됩니다.
    ///
    /// - Parameters:
    ///   - sourceBook: 검색할 도서의 기본 정보
    /// - Returns: 검색된 도서 목록
    /// - Throws: BookMatchError
    private func searchOverallBooks(from textData: [String]) async throws -> [BookItem] {
        var searchResults = [BookItem]()
        var previousResults = [BookItem]()
        var currentIndex = 0
        var currentQuery = ""
        
        while currentIndex < textData.count {
            if currentQuery.isEmpty {
                currentQuery = textData[currentIndex]
            } else {
                currentQuery = [currentQuery, textData[currentIndex]].joined(separator: " ")
            }
            
            try await Task.sleep(nanoseconds: 500_000_000) // Rate limit 방지
            let results = try await apiClient.searchBooks(query: currentQuery, limit: 10)
            
            // 이전 검색 결과 저장
            if !results.isEmpty {
                previousResults = results
            }
            
            // 검색 결과가 3개 이하면 최적의 쿼리로 판단하고 중단
            if results.count <= 3 {
                searchResults = previousResults // 이전 검색 결과 사용
                break
            }
            
            // 마지막 단어 그룹까지 도달했는데도 3개 이하가 안 된 경우
            if currentIndex == textData.count - 1 {
                searchResults = results.isEmpty ? previousResults : results
                break
            }
            
            currentIndex += 1
        }
        
        return searchResults
    }
    
    private func weightedTotalScore(_ similarities: [Double]) -> Double {
        let weights = [0.8, 0.2] // 제목 가중치 0.8, 저자 가중치 0.2
        return zip(similarities, weights)
            .map { $0.0 * $0.1 }
            .reduce(0, +)
    }
}
