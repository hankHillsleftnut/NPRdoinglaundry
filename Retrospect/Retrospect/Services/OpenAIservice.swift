import Foundation
import UIKit

enum OpenAIError: Error {
    case networkError
    case parseError
    case apiError(String)
    case invalidKey
    case deepResearchTimeout
    case deepResearchFailed
}

// MARK: - Supercharge Support
struct DeepResearchRequest {
    let query: String
    let userContext: String
    let goals: [String]
    let enableBackground: Bool
    let maxOutputTokens: Int
    
    init(query: String, userContext: String, goals: [String], enableBackground: Bool = true, maxOutputTokens: Int = 32000) {
        self.query = query
        self.userContext = userContext
        self.goals = goals
        self.enableBackground = enableBackground
        self.maxOutputTokens = maxOutputTokens
    }
}

struct DeepResearchResponse {
    let content: String
    let citations: [Citation]
    let reasoningSteps: [String]
    let searchQueries: [String]
}

class OpenAIService {
    static let shared: OpenAIService = {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String else {
            fatalError("OpenAI API key not found in Info.plist")
        }
        return OpenAIService(apiKey: apiKey)
    }()
    
    private let apiKey: String
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let deepResearchURL = URL(string: "https://api.openai.com/v1/responses")!
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func validateAPIKey(completion: @escaping (Result<Bool, OpenAIError>) -> Void) {
        print("🔑 Validating OpenAI API key...")
        
        // Create a minimal request to test the API key
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "user", "content": "Hello, can you confirm this is a valid API key test?"]
            ],
            "max_tokens": 10
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("❌ Failed to serialize request body: \(error)")
            completion(.failure(.invalidKey))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Check for network errors
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(.networkError))
                return
            }
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                completion(.failure(.apiError("Invalid response")))
                return
            }
            
            print("🌐 API Response Status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                print("✅ API key validated successfully")
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
    
    func generateTranscript(text: String, goals: [String], generationType: GenerationType, completion: @escaping (Result<String, OpenAIError>) -> Void) {
        print("🤖 Starting OpenAI multi-pass transcript generation...")
        print("📝 Text length: \(text.count)")
        print("🎯 Goals count: \(goals.count)")
        print("🎭 Generation type: \(generationType.displayName)")
        
        // Validate API key first
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
    
    private func performTranscriptGeneration(text: String, goals: [String], generationType: GenerationType, completion: @escaping (Result<String, OpenAIError>) -> Void) {
        print("🚀 Preparing OpenAI API request...")
        
        // Get system prompt based on generation type
        let systemPrompt = getSystemPrompt(for: generationType)
        
        print("📤 Sending request to OpenAI...")
        print("Text length: \(text.count)")
        print("Number of goals: \(goals.count)")
        
        // Prepare request
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": """
            Weekly Reflections:
            \(text)
            
            Goals:
            \(goals.joined(separator: "\n- "))
            """]
        ]
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "temperature": 0.4,
            "max_tokens": 8000,
            "top_p": 0.9,
            "frequency_penalty": 0.8,
            "presence_penalty": 0.6
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("📦 Request prepared successfully")
            
            if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                print("📦 Request body preview: \(String(bodyString.prefix(200)))...")
            }
        } catch {
            print("❌ Failed to serialize request body: \(error)")
            completion(.failure(.parseError))
            return
        }
        
        print("🌐 Starting API request...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Check for network errors
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(.networkError))
                return
            }
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                completion(.failure(.apiError("Invalid response")))
                return
            }
            
            print("🌐 API Response Status: \(httpResponse.statusCode)")
            print("🌐 Response Headers: \(httpResponse.allHeaderFields)")
            
            // Check response status
            guard (200...299).contains(httpResponse.statusCode) else {
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("❌ API Error response: \(errorString)")
                }
                completion(.failure(.apiError("HTTP Error: \(httpResponse.statusCode)")))
                return
            }
            
            // Parse JSON response
            guard let data = data else {
                print("❌ No data in response")
                completion(.failure(.parseError))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    print("✅ Successfully generated transcript")
                    print("📝 Response length: \(content.count)")
                    
                    // Check if audio test mode is enabled and truncate if needed
                    let audioTestMode = UserDefaults.standard.bool(forKey: "audioTestMode")
                    if audioTestMode {
                        let elevenLabsCharLimit = 5000 // ElevenLabs character limit for eleven_v3
                        if content.count > elevenLabsCharLimit {
                            let truncatedContent = String(content.prefix(elevenLabsCharLimit))
                            print("🎧 Audio Test Mode: Truncated transcript to \(truncatedContent.count) characters")
                            completion(.success(truncatedContent))
                        } else {
                            completion(.success(content))
                        }
                    } else {
                        completion(.success(content))
                    }
                } else {
                    print("❌ Failed to parse response")
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
    
    // MARK: - Multi-Pass Generation System
    
    private func performMultiPassGeneration(text: String, goals: [String], generationType: GenerationType, completion: @escaping (Result<String, OpenAIError>) -> Void) {
        print("🎯 Starting 2-pass focused generation system...")
        
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
                            let elevenLabsCharLimit = 5000 // ElevenLabs character limit for eleven_v3
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
    
    private func extractKeyInsights(text: String, goals: [String], generationType: GenerationType, completion: @escaping (Result<String, OpenAIError>) -> Void) {
        print("🔍 Pass 1: Extracting key insights...")
        
        let insightsPrompt = getInsightsPrompt(for: generationType)
        let messages: [[String: Any]] = [
            ["role": "system", "content": insightsPrompt],
            ["role": "user", "content": """
            Weekly Reflections:
            \(text)
            
            Goals:
            \(goals.joined(separator: "\n- "))
            """]
        ]
        
        makeAPICall(messages: messages, maxTokens: 1000, purpose: "key insights extraction", completion: completion)
    }
    
    private func generateFocusedPodcast(text: String, goals: [String], insights: String, generationType: GenerationType, completion: @escaping (Result<String, OpenAIError>) -> Void) {
        print("🎙️ Pass 2: Generating focused podcast...")
        
        let podcastPrompt = getFocusedPodcastPrompt(for: generationType)
        let messages: [[String: Any]] = [
            ["role": "system", "content": podcastPrompt],
            ["role": "user", "content": """
            KEY INSIGHTS TO BUILD UPON:
            \(insights)
            
            ORIGINAL USER DATA:
            Weekly Reflections: \(text)
            Goals: \(goals.joined(separator: ", "))
            """]
        ]
        
        makeAPICall(messages: messages, maxTokens: 1500, purpose: "focused podcast generation", completion: completion)
    }
    
    internal func makeAPICall(messages: [[String: Any]], maxTokens: Int, purpose: String, completion: @escaping (Result<String, OpenAIError>) -> Void) {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 90 // 1.5 minutes timeout for focused generations
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "temperature": 0.3,  // Slightly lower for more consistency
            "max_tokens": maxTokens,
            "top_p": 0.9,
            "frequency_penalty": 0.1,  // FIXED: Much lower to prevent weird vocabulary
            "presence_penalty": 0.1    // FIXED: Much lower to maintain topic coherence
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.parseError))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.apiError("HTTP Error")))
                return
            }
            
            guard let data = data else {
                completion(.failure(.parseError))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    print("✅ \(purpose) successful (\(content.count) chars)")
                    completion(.success(content))
                } else {
                    completion(.failure(.parseError))
                }
            } catch {
                completion(.failure(.parseError))
            }
        }.resume()
    }
    
    func analyzeText(_ prompt: String) async throws -> String {
        // Prepare request
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let messages: [[String: Any]] = [
            ["role": "user", "content": prompt]
        ]
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "temperature": 0.3,  // Slightly lower for more consistency
            "max_tokens": 8000,
            "top_p": 0.9,
            "frequency_penalty": 0.1,  // FIXED: Much lower to prevent weird vocabulary
            "presence_penalty": 0.1    // FIXED: Much lower to maintain topic coherence
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OpenAIError.apiError("Invalid response")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.parseError
        }
        
        // Check if audio test mode is enabled and truncate if needed
        let audioTestMode = UserDefaults.standard.bool(forKey: "audioTestMode")
        if audioTestMode {
            let elevenLabsCharLimit = 5000 // ElevenLabs character limit for eleven_v3
            if content.count > elevenLabsCharLimit {
                let truncatedContent = String(content.prefix(elevenLabsCharLimit))
                print("🎧 Audio Test Mode: Truncated analyzeText result to \(truncatedContent.count) characters")
                return truncatedContent
            }
        }
        
        return content
    }
    
    // MARK: - Supercharge Methods
    
    func generateDeepResearchTranscript(
        text: String, 
        goals: [String], 
        generationType: GenerationType,
        completion: @escaping (Result<DeepResearchResponse, OpenAIError>) -> Void
    ) {
        print("⚡ Starting Supercharge generation...")
        
        let systemPrompt = getDeepResearchSystemPrompt(for: generationType)
        let userQuery = buildDeepResearchQuery(text: text, goals: goals, generationType: generationType)
        
        let request = DeepResearchRequest(
            query: userQuery,
            userContext: systemPrompt,
            goals: goals,
            enableBackground: true,
            maxOutputTokens: 32000
        )
        
        performDeepResearch(request: request, completion: completion)
    }
    
    private func performDeepResearch(
        request: DeepResearchRequest,
        completion: @escaping (Result<DeepResearchResponse, OpenAIError>) -> Void
    ) {
        var urlRequest = URLRequest(url: deepResearchURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 1800 // 30 minutes for supercharge mode
        
        let requestBody: [String: Any] = [
            "model": "o3-deep-research-2025-06-26",
            "input": [
                [
                    "role": "developer",
                    "content": [
                        [
                            "type": "input_text",
                            "text": request.userContext
                        ]
                    ]
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": request.query
                        ]
                    ]
                ]
            ],
            "reasoning": [
                "summary": "auto"
            ],
            "tools": [
                [
                    "type": "web_search_preview"
                ]
            ],
            "background": request.enableBackground,
            "max_output_tokens": request.maxOutputTokens
        ]
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(.parseError))
            return
        }
        
        print("🌐 Starting Supercharge API call...")
        
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print("❌ Supercharge network error: \(error)")
                completion(.failure(.networkError))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.apiError("Invalid response")))
                return
            }
            
            print("🌐 Supercharge Response Status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("❌ Supercharge API Error: \(errorString)")
                }
                completion(.failure(.apiError("HTTP Error: \(httpResponse.statusCode)")))
                return
            }
            
            guard let data = data else {
                completion(.failure(.parseError))
                return
            }
            
            do {
                let response = try self.parseDeepResearchResponse(data: data)
                completion(.success(response))
            } catch {
                print("❌ Supercharge parsing error: \(error)")
                completion(.failure(.parseError))
            }
        }.resume()
    }
    
    private func parseDeepResearchResponse(data: Data) throws -> DeepResearchResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [[String: Any]] else {
            throw OpenAIError.parseError
        }
        
        // Find the final content
        var finalContent = ""
        var citations: [Citation] = []
        var reasoningSteps: [String] = []
        var searchQueries: [String] = []
        
        for item in output {
            if let type = item["type"] as? String {
                switch type {
                case "text":
                    if let content = item["content"] as? [[String: Any]],
                       let firstContent = content.first,
                       let text = firstContent["text"] as? String {
                        finalContent = text
                        
                        // Parse citations
                        if let annotations = firstContent["annotations"] as? [[String: Any]] {
                            for annotation in annotations {
                                if let title = annotation["title"] as? String,
                                   let url = annotation["url"] as? String,
                                   let startIndex = annotation["start_index"] as? Int,
                                   let endIndex = annotation["end_index"] as? Int {
                                    let citation = Citation(
                                        title: title,
                                        url: url,
                                        startIndex: startIndex,
                                        endIndex: endIndex
                                    )
                                    citations.append(citation)
                                }
                            }
                        }
                    }
                case "reasoning":
                    if let summary = item["summary"] as? [[String: Any]] {
                        for step in summary {
                            if let text = step["text"] as? String {
                                reasoningSteps.append(text)
                            }
                        }
                    }
                case "web_search_call":
                    if let action = item["action"] as? [String: Any],
                       let query = action["query"] as? String {
                        searchQueries.append(query)
                    }
                default:
                    break
                }
            }
        }
        
        return DeepResearchResponse(
            content: finalContent,
            citations: citations,
            reasoningSteps: reasoningSteps,
            searchQueries: searchQueries
        )
    }
    
    private func buildDeepResearchQuery(text: String, goals: [String], generationType: GenerationType) -> String {
        return """
        Please research current best practices, scientific studies, and expert insights related to the following personal development scenario:
        
        **User's Weekly Reflections:**
        \(text)
        
        **User's Goals:**
        \(goals.joined(separator: "\n- "))
        
        **Research Focus:**
        Research the latest evidence-based strategies, psychological research, and expert recommendations that would help this person achieve their goals based on their current patterns and challenges. Include:
        
        1. Recent scientific studies on habit formation and behavior change related to their goals
        2. Evidence-based strategies for overcoming the specific challenges they mention
        3. Current best practices in personal development for their situation
        4. Expert insights from psychology, productivity, and wellness research
        5. Practical, actionable steps backed by research
        
        Format your findings as a comprehensive research report with proper citations that can be used to create a personalized development podcast.
        """
    }
    
    private func getDeepResearchSystemPrompt(for generationType: GenerationType) -> String {
        let basePersonality = generationType == .goodListener ? 
            "thoughtful, empathetic, and insightful guide" : 
            "grounded, wise, and emotionally attuned mentor"
        
        return """
        You are a \(basePersonality) and expert researcher specializing in personal development, psychology, and behavioral science.
        
        Your task is to conduct thorough research to support personalized guidance for someone working on their personal growth. You should:
        
        1. Research current scientific literature on topics relevant to their reflections and goals
        2. Find evidence-based strategies and interventions
        3. Look for expert insights from psychology, neuroscience, and behavioral science
        4. Identify practical, actionable approaches backed by research
        5. Consider cultural and individual differences in your recommendations
        
        Focus on:
        - Recent peer-reviewed studies (last 5 years preferred)
        - Evidence-based practices with proven outcomes
        - Expert insights from recognized authorities
        - Practical applications that can be implemented immediately
        - Addressing specific patterns and challenges mentioned in their reflections
        
        Your research should be comprehensive, well-cited, and focused on providing actionable insights for personal growth and goal achievement.
        """
    }
    
    // MARK: - System Prompts
    private func getSystemPrompt(for generationType: GenerationType) -> String {
        switch generationType {
        case .goodListener:
            return getGoodListenerSystemPrompt()
        case .growthMentor:
            return getGrowthMentorSystemPrompt()
        }
    }
    
    private func getGoodListenerSystemPrompt() -> String {
        return """
        You are a thoughtful, empathetic, and insightful guide designed to help users grow into the person they want to become. You do this by analyzing a wide range of data from their life — including health data (e.g., from HealthKit), personal notes, calendar events, email summaries, video and transcript journal entries, and written goals.
        Your primary task is to filter this bucket of information through the lens of the user's short-, medium-, and long-term goals. Discard irrelevant or distracting information. From what remains, identify what matters — the data that is aligned with their desired future self.
        Then, expand on this filtered information: add helpful context, identify emotional or behavioral patterns, and connect dots across otherwise unrelated moments. Seek out emerging themes, habits, or blind spots. The goal is to derive personal insights that are highly relevant to where the user wants to go in life.
        Using these insights, create a podcast episode designed specifically for the user to listen to. The tone should be warm, motivating, occasionally challenging, and always deeply personal. The episode should:
        * Remind the user of what matters most to them
        * Highlight progress or areas for reflection
        * Offer comfort or clarity where needed
        * Reframe negative patterns in service of their growth
        * Encourage habits, mindsets, and actions aligned with their goals
        Your ultimate purpose is to rewire the user's subconscious through personalized, emotionally resonant storytelling— helping them internalize the behaviors, beliefs, and intentions required to become who they are meant to be. Make this a 10 minute or more, thorough, chapter based podcasts, with great transitions and deep insights. Play with being literal and using metaphors in making your points.
        """
    }
    
    private func getGrowthMentorSystemPrompt() -> String {
        return """
        You are a grounded, wise, and emotionally attuned guide — part mentor, part therapist — dedicated to helping users become the fullest version of themselves. You offer not just support, but perspective. Your strength lies in noticing patterns, asking the right questions, and gently guiding the user toward growth through thoughtful insight and actionable reflection.
        Using these insights, create a podcast episode designed specifically for the user to listen to. The tone should be warm, motivating, occasionally challenging, and always deeply personal. Make this a thorough, chapter based podcast, with great transitions and deep insights. Play with being literal and using metaphors in making your points.
        """
    }
    
    // MARK: - Multi-Pass Prompts
    
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
    
    // MARK: - Entry Metadata Generation
    
    struct EntryMetadata {
        let title: String
        let tags: [String]
    }
    
    func analyzeEntryForMetadata(content: String, completion: @escaping (Result<EntryMetadata, OpenAIError>) -> Void) {
        print("🏷️ Generating entry metadata...")
        
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
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": content]
        ]
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 100,
            "response_format": ["type": "json_object"]
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
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String,
                   let contentData = content.data(using: .utf8),
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
    
    // MARK: - Image Analysis (GPT-4 Vision)
    
    struct ImageAnalysisResult {
        let descriptions: [String]
        let combinedContext: String
    }
    
    /// Analyze images using GPT-4 Vision and return descriptions for podcast context
    func analyzeImages(_ images: [UIImage], completion: @escaping (Result<ImageAnalysisResult, OpenAIError>) -> Void) {
        print("🖼️ Analyzing \(images.count) images with GPT-4 Vision...")
        
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
        
        // Build content array with images
        var contentArray: [[String: Any]] = [
            ["type": "text", "text": "Please analyze these journal entry images and provide descriptions that can be used as context for a personal reflection podcast."]
        ]
        
        for (index, image) in imagesToAnalyze.enumerated() {
            if let imageData = image.jpegData(compressionQuality: 0.7) {
                let base64Image = imageData.base64EncodedString()
                contentArray.append([
                    "type": "image_url",
                    "image_url": [
                        "url": "data:image/jpeg;base64,\(base64Image)",
                        "detail": "low" // Use low detail to reduce token usage
                    ]
                ])
                print("📷 Added image \(index + 1) to request")
            }
        }
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": contentArray]
        ]
        
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 1000,
            "response_format": ["type": "json_object"]
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
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String,
                   let contentData = content.data(using: .utf8),
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

}
