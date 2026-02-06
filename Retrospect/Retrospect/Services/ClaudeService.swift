import Foundation
import UIKit

enum ClaudeError: Error {
    case networkError
    case parseError
    case apiError(String)
    case invalidKey
}

class ClaudeService {
    static let shared: ClaudeService = {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String else {
            fatalError("Anthropic API key not found in Info.plist")
        }
        return ClaudeService(apiKey: apiKey)
    }()

    private let apiKey: String
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func validateAPIKey(completion: @escaping (Result<Bool, ClaudeError>) -> Void) {
        print("🔑 Validating Claude API key...")

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 10,
            "messages": [
                ["role": "user", "content": "Hello"]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Failed to serialize request body: \(error)")
            completion(.failure(.invalidKey))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(.networkError))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                completion(.failure(.apiError("Invalid response")))
                return
            }

            print("🌐 Claude API Response Status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                print("✅ Claude API key validated successfully")
                completion(.success(true))
            case 401:
                print("❌ Invalid API key")
                completion(.failure(.invalidKey))
            case 429:
                print("❌ Rate limit exceeded")
                completion(.failure(.apiError("Rate limit exceeded")))
            case 500...599:
                print("❌ Server error: \(httpResponse.statusCode)")
                completion(.failure(.apiError("Server error: \(httpResponse.statusCode)")))
            default:
                print("❌ Unexpected status code: \(httpResponse.statusCode)")
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("Error response: \(errorString)")
                }
                completion(.failure(.apiError("Unexpected status code: \(httpResponse.statusCode)")))
            }
        }.resume()
    }

    func generateTranscript(text: String, goals: [String], generationType: GenerationType, completion: @escaping (Result<String, ClaudeError>) -> Void) {
        print("🤖 Starting Claude multi-pass transcript generation...")
        print("📝 Text length: \(text.count)")
        print("🎯 Goals count: \(goals.count)")
        print("🎭 Generation type: \(generationType.displayName)")

        validateAPIKey { [weak self] keyValidation in
            switch keyValidation {
            case .success:
                print("✅ API key validated, proceeding with multi-pass transcript generation")
                self?.performMultiPassGeneration(text: text, goals: goals, generationType: generationType, completion: completion)
            case .failure(let error):
                print("❌ API key validation failed: \(error)")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Multi-Pass Generation System

    private func performMultiPassGeneration(text: String, goals: [String], generationType: GenerationType, completion: @escaping (Result<String, ClaudeError>) -> Void) {
        print("🎯 Starting 2-pass focused generation system (Claude)...")

        // Pass 1: Extract key insights and patterns
        extractKeyInsights(text: text, goals: goals, generationType: generationType) { [weak self] insightsResult in
            switch insightsResult {
            case .success(let insights):
                print("✅ Pass 1 complete - Key insights extracted (\(insights.count) chars)")

                // Pass 2: Generate focused podcast using insights
                self?.generateFocusedPodcast(text: text, goals: goals, insights: insights, generationType: generationType) { finalResult in
                    switch finalResult {
                    case .success(let finalPodcast):
                        print("✅ Pass 2 complete - Focused podcast generated (\(finalPodcast.count) chars)")

                        // Check if audio test mode is enabled and truncate if needed
                        let audioTestMode = UserDefaults.standard.bool(forKey: "audioTestMode")
                        if audioTestMode {
                            let elevenLabsCharLimit = 5000
                            if finalPodcast.count > elevenLabsCharLimit {
                                let truncatedPodcast = String(finalPodcast.prefix(elevenLabsCharLimit))
                                print("🎧 Audio Test Mode: Truncated podcast to \(truncatedPodcast.count) characters")
                                completion(.success(truncatedPodcast))
                            } else {
                                completion(.success(finalPodcast))
                            }
                        } else {
                            completion(.success(finalPodcast))
                        }
                    case .failure(let error):
                        print("❌ Pass 2 failed: \(error)")
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                print("❌ Pass 1 failed: \(error)")
                completion(.failure(error))
            }
        }
    }

    private func extractKeyInsights(text: String, goals: [String], generationType: GenerationType, completion: @escaping (Result<String, ClaudeError>) -> Void) {
        print("🔍 Pass 1: Extracting key insights (Claude)...")

        let systemPrompt = getInsightsPrompt(for: generationType)
        let userMessage = """
        Weekly Reflections:
        \(text)

        Goals:
        \(goals.joined(separator: "\n- "))
        """

        makeAPICall(systemPrompt: systemPrompt, userMessage: userMessage, maxTokens: 1000, purpose: "key insights extraction", completion: completion)
    }

    private func generateFocusedPodcast(text: String, goals: [String], insights: String, generationType: GenerationType, completion: @escaping (Result<String, ClaudeError>) -> Void) {
        print("🎙️ Pass 2: Generating focused podcast (Claude)...")

        let systemPrompt = getFocusedPodcastPrompt(for: generationType)
        let userMessage = """
        KEY INSIGHTS TO BUILD UPON:
        \(insights)

        ORIGINAL USER DATA:
        Weekly Reflections: \(text)
        Goals: \(goals.joined(separator: ", "))
        """

        makeAPICall(systemPrompt: systemPrompt, userMessage: userMessage, maxTokens: 4000, purpose: "focused podcast generation", completion: completion)
    }

    internal func makeAPICall(systemPrompt: String, userMessage: String, maxTokens: Int, purpose: String, completion: @escaping (Result<String, ClaudeError>) -> Void) {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 120 // 2 minutes timeout

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.parseError))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Claude network error: \(error)")
                completion(.failure(.networkError))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("❌ Claude API Error: \(errorString)")
                }
                completion(.failure(.apiError("HTTP Error")))
                return
            }

            guard let data = data else {
                completion(.failure(.parseError))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {
                    print("✅ Claude \(purpose) successful (\(text.count) chars)")
                    completion(.success(text))
                } else {
                    print("❌ Failed to parse Claude response")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Raw response: \(responseString)")
                    }
                    completion(.failure(.parseError))
                }
            } catch {
                print("❌ JSON parsing error: \(error)")
                completion(.failure(.parseError))
            }
        }.resume()
    }

    func analyzeText(_ prompt: String) async throws -> String {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 8000,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ClaudeError.apiError("Invalid response")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw ClaudeError.parseError
        }

        // Check if audio test mode is enabled and truncate if needed
        let audioTestMode = UserDefaults.standard.bool(forKey: "audioTestMode")
        if audioTestMode {
            let elevenLabsCharLimit = 5000
            if text.count > elevenLabsCharLimit {
                let truncatedContent = String(text.prefix(elevenLabsCharLimit))
                print("🎧 Audio Test Mode: Truncated analyzeText result to \(truncatedContent.count) characters")
                return truncatedContent
            }
        }

        return text
    }

    // MARK: - Entry Metadata Generation

    struct EntryMetadata {
        let title: String
        let tags: [String]
    }

    func analyzeEntryForMetadata(content: String, completion: @escaping (Result<EntryMetadata, ClaudeError>) -> Void) {
        print("🏷️ Generating entry metadata (Claude)...")

        let systemPrompt = """
        You are a helpful assistant that generates concise titles and relevant topic tags for journal entries.

        Given a journal entry, you must:
        1. Generate a brief, descriptive title (3-6 words maximum) that captures the essence of the entry
        2. Generate 2-4 relevant topic tags that categorize the content

        Common tags include: work, relationships, health, personal growth, productivity, creativity, family, friends, exercise, mental health, career, learning, finances, travel, hobbies, challenges, achievements, reflection, goals, habits

        Return ONLY a JSON object with this exact format:
        {
            "title": "brief descriptive title",
            "tags": ["tag1", "tag2", "tag3"]
        }

        Do not include any other text or explanation.
        """

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 200,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": content]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.parseError))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Metadata generation network error: \(error)")
                completion(.failure(.networkError))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("❌ Metadata generation API error")
                completion(.failure(.apiError("HTTP Error")))
                return
            }

            guard let data = data else {
                completion(.failure(.parseError))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String,
                   let contentData = text.data(using: .utf8),
                   let metadataJson = try JSONSerialization.jsonObject(with: contentData) as? [String: Any],
                   let title = metadataJson["title"] as? String,
                   let tags = metadataJson["tags"] as? [String] {

                    let metadata = EntryMetadata(title: title, tags: tags)
                    print("✅ Generated metadata - Title: \(title), Tags: \(tags.joined(separator: ", "))")
                    completion(.success(metadata))
                } else {
                    print("❌ Failed to parse metadata response")
                    completion(.failure(.parseError))
                }
            } catch {
                print("❌ JSON parsing error: \(error)")
                completion(.failure(.parseError))
            }
        }.resume()
    }

    // MARK: - Image Analysis (Claude Vision)

    struct ImageAnalysisResult {
        let descriptions: [String]
        let combinedContext: String
    }

    func analyzeImages(_ images: [UIImage], completion: @escaping (Result<ImageAnalysisResult, ClaudeError>) -> Void) {
        print("🖼️ Analyzing \(images.count) images with Claude Vision...")

        guard !images.isEmpty else {
            completion(.success(ImageAnalysisResult(descriptions: [], combinedContext: "")))
            return
        }

        // Limit to 5 images maximum
        let imagesToAnalyze = Array(images.prefix(5))

        let systemPrompt = """
        You are a thoughtful assistant helping analyze images attached to journal entries. Your role is to describe what you see in each image in a way that provides meaningful context for personal reflection.

        For each image, provide:
        1. A brief description of what's in the image (people, places, objects, activities)
        2. The apparent mood or atmosphere
        3. Any details that might be personally meaningful (events, achievements, relationships)

        Be observant but respectful. Focus on what can be clearly seen, not assumptions.

        Return a JSON object with this exact format:
        {
            "images": [
                {
                    "description": "detailed description of image 1",
                    "mood": "apparent mood/atmosphere",
                    "significance": "potential personal significance"
                }
            ],
            "combined_context": "A brief summary of all images that could be used as additional context for a personal reflection podcast"
        }
        """

        // Build content array with images for Claude
        var contentArray: [[String: Any]] = []

        for (index, image) in imagesToAnalyze.enumerated() {
            if let imageData = image.jpegData(compressionQuality: 0.7) {
                let base64Image = imageData.base64EncodedString()
                contentArray.append([
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": base64Image
                    ]
                ])
                print("📷 Added image \(index + 1) to request")
            }
        }

        // Add the text prompt
        contentArray.append([
            "type": "text",
            "text": "Please analyze these journal entry images and provide descriptions that can be used as context for a personal reflection podcast."
        ])

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1000,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": contentArray]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Failed to serialize image analysis request: \(error)")
            completion(.failure(.parseError))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Image analysis network error: \(error)")
                completion(.failure(.networkError))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                completion(.failure(.apiError("Invalid response")))
                return
            }

            print("🌐 Image analysis response status: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("❌ Image analysis error response: \(errorString)")
                }
                completion(.failure(.apiError("HTTP Error: \(httpResponse.statusCode)")))
                return
            }

            guard let data = data else {
                completion(.failure(.parseError))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String,
                   let contentData = text.data(using: .utf8),
                   let analysisJson = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] {

                    var descriptions: [String] = []
                    if let imagesArray = analysisJson["images"] as? [[String: Any]] {
                        for imageInfo in imagesArray {
                            if let desc = imageInfo["description"] as? String {
                                descriptions.append(desc)
                            }
                        }
                    }

                    let combinedContext = analysisJson["combined_context"] as? String ?? ""

                    let result = ImageAnalysisResult(
                        descriptions: descriptions,
                        combinedContext: combinedContext
                    )

                    print("✅ Image analysis complete - \(descriptions.count) descriptions generated")
                    completion(.success(result))
                } else {
                    print("❌ Failed to parse image analysis response")
                    completion(.failure(.parseError))
                }
            } catch {
                print("❌ JSON parsing error in image analysis: \(error)")
                completion(.failure(.parseError))
            }
        }.resume()
    }

    // MARK: - System Prompts (Same as OpenAI)

    private func getInsightsPrompt(for generationType: GenerationType) -> String {
        let basePersonality = generationType == .goodListener ?
            "thoughtful, empathetic, and insightful guide" :
            "grounded, wise, and emotionally attuned mentor"

        return """
        You are a \(basePersonality) analyzing user data to extract key insights for a focused 5-8 minute podcast.

        STRICT REQUIREMENTS:
        - Be concise and specific
        - NO repetitive phrases or filler language
        - NO flowery or overly elaborate language
        - Focus on observable patterns only

        Your task:
        1. Identify 3-4 specific patterns from their reflections that relate to their goals
        2. Find concrete examples of behaviors, thoughts, or emotions that repeat
        3. Connect these patterns to their stated goals (supporting or contradicting)
        4. Highlight blind spots or growth opportunities

        Extract insights that are:
        - Specific and observable (not generic advice)
        - Directly referenced in their data
        - Connected to their personal goals
        - Actionable and meaningful

        Format as a structured list of insights with specific examples from their data.
        Keep your response under 500 words total.
        """
    }

    private func getFocusedPodcastPrompt(for generationType: GenerationType) -> String {
        let tone = generationType == .goodListener ?
            "warm, motivating, occasionally challenging, and always deeply personal" :
            "warm, clear, and unafraid to challenge. Noticing without judging. Encouraging without sugarcoating"

        return """
        You are creating a focused 5-8 minute personal growth podcast episode. Using the extracted insights, create a cohesive, data-driven episode that speaks directly to the user's patterns and goals.

        CRITICAL REQUIREMENTS:
        - MAXIMUM 1,200 words total
        - NO repetitive phrases or filler language
        - NO flowery or overly elaborate language
        - Be direct and conversational
        - Every sentence must add value

        Your tone should be \(tone).

        Create a complete podcast episode (1,000-1,200 words) with:

        **Introduction (200-300 words)**
        - Brief, warm welcome
        - Preview the specific insights you'll explore
        - Get straight to the point

        **Main Content (600-800 words)**
        - Focus on the 3-4 key insights extracted from their data
        - Use specific examples from their reflections
        - Connect patterns directly to their stated goals
        - Address blind spots with compassion
        - Provide actionable next steps

        **Conclusion (200-300 words)**
        - Synthesize the main insights briefly
        - Offer specific guidance for the week ahead
        - End with encouragement and momentum

        Requirements:
        - Reference specific details from their reflections (no generic advice)
        - Connect every insight to their personal goals
        - Keep it focused and actionable
        - Feel like a conversation with someone who truly knows them
        - Absolutely NO repetitive phrases or words
        - Stay within 5-8 minutes of content

        Build the entire podcast around the extracted insights - no filler content.
        """
    }
}
