import BookMatchCore

struct ChatGPTResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}

/// GPT로부터 받은 Raw 데이터입니다.
public struct GPTRecommendationDTO: Codable {
    public let recommendationOwned: [String]
    public let recommendationNew: [String]
    
    func toGPTRecommendation(_ ownedBooks: [OwnedBook]) -> GPTRecommendation {
        /// 기존 "도서명-저자명" 배열을 순회하며, 초기 전달받은 OwnedBook들 중 일치하는 데이터로 변환합니다.
        let ownedBooks = self.recommendationOwned.compactMap {
            let arr = $0.split(separator: "-").map { String($0) }
            return ownedBooks.first(where: { $0.title == arr[0] && $0.author == arr[1] })
        }
        
        let newRawBooks = self.recommendationNew.map {
            let arr = $0.split(separator: "-").map { String($0) }
            return RawBook(title: arr[0], author: arr[1])
        }
        
        return GPTRecommendation(ownedBooks: ownedBooks, newBooks: newRawBooks)
    }
}
