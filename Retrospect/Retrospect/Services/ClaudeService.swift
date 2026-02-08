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
        1. Generate a brief, descriptive title (3-6 words maximum) that captures the essence
        2. Generate 2-4 relevant topic tags

        Common tags include: work, relationships, health, personal growth, productivity, creativity, family, friends, exercise, mental health, career, learning, finances, travel, hobbies, challenges, achievements, reflection, goals, habits, self-esteem, anxiety, confidence, self-criticism, cognitive distortions, wins, capability

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
        You are a thoughtful assistant analyzing images attached to journal entries to provide meaningful context for personal reflection and self-esteem work.

        For each image, provide:
        1. Brief description (people, places, objects, activities)
        2. Apparent mood or atmosphere
        3. Potential personal significance — especially evidence of capability, connection, or achievement

        Be observant but respectful. Focus on what can be clearly seen.

        **CBT LENS:** If images show evidence of:
        - Accomplishments or wins the user might be dismissing
        - Social connection the user might be discounting
        - Activities demonstrating capability
        Note these as they may be counter-evidence to negative beliefs.

        Return JSON:
        {
            "images": [
                {
                    "description": "detailed description",
                    "mood": "apparent mood/atmosphere",
                    "significance": "potential personal significance, especially capability evidence"
                }
            ],
            "combined_context": "Brief summary for reflection podcast, highlighting any capability evidence visible in images"
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
            "compassionate but direct CBT therapist" :
            "action-oriented CBT therapist focused on behavioral activation"

        return """
        You are a \(basePersonality) analyzing user data to extract CBT-focused insights for a 5-8 minute podcast on building self-esteem.

        **Your task:**

        1. **IDENTIFY EVIDENCE OF CAPABILITY** — Specific instances where they demonstrated competence, resilience, problem-solving
           - Count them. Be precise: "Handled conflict successfully 4 times"
           - Note if they acknowledged it or dismissed it

        2. **IDENTIFY COGNITIVE DISTORTIONS** — Unhelpful thinking patterns in their reflections
           - All-or-nothing, overgeneralization, catastrophizing, discounting positives, etc.
           - Show the pattern with examples from their data

        3. **IDENTIFY THOUGHT→BEHAVIOR LINKS** — How thoughts led to feelings and actions
           - "Thought 'I'll fail' → felt anxious → procrastinated → rushed work"

        4. **IDENTIFY CAPABILITY THEY'RE MISSING** — Strengths they demonstrated but didn't acknowledge
           - What are they systematically good at but don't see?

        **REQUIREMENTS:**
        - Be SPECIFIC with evidence — no generic observations
        - NO flowery language — be direct and concrete
        - Connect everything to their stated goals
        - Highlight blind spots compassionately but clearly

        Format as structured list with:
        - Type: capability_evidence | cognitive_distortion | thought_behavior_link | hidden_strength
        - Specific examples from their data
        - Connection to goal

        Keep response under 500 words total.
        """
    }

    private func getFocusedPodcastPrompt(for generationType: GenerationType) -> String {
        let tone = generationType == .goodListener ?
            "warm, direct, evidence-based — no toxic positivity" :
            "direct, energizing, action-oriented — challenge harsh self-criticism"

        return """
        You are creating a focused 5-8 minute CBT podcast on building self-esteem. Using the extracted insights, create an episode that challenges distortions and presents counter-evidence.

        **CRITICAL REQUIREMENTS:**
        - MAXIMUM 1,200 words total
        - NO repetitive phrases or filler
        - Be DIRECT and SPECIFIC
        - Every sentence must add therapeutic value

        Tone: \(tone)

        **STRUCTURE:**

        **Introduction (200-300 words)**
        - Acknowledge their week
        - Preview the challenge: "I want to show you something you're not seeing..."

        **Evidence Presentation (300-400 words)**
        - Present SPECIFIC instances of capability with counts
        - Be FORCEFUL: "This isn't luck. Here's proof..."
        - Challenge most active cognitive distortion with evidence

        **Behavioral Experiment (200-300 words)**
        - ONE specific action to test a belief or build capability
        - Frame as experiment: "This week, try X and track what ACTUALLY happens vs. what you predict"
        - Explain what it will teach them

        **Closing (200-300 words)**
        - Self-compassion (not positivity): "Progress, not perfection"
        - Remind them of track record with evidence
        - Forward momentum

        **REQUIREMENTS:**
        - Reference SPECIFIC details from their reflections (no generic advice)
        - Challenge distortions by NAME
        - Present counter-evidence with numbers/examples
        - Prescribe ONE clear behavioral experiment
        - NO repetitive language
        - Feel like a therapist who knows them and cares enough to challenge

        Build around the extracted insights — no filler content.
        """
    }
}
