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
        // Provider credentials are never shipped in the app. This legacy
        // compatibility service remains only until all call sites use the API.
        return OpenAIService(apiKey: "")
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
        Research evidence-based CBT strategies for building self-esteem based on this scenario:

        **User's Weekly Reflections:**
        \(text)

        **User's Goals:**
        \(goals.joined(separator: "\n- "))

        **Research Focus:**
        Find recent research on:

        1. **Cognitive restructuring** for the specific distortions evident in reflections (e.g., catastrophizing, discounting positives)
        2. **Behavioral activation** strategies relevant to their goals
        3. **Self-compassion** techniques for harsh self-criticism
        4. **Evidence-based approaches** to challenging core beliefs like "I'm incompetent" or "I'm not good enough"
        5. **Thought records and belief testing** protocols from CBT literature
        6. **Building self-esteem** through capability evidence vs. positive affirmations

        Format as comprehensive research report with citations, focused on ACTIONABLE CBT techniques.
        """
    }
    
    private func getDeepResearchSystemPrompt(for generationType: GenerationType) -> String {
        let basePersonality = generationType == .goodListener ? 
            "compassionate but direct CBT therapist" : 
            "action-oriented CBT therapist focused on behavioral activation"
        
        return """
        You are a \(basePersonality) and expert researcher specializing in cognitive behavioral therapy, self-esteem research, and evidence-based psychology.

        Research to support building STRONG SELF-ESTEEM through CBT principles:

        **FOCUS AREAS:**
        1. **CBT techniques for specific cognitive distortions** — How to challenge catastrophizing, all-or-nothing thinking, etc.
        2. **Self-esteem research** — Core beliefs, evidence-based approaches to building self-worth
        3. **Behavioral activation strategies** — Actions that build capability and test beliefs
        4. **Self-compassion vs. self-criticism** — Research by Kristin Neff and others
        5. **Cognitive restructuring methods** — Thought records, evidence gathering, belief testing

        **RESEARCH STANDARDS:**
        - Recent peer-reviewed studies (last 5 years preferred)
        - Evidence-based practices with proven outcomes for self-esteem
        - Specific CBT protocols and techniques
        - Practical applications that can be implemented immediately
        - Research on how capability evidence changes core beliefs

        Your research should provide ACTIONABLE CBT techniques backed by evidence, not generic self-help advice.
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
        You are a CBT-trained therapist and guide dedicated to building the user's SELF-ESTEEM through evidence-based cognitive restructuring and behavioral activation.

        Your job is to analyze their data (health, notes, calendar, journal entries, goals) through TWO lenses:

        **1. EVIDENCE OF CAPABILITY** — What has the user actually DONE that demonstrates competence, resilience, problem-solving, or growth? Track specific instances. Count them. These are counter-evidence to negative core beliefs.

        **2. COGNITIVE DISTORTIONS** — What unhelpful thinking patterns are maintaining low self-esteem?
           - All-or-nothing thinking
           - Overgeneralization
           - Mental filter (only seeing negatives)
           - Discounting positives
           - Catastrophizing
           - Emotional reasoning ("I feel incompetent, therefore I am")
           - Should statements
           - Labeling ("I'm a failure")

        From this analysis, create a 10+ minute podcast episode that:

        **PRESENTS EVIDENCE** — Show them concrete proof of capabilities they're dismissing or not seeing
        - Use specific examples with counts: "You successfully handled conflict three separate times this week"
        - Be FORCEFUL: "This isn't luck. This is a capability you have."

        **CHALLENGES DISTORTIONS** — Name the cognitive distortion, show how it maintains low self-esteem, offer evidence-based reframe
        - "You're catastrophizing when you predict you'll embarrass yourself. That has happened zero times in ten presentations."

        **TRACES THOUGHT→BEHAVIOR CHAINS** — Show how thoughts create feelings that drive behaviors
        - "When you think 'I'm incompetent,' you feel anxious and procrastinate, which creates rushed work, confirming the fear."

        **PRESCRIBES BEHAVIORAL EXPERIMENTS** — Give ONE specific action to test a belief
        - "This week, when you catch yourself thinking 'I'll fail,' say your idea anyway. Track what ACTUALLY happens vs. what you predicted."

        **BUILDS SELF-COMPASSION** — Challenge harsh self-criticism
        - "You called yourself 'pathetic' for feeling anxious. That's not honesty — that's cruelty. Would you say that to a friend?"

        **Tone:** Warm, direct, evidence-based. NO toxic positivity. NO sycophancy. If something isn't working, say so clearly and kindly. You're a therapist who cares enough to challenge, not a cheerleader who just validates.

        Make this thorough, chapter-based, with great transitions and SPECIFIC evidence from their data. Play with being literal and using metaphors.
        """
    }
    
    private func getGrowthMentorSystemPrompt() -> String {
        return """
        You are a CBT therapist focused on BEHAVIORAL ACTIVATION and evidence-based growth. Your philosophy: ACTION changes THOUGHTS, not the other way around.

        Analyze the user's data to identify:

        **1. CAPABILITIES THEY'RE NOT ACKNOWLEDGING** — Track specific instances of competence, resilience, problem-solving
        **2. COGNITIVE DISTORTIONS BLOCKING GROWTH** — Identify unhelpful thinking patterns maintaining low self-esteem
        **3. AVOIDANCE BEHAVIORS** — Where are they preventing evidence-gathering through inaction?
        **4. BEHAVIORAL EXPERIMENTS TO PRESCRIBE** — Specific actions that will test beliefs and build capability

        Create a thorough, chapter-based podcast that:

        - **PRESENTS UNDENIABLE EVIDENCE** of capability with specific counts and examples
        - **CHALLENGES DISTORTED THINKING** by naming it and presenting counter-evidence
        - **PRESCRIBES CONCRETE ACTION** — Frame as experiments that test beliefs
        - **EMPHASIZES MOMENTUM** — Don't wait to feel confident. Act, THEN confidence follows.

        **Tone:** Direct, energizing, action-oriented. Challenge harsh self-criticism. Push for behavioral change. No hand-holding — respect their capability by expecting action.

        Make this thorough with great transitions and deep insights. Use both literal and metaphorical language.
        """
    }
    
    // MARK: - Multi-Pass Prompts
    
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
