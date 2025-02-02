import BookMatchCore
import Foundation

public final class DefaultAPIClient: APIClientProtocol {
    private let configuration: APIConfiguration
    private let session: URLSession
    
    public init(
        configuration: APIConfiguration,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }
    
    public func searchBooks(query: String, limit: Int = 10) async throws -> [BookItem] {
        guard !query.isEmpty else { return [] }
        
        let queryString = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(configuration.naverBaseURL)?query=\(queryString)&display=\(limit)&start=1"
        
        guard let url = URL(string: urlString) else {
            throw BookMatchError.networkError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.setValue(configuration.naverClientId, forHTTPHeaderField: "X-Naver-Client-Id")
        request.setValue(configuration.naverClientSecret, forHTTPHeaderField: "X-Naver-Client-Secret")
        
        let (data, response) = try await session.data(for: request)
        
        let naverResponse = try JSONDecoder().decode(NaverBooksResponse.self, from: data)
        return naverResponse.items.map { $0.toBookItem() }
    }
    
    public func getBookRecommendation(
        question: String,
        ownedBooks: [OwnedBook]
    ) async throws -> GPTRecommendation {
        let messages = [
            ChatMessage(role: "system", content: Prompts.bookRecommendation),
            ChatMessage(
                role: "user",
                content: "질문: \(question)\n보유도서: \(ownedBooks.map{"\($0.title)-\($0.author)"})"
            )
        ]
        
        let maxRetries = 3
        var retryCount = 0
        
        while retryCount < maxRetries {
            do {
                let response = try await sendChatRequest(messages: messages, temperature: 0.01, maxTokens: 500)
                
                guard let jsonString = response.choices.first?.message.content,
                      let jsonData = jsonString.data(using: .utf8) else {
                    throw BookMatchError.invalidResponse
                }
                
                let result = try JSONDecoder().decode(GPTRecommendationDTO.self, from: jsonData)
                
                return result.toGPTRecommendation(ownedBooks)
            } catch {
                retryCount += 1
                print("Retry attempt in getBookRecommendation \(retryCount): \(error)")
                continue
            }
        }
        
        /// 3회 재시도하여도 sendChatRequest로부터 에러를 계속 반환받거나, GPT로부터 반환받은 결과가 형식에 맞지 않을 경우 invalidResponse를 반환합니다.
        throw BookMatchError.invalidResponse
    }
    
    public func getAdditionalBook(
        question: String,
        previousBooks: [RawBook]
    ) async throws -> RawBook {
        let messages = [
            ChatMessage(role: "system", content: Prompts.additionalBook),
            ChatMessage(
                role: "user",
                content: "질문: \(question)\n기존 도서 제목 배열: \(previousBooks.map{$0.title})"
            )
        ]
        
        let maxRetries = 3
        var retryCount = 0
        
        while retryCount < maxRetries {
            do {
                let response = try await sendChatRequest(messages: messages, temperature: 0.01, maxTokens: 100)
                
                guard let result = response.choices.first?.message.content,
                      result.map({String($0)}).contains("-") else {
                    throw BookMatchError.invalidResponse
                }
                
                let arr = result
                    .split(separator: "-")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines)}
                
                return RawBook(title: arr[0], author: arr[1])
            } catch {
                retryCount += 1
                print("Retry attempt in getAdditionalBook \(retryCount): \(error)")
                continue
            }
        }
        
        /// 3회 재시도하여도 sendChatRequest로부터 에러를 계속 반환받거나, GPT로부터 반환받은 결과가 형식에 맞지 않을 경우 invalidResponse를 반환합니다.
        throw BookMatchError.invalidResponse
    }
    
    public func getDescription(
        question: String,
        books: [RawBook]
    ) async throws -> String {
        let messages = [
            ChatMessage(role: "system", content: Prompts.description),
            ChatMessage(
                role: "user",
                content: "질문: \(question)\n해당 질문에 대해 선정된 도서 목록: \(books.map{"\($0.title)-\($0.author)"}.joined(separator: ","))"
            )
        ]
        
        let maxRetries = 3
        var retryCount = 0
        
        while retryCount < maxRetries {
            do {
                let response = try await sendChatRequest(model:"gpt-4o-mini", messages: messages, temperature: 1.0, maxTokens: 500)
                
                guard let result = response.choices.first?.message.content else {
                    throw BookMatchError.invalidResponse
                }
                
                return result
            } catch {
                retryCount += 1
                print("Retry attempt in getDescription \(retryCount): \(error)")
                continue
            }
        }
        
        /// 3회 재시도하여도 sendChatRequest로부터 에러를 계속 반환받거나, GPT로부터 반환받은 결과가 형식에 맞지 않을 경우 invalidResponse를 반환합니다.
        throw BookMatchError.invalidResponse
    }
    
    
    private func sendChatRequest(
        model: String = "gpt-4o",
        messages: [ChatMessage],
        temperature: Double,
        maxTokens: Int
    ) async throws -> ChatGPTResponse {
        guard let url = URL(string: configuration.openAIBaseURL) else {
            throw BookMatchError.networkError("Invalid URL")
        }
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature,
            "max_tokens": maxTokens
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(configuration.openAIApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        return try JSONDecoder().decode(ChatGPTResponse.self, from: data)
    }
}
