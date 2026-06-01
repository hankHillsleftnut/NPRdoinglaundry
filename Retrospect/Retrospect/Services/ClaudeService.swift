import Foundation
import UIKit

enum ClaudeError: Error {
    case networkError
    case parseError
    case apiError(String)
    case invalidKey
}

class ClaudeService {
    static let shared = ClaudeService()

    private init() {}

    func validateAPIKey(completion: @escaping (Result<Bool, ClaudeError>) -> Void) {
        // Key is managed server-side; treat as always valid.
        completion(.success(true))
    }

    func generateTranscript(text: String, goals: [String], generationType: GenerationType, completion: @escaping (Result<String, ClaudeError>) -> Void) {
        print("🤖 Starting Claude multi-pass transcript generation...")
        print("📝 Text length: \(text.count)")
        print("🎯 Goals count: \(goals.count)")
        print("🎭 Generation type: \(generationType.displayName)")
        performMultiPassGeneration(text: text, goals: goals, generationType: generationType, completion: completion)
    }

    // MARK: - Multi-Pass Generation System

    private func performMultiPassGeneration(text: String, goals: [String], generationType: GenerationType, completion: @escaping (Result<String, ClaudeError>) -> Void) {
        print("🎯 Starting 2-pass focused generation system (Claude)...")

        extractKeyInsights(text: text, goals: goals, generationType: generationType) { [weak self] insightsResult in
            switch insightsResult {
            case .success(let insights):
                print("✅ Pass 1 complete - Key insights extracted (\(insights.count) chars)")
                self?.generateFocusedPodcast(text: text, goals: goals, insights: insights, generationType: generationType) { finalResult in
                    switch finalResult {
                    case .success(let finalPodcast):
                        print("✅ Pass 2 complete - Focused podcast generated (\(finalPodcast.count) chars)")
                        let audioTestMode = UserDefaults.standard.bool(forKey: "audioTestMode")
                        if audioTestMode {
                            let elevenLabsCharLimit = 5000
                            if finalPodcast.count > elevenLabsCharLimit {
                                let truncated = String(finalPodcast.prefix(elevenLabsCharLimit))
                                print("🎧 Audio Test Mode: Truncated podcast to \(truncated.count) characters")
                                completion(.success(truncated))
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
        Task {
            do {
                let text = try await RetrospectAPIClient.shared.claudeGenerate(
                    systemPrompt: systemPrompt,
                    userMessage: userMessage,
                    maxTokens: maxTokens
                )
                print("✅ Claude \(purpose) successful (\(text.count) chars)")
                completion(.success(text))
            } catch {
                print("❌ Claude \(purpose) failed: \(error)")
                completion(.failure(.apiError(error.localizedDescription)))
            }
        }
    }

    func analyzeText(_ prompt: String) async throws -> String {
        let text = try await RetrospectAPIClient.shared.claudeGenerate(
            userMessage: prompt,
            maxTokens: 8000
        )
        let audioTestMode = UserDefaults.standard.bool(forKey: "audioTestMode")
        if audioTestMode {
            let elevenLabsCharLimit = 5000
            if text.count > elevenLabsCharLimit {
                let truncated = String(text.prefix(elevenLabsCharLimit))
                print("🎧 Audio Test Mode: Truncated analyzeText result to \(truncated.count) characters")
                return truncated
            }
        }
        return text
    }

    // MARK: - Entry Metadata Generation

    struct EntryMetadata {
        let title: String
        let tags: [String]
    }

    // MARK: - Onboarding Goals Conversation

    func generateOnboardingGoalsReply(conversationMessages: [[String: Any]], completion: @escaping (Result<String, ClaudeError>) -> Void) {
        let systemPrompt = """
        You are Retrospect, a warm and thoughtful app that turns the user's life into a weekly podcast. Right now you're in a short onboarding conversation to learn about their goals. The user has just replied to your last message.

        Your job: reply with exactly one short message (1-3 sentences). Reference their exact words or a specific detail they shared; do not give a generic reply. Be genuinely curious. Ask one thoughtful follow-up that helps you understand what they want to change or focus on—day-to-day behavior, a recent moment, obstacles, or another area of life. Sound like a real person, not a form. No bullet points, no "Great!", no generic praise.
        """
        Task {
            do {
                let text = try await RetrospectAPIClient.shared.claudeGenerate(
                    systemPrompt: systemPrompt,
                    messages: conversationMessages,
                    maxTokens: 256
                )
                completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
            } catch {
                completion(.failure(.apiError(error.localizedDescription)))
            }
        }
    }

    func generateOnboardingAcknowledgment(
        question: String,
        answer: String,
        userName: String,
        completion: @escaping (Result<String, ClaudeError>) -> Void
    ) {
        let systemPrompt = """
        You are Retrospect, a personal growth app. A user just answered an onboarding question.
        Write 1-2 sentences that show you truly heard what they said.
        Rules:
        - Reference their specific words — not a paraphrase, their actual words or phrasing
        - Use their name naturally if it fits the sentence
        - Be warm but never sycophantic — no "Great answer!" or "That's wonderful!"
        - Do not ask a follow-up question
        - Do not give advice
        - Just reflect what you heard, with warmth
        - Under 40 words total
        """
        let userMessage = "User's name: \(userName)\nQuestion asked: \(question)\nTheir answer: \(answer)"
        Task {
            do {
                let text = try await RetrospectAPIClient.shared.claudeGenerate(
                    systemPrompt: systemPrompt,
                    userMessage: userMessage,
                    maxTokens: 120
                )
                completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
            } catch {
                completion(.failure(.apiError(error.localizedDescription)))
            }
        }
    }

    func extractGoalsFromConversation(conversationHistory: [[String: Any]], completion: @escaping (Result<[String], ClaudeError>) -> Void) {
        let systemPrompt = """
        You are analyzing a conversation where Retrospect asked the user about their goals for the next couple of months. Extract 2-4 specific, actionable goals from what the user said.

        CRITICAL REQUIREMENTS:
        - Be ACCURATE: Don't misclassify. If they say "I want to be better in the gym", extract "Exercise more" or "Fitness goals", NOT something unrelated.
        - Capture NUANCE: If they mention wanting to feel more confident at work, extract "Career growth" or "Professional confidence", not just "Work".
        - Be SPECIFIC: "Better sleep" not "Sleep", "Exercise more" not "Gym".
        - NO SHORTCUTS: Read the full conversation context. Don't miss important details.
        - Common goals: Exercise more, Better sleep, Read daily, Learn something new, Reduce stress, Eat healthier, Save money, Be more present, Improve focus, Build habits, Improve relationships, Career growth, Creativity

        Return ONLY a JSON array of goal strings, like: ["Exercise more", "Better sleep", "Career growth"]
        Do not include any other text or explanation.
        """
        let conversationText = conversationHistory.map { msg in
            let role = msg["role"] as? String ?? ""
            let content = msg["content"] as? String ?? ""
            return "\(role.capitalized): \(content)"
        }.joined(separator: "\n\n")
        let userMessage = "Conversation:\n\(conversationText)\n\nExtract 2-4 specific goals from this conversation."

        Task {
            do {
                let text = try await RetrospectAPIClient.shared.claudeGenerate(
                    systemPrompt: systemPrompt,
                    userMessage: userMessage,
                    maxTokens: 200
                )
                if let jsonData = text.data(using: .utf8),
                   let goalsArray = try? JSONSerialization.jsonObject(with: jsonData) as? [String] {
                    completion(.success(goalsArray))
                } else {
                    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.hasPrefix("[") && cleaned.hasSuffix("]") {
                        let inner = String(cleaned.dropFirst().dropLast())
                        let goals = inner.components(separatedBy: ",")
                            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\" ")) }
                            .filter { !$0.isEmpty }
                        completion(.success(goals))
                    } else {
                        completion(.failure(.parseError))
                    }
                }
            } catch {
                completion(.failure(.apiError(error.localizedDescription)))
            }
        }
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
        Task {
            do {
                let text = try await RetrospectAPIClient.shared.claudeGenerate(
                    systemPrompt: systemPrompt,
                    userMessage: content,
                    maxTokens: 200
                )
                if let data = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let title = json["title"] as? String,
                   let tags = json["tags"] as? [String] {
                    print("✅ Generated metadata - Title: \(title), Tags: \(tags.joined(separator: ", "))")
                    completion(.success(EntryMetadata(title: title, tags: tags)))
                } else {
                    print("❌ Failed to parse metadata response")
                    completion(.failure(.parseError))
                }
            } catch {
                print("❌ Metadata generation error: \(error)")
                completion(.failure(.apiError(error.localizedDescription)))
            }
        }
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
        contentArray.append([
            "type": "text",
            "text": "Please analyze these journal entry images and provide descriptions that can be used as context for a personal reflection podcast."
        ])

        let messages: [[String: Any]] = [
            ["role": "user", "content": contentArray]
        ]

        Task {
            do {
                let text = try await RetrospectAPIClient.shared.claudeGenerate(
                    systemPrompt: systemPrompt,
                    messages: messages,
                    maxTokens: 1000
                )
                if let data = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    var descriptions: [String] = []
                    if let imagesArray = json["images"] as? [[String: Any]] {
                        for imageInfo in imagesArray {
                            if let desc = imageInfo["description"] as? String {
                                descriptions.append(desc)
                            }
                        }
                    }
                    let combinedContext = json["combined_context"] as? String ?? ""
                    print("✅ Image analysis complete - \(descriptions.count) descriptions generated")
                    completion(.success(ImageAnalysisResult(descriptions: descriptions, combinedContext: combinedContext)))
                } else {
                    print("❌ Failed to parse image analysis response")
                    completion(.failure(.parseError))
                }
            } catch {
                print("❌ Image analysis error: \(error)")
                completion(.failure(.apiError(error.localizedDescription)))
            }
        }
    }

    // MARK: - System Prompts

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
