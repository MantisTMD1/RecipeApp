import Foundation

/// Minimal client for TheMealDB (https://www.themealdb.com/api.php).
struct MealDBClient {
    static let shared = MealDBClient()

    /// "1" is the free development key. Replace it with a supporter key before publishing.
    private let apiKey = "1"
    private let session: URLSession = .shared

    private var baseURL: URL {
        URL(string: "https://www.themealdb.com/api/json/v1/\(apiKey)/")!
    }

    func categories() async throws -> [MealCategory] {
        struct Response: Decodable { let categories: [MealCategory]? }
        let response: Response = try await get("categories.php")
        return response.categories ?? []
    }

    func meals(inCategory category: String) async throws -> [MealSummary] {
        struct Response: Decodable { let meals: [MealSummary]? }
        let response: Response = try await get("filter.php", query: ["c": category])
        return response.meals ?? []
    }

    /// Every ingredient TheMealDB knows about (about 1,000).
    func allIngredients() async throws -> [IngredientInfo] {
        struct Response: Decodable { let meals: [IngredientInfo]? }
        let response: Response = try await get("list.php", query: ["i": "list"])
        return response.meals ?? []
    }

    /// Meals that use the given ingredient. The free key only supports one ingredient per request.
    func meals(withIngredient ingredient: String) async throws -> [MealSummary] {
        struct Response: Decodable { let meals: [MealSummary]? }
        let response: Response = try await get("filter.php", query: ["i": ingredient])
        return response.meals ?? []
    }

    func search(_ term: String) async throws -> [Meal] {
        struct Response: Decodable { let meals: [Meal]? }
        let response: Response = try await get("search.php", query: ["s": term])
        return response.meals ?? []
    }

    func meal(id: String) async throws -> Meal? {
        struct Response: Decodable { let meals: [Meal]? }
        let response: Response = try await get("lookup.php", query: ["i": id])
        return response.meals?.first
    }

    func randomMeal() async throws -> Meal? {
        struct Response: Decodable { let meals: [Meal]? }
        let response: Response = try await get("random.php")
        return response.meals?.first
    }

    private func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        let (data, response) = try await session.data(from: components.url!)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
