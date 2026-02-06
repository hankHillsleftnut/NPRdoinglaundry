import Foundation

enum OpenAIError: Error {
    case networkError
    case parseError
    case apiError(String)
    case invalidKey
}

class OpenAIService {
    private let apiKey: String
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func validateAPIKey(completion: @escaping (Result<Bool, OpenAIError>) -> Void) {
        // Create a minimal request to test the API key
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "user", "content": "Hello, can you confirm this is a valid API key test?"]
            ],
            "max_tokens": 10
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.invalidKey))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Check for network errors
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(.failure(.networkError))
                return
            }
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.apiError("Invalid response")))
                return
            }
            
            switch httpResponse.statusCode {
            case 200:
                // Successful response
                completion(.success(true))
            case 401:
                // Unauthorized - likely an invalid API key
                completion(.failure(.invalidKey))
            case 429:
                // Rate limit exceeded
                completion(.failure(.apiError("Rate limit exceeded")))
            case 500...599:
                // Server errors
                completion(.failure(.apiError("Server error: \(httpResponse.statusCode)")))
            default:
                // Other unexpected status codes
                completion(.failure(.apiError("Unexpected status code: \(httpResponse.statusCode)")))
            }
        }.resume()
    }
    
    func generateTranscript(text: String, goals: [String], completion: @escaping (Result<String, OpenAIError>) -> Void) {
        // Validate API key first
        validateAPIKey { [weak self] keyValidation in
            switch keyValidation {
            case .success:
                // Proceed with transcript generation if key is valid
                self?.performTranscriptGeneration(text: text, goals: goals, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func performTranscriptGeneration(text: String, goals: [String], completion: @escaping (Result<String, OpenAIError>) -> Void) {
        // Construct system prompt
        let systemPrompt = """
        You are a thoughtful, articulate, and motivational life coach and narrative analyst. Your job is to analyze a user's weekly goals and digital writing—such as personal notes, reflections, and to-dos—to uncover meaningful patterns, progress, emotional tone, and key actions. You then generate a weekly life briefing that is personalized, emotionally resonant, and encouraging. Your voice is grounded, clear, empathetic, and motivating. Avoid fluff and over-optimism; instead, aim for clarity, insight, and gentle accountability. Structure your output with an executive summary, followed by a narrative reflection that weaves in achievements, challenges, and forward momentum.

        Text: \(text)
        Goals: \(goals.joined(separator: ", "))
        """
        
        // Prepare request
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Generate the weekly life briefing transcript"]
            ],
            "max_tokens": 500
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.parseError))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Check for network errors
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(.failure(.networkError))
                return
            }
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.apiError("Invalid response")))
                return
            }
            
            // Check response status
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.apiError("HTTP Error: \(httpResponse.statusCode)")))
                return
            }
            
            // Parse JSON response
            guard let data = data else {
                completion(.failure(.parseError))
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    completion(.failure(.parseError))
                    return
                }
                
                completion(.success(content))
            } catch {
                completion(.failure(.parseError))
            }
        }.resume()
    }
}
