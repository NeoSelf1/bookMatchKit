public protocol BookMatchable {
    func processBookRecommendation(_ input: BookMatchModuleInput) async throws -> BookMatchModuleOutput
    func processBookMatch(_ input: RawBook) async throws -> (isMatching: Bool, book: BookItem?, similarity: Double)
}
