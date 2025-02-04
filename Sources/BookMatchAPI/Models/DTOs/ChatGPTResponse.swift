import BookMatchCore

/// OpenAI API로부터 받은 응답을 디코딩하기 위한 구조체입니다.
struct ChatGPTResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}

/// GPT 모델의 응답을 `사용자 질문 기반 추천 도서` 데이터로 변환하는 DTO 구조체입니다.
public struct GPTRecommendationForQuestionDTO: Codable {
    public let recommendationOwned: [String]
    public let recommendationNew: [String]
    
    /// - Parameters:
    ///    - ownedBooks: 사용자가 보유한 도서 목록
    ///    - Returns: BookMatchCore에서 구현되었으며, APIClient 모듈에서 사용되는 ``GPTRecommendationForQuestion`` 객체
    func toDomain(_ ownedBooks: [OwnedBook]) -> GPTRecommendationForQuestion {
        /// 기존 "도서명-저자명" 배열을 순회하며, 초기 전달받은 OwnedBook들 중 일치하는 데이터로 변환합니다.
        let ownedBooks = self.recommendationOwned.compactMap {
            let arr = $0.split(separator: "-").map { String($0) }
            return ownedBooks.first(where: { $0.title == arr[0] && $0.author == arr[1] })
        }
        
        let newRawBooks = self.recommendationNew.map {
            let arr = $0.split(separator: "-").map { String($0) }
            return RawBook(title: arr[0], author: arr[1])
        }
        
        return GPTRecommendationForQuestion(ownedBooks: ownedBooks, newBooks: newRawBooks)
    }
}

/// GPT 모델의 응답을 `사용자 보유도서 기반 추천 도서` 데이터로 변환하는 DTO 구조체입니다.
public struct GPTRecommendationFromOwnedBooksDTO: Codable {
    public let recommendations: [String]
    
    /// - Returns: BookMatchCore에서 구현되었으며, APIClient 모듈에서 사용되는 ``GPTRecommendationFromOwnedBooks`` 객체
    func toDomain() -> GPTRecommendationFromOwnedBooks {
        let recommendations = self.recommendations.map {
            let arr = $0.split(separator: "-").map { String($0) }
            return RawBook(title: arr[0], author: arr[1])
        }
        
        return GPTRecommendationFromOwnedBooks(books:recommendations)
    }
}
