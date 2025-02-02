public struct APIConfiguration {
    public let naverClientId: String
    public let naverClientSecret: String
    public let openAIApiKey: String
    public let naverBaseURL: String
    public let openAIBaseURL: String
    
    public init(
        naverClientId: String,
        naverClientSecret: String,
        openAIApiKey: String,
        naverBaseURL: String = "https://openapi.naver.com/v1/search/book.json",
        openAIBaseURL: String = "https://api.openai.com/v1/chat/completions"
    ) {
        self.naverClientId = naverClientId
        self.naverClientSecret = naverClientSecret
        self.openAIApiKey = openAIApiKey
        self.naverBaseURL = naverBaseURL
        self.openAIBaseURL = openAIBaseURL
    }
}
