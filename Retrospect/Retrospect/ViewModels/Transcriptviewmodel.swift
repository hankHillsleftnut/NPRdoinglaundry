import Foundation
import Combine
import AVFoundation
import SwiftUI

// MARK: - Google Docs Content Structure
struct GoogleDocsContent {
    let includedDocuments: [String] // Document names that were included
    let failedDocuments: [String] // Document names that failed to load
    let contentText: String // Combined content text
    let totalCharacters: Int // Total characters across all documents
}

// MARK: - Reference Tracking System
struct ContentReference {
    let id = UUID()
    let type: ReferenceType
    let name: String
    let isIncluded: Bool
    
    enum ReferenceType {
        case userText
        case goals
        case healthData
        case document(String) // Document ID or name
        case journal(String) // Journal ID or date
        
        var icon: String {
            switch self {
            case .userText: return "text.quote"
            case .goals: return "target"
            case .healthData: return "heart.fill"
            case .document: return "doc.text"
            case .journal: return "book.closed"
            }
        }
        
        var color: String {
            switch self {
            case .userText: return "blue"
            case .goals: return "green"
            case .healthData: return "red"
            case .document: return "purple"
            case .journal: return "orange"
            }
        }
    }
}


class TranscriptViewModel: ObservableObject {
    @Published var transcript: TranscriptModel?
    @Published var savedPodcasts: [TranscriptModel] = []  // All saved podcasts
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var googleDocsInfo: GoogleDocsContent?
    @Published var processingStatus: String = ""
    @Published var isDeepResearchEnabled: Bool = false
    @Published var deepResearchCitations: [Citation] = []
    @Published var deepResearchProgress: String = ""
    
    // MARK: - Enhanced Loading System
    @Published var contentReferences: [ContentReference] = []
    @Published var currentProgress: Double = 0.0
    @Published var currentLoadingPhase: String = ""
    
    private var progressTimer: Timer?
    private var loadingStartTime: Date?
    @AppStorage("healthKitEnabled") private var healthKitEnabled: Bool = false
    @AppStorage("devMode") private var devMode: Bool = false
    @AppStorage("mockAPICalls") private var mockAPICalls: Bool = false
    @AppStorage("generationType") private var generationTypeRaw: String = GenerationType.goodListener.rawValue
    @AppStorage("deepResearchMode") var deepResearchMode: Bool = false
    
    private var generationType: GenerationType {
        GenerationType(rawValue: generationTypeRaw) ?? .goodListener
    }
    
    private let openAIService: OpenAIService
    private let textToSpeechService: TextToSpeechService
    private let elevenLabsService: ElevenLabsService
    private let googleDocsService: GoogleDocsService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Persistence
    private static let podcastsKey = "saved_podcasts"
    
    private var podcastsFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("podcasts.json")
    }
    
    // Sample audio URL for development
    private var sampleAudioURL: URL? {
        // Create a temporary URL for sample audio
        let tempDir = FileManager.default.temporaryDirectory
        let sampleURL = tempDir.appendingPathComponent("sample_reflection.m4a")
        
        // Generate a simple audio file if it doesn't exist
        if !FileManager.default.fileExists(atPath: sampleURL.path) {
            generateSampleAudioFile(at: sampleURL)
        }
        
        return sampleURL
    }
    
    init(
        openAIService: OpenAIService,
        textToSpeechService: TextToSpeechService,
        elevenLabsService: ElevenLabsService = .shared,
        googleDocsService: GoogleDocsService = .shared
    ) {
        self.openAIService = openAIService
        self.textToSpeechService = textToSpeechService
        self.elevenLabsService = elevenLabsService
        self.googleDocsService = googleDocsService
        
        // Load saved podcasts on init
        loadSavedPodcasts()
    }
    
    // MARK: - Podcast Persistence Methods
    
    func savePodcast(_ podcast: TranscriptModel) {
        // Add to saved podcasts if not already there
        if !savedPodcasts.contains(where: { $0.id == podcast.id }) {
            savedPodcasts.insert(podcast, at: 0) // Add to beginning (most recent first)
        } else {
            // Update existing podcast
            if let index = savedPodcasts.firstIndex(where: { $0.id == podcast.id }) {
                savedPodcasts[index] = podcast
            }
        }
        
        // Persist to disk
        savePodcastsToDisk()
        print("💾 Podcast saved. Total saved: \(savedPodcasts.count)")
    }
    
    func deletePodcast(_ podcast: TranscriptModel) {
        savedPodcasts.removeAll { $0.id == podcast.id }
        
        // Delete audio file if exists
        if let audioURL = podcast.audioFileURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
        
        savePodcastsToDisk()
        print("🗑️ Podcast deleted. Total saved: \(savedPodcasts.count)")
    }
    
    private func savePodcastsToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(savedPodcasts)
            try data.write(to: podcastsFileURL)
            print("💾 Podcasts saved to: \(podcastsFileURL.path)")
        } catch {
            print("❌ Failed to save podcasts: \(error.localizedDescription)")
        }
    }
    
    private func loadSavedPodcasts() {
        guard FileManager.default.fileExists(atPath: podcastsFileURL.path) else {
            print("📂 No saved podcasts file found")
            return
        }
        
        do {
            let data = try Data(contentsOf: podcastsFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            savedPodcasts = try decoder.decode([TranscriptModel].self, from: data)
            
            // Set the most recent podcast as the current transcript
            if let mostRecent = savedPodcasts.first {
                transcript = mostRecent
            }
            
            print("📂 Loaded \(savedPodcasts.count) saved podcasts")
        } catch {
            print("❌ Failed to load podcasts: \(error.localizedDescription)")
        }
        
        // Also fetch from backend
        fetchBackendPodcasts()
    }
    
    // MARK: - Backend Podcast Fetching
    
    /// Fetch podcast episodes from the Retrospect backend and merge with local podcasts.
    func fetchBackendPodcasts() {
        guard RetrospectAPIClient.shared.isAuthenticated else { return }
        
        Task {
            do {
                let episodes = try await RetrospectAPIClient.shared.fetchPodcasts()
                let backendTranscripts = episodes.map { $0.toTranscriptModel() }
                
                await MainActor.run {
                    // Merge: add backend podcasts that aren't already in saved list
                    for transcript in backendTranscripts {
                        if !savedPodcasts.contains(where: { $0.id == transcript.id }) {
                            savedPodcasts.append(transcript)
                        }
                    }
                    // Re-sort by date (newest first)
                    savedPodcasts.sort { $0.createdAt > $1.createdAt }
                    
                    // Update current transcript if none set
                    if self.transcript == nil, let mostRecent = savedPodcasts.first {
                        self.transcript = mostRecent
                    }
                    
                    print("Fetched \(episodes.count) backend episodes, total: \(savedPodcasts.count)")
                }
            } catch {
                print("Backend podcast fetch failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Supercharge Methods
    
    func generateDeepResearchTranscript(text: String, goals: [String]) {
        print("⚡ Starting Supercharge transcript generation...")
        print("Input text: \(text)")
        print("Goals: \(goals)")
        
        isProcessing = true
        errorMessage = nil
        deepResearchCitations = []
        
        // Initialize enhanced loading system for deep research
        initializeContentReferences(text: text, goals: goals)
        startRealisticProgress()
        
        processingStatus = "Initializing supercharge mode..."
        deepResearchProgress = "Planning research strategy..."
        
        // Start by fetching Google Docs content if connected
        fetchGoogleDocsContent { googleDocsContent in
            let combinedInput = self.buildCombinedInput(
                userText: text,
                goals: goals,
                googleDocsContent: googleDocsContent,
                healthSummary: nil
            )
            
            DispatchQueue.main.async {
                self.processingStatus = "Conducting supercharged research..."
                self.deepResearchProgress = "Analyzing your patterns and searching for relevant research..."
            }
            
            self.openAIService.generateDeepResearchTranscript(
                text: combinedInput,
                goals: goals,
                generationType: self.generationType
            ) { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    switch result {
                    case .success(let deepResearchResponse):
                        print("✅ Supercharge mode completed successfully")
                        print("📚 Citations found: \(deepResearchResponse.citations.count)")
                        print("🔍 Search queries used: \(deepResearchResponse.searchQueries.count)")
                        
                        self.deepResearchCitations = deepResearchResponse.citations
                        self.processingStatus = "Generating personalized insights..."
                        
                        // Now generate the focused podcast using the research
                        self.generateFocusedPodcastFromResearch(
                            originalText: text,
                            goals: goals,
                            research: deepResearchResponse.content,
                            citations: deepResearchResponse.citations
                        )
                        
                    case .failure(let error):
                        print("❌ Supercharge mode failed: \(error)")
                        self.handleError(error)
                        self.completeProgress()
                        self.isProcessing = false
                        self.processingStatus = ""
                        self.deepResearchProgress = ""
                    }
                }
            }
        }
    }
    
    private func generateFocusedPodcastFromResearch(
        originalText: String,
        goals: [String],
        research: String,
        citations: [Citation]
    ) {
        // Use regular OpenAI to create podcast from research
        let systemPrompt = getFocusedPodcastPrompt(for: generationType)
        let userPrompt = """
        Based on the following research findings, create a personalized podcast episode:
        
        **User's Original Reflections:**
        \(originalText)
        
        **User's Goals:**
        \(goals.joined(separator: ", "))
        
        **Research Findings:**
        \(research)
        
        Create a 5-8 minute podcast episode that weaves together the research findings with specific insights about this person's reflections and goals. Reference the research naturally but focus on making it personally relevant and actionable.
        """
        
        openAIService.makeAPICall(
            messages: [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            maxTokens: 2000,
            purpose: "research-based podcast generation"
        ) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let podcastContent):
                    print("✅ Research-based podcast generated")
                    
                    // Create transcript model with research metadata
                    let docsInfo: GoogleDocsInfo? = self.googleDocsInfo.map { docsContent in
                        GoogleDocsInfo(
                            includedDocuments: docsContent.includedDocuments,
                            failedDocuments: docsContent.failedDocuments,
                            totalCharacters: docsContent.totalCharacters
                        )
                    }
                    
                    HapticManager.shared.playGenerationComplete() // Generation completion haptic
                    self.transcript = TranscriptModel(
                        originalText: originalText,
                        goals: goals,
                        processedTranscript: podcastContent,
                        audioFileURL: nil,
                        mood: "reflective",
                        generationType: self.generationType,
                        googleDocsInfo: docsInfo,
                        isDeepResearch: true,
                        citations: citations,
                        researchQueries: [] // Could extract from research response
                    )
                    
                    // Debug logging for deep research transcript
                    print("🔍 DEBUG: Deep Research Transcript stored successfully")
                    print("🔍 DEBUG: podcastContent length: \(podcastContent.count)")
                    print("🔍 DEBUG: First 100 chars: \(String(podcastContent.prefix(100)))")
                    print("🔍 DEBUG: transcript property is nil: \(self.transcript == nil)")
                    print("🔍 DEBUG: processedTranscript is nil: \(self.transcript?.processedTranscript == nil)")
                    
                    self.isProcessing = false
                    self.processingStatus = ""
                    self.deepResearchProgress = ""
                    
                case .failure(let error):
                    print("❌ Podcast generation from research failed: \(error)")
                    self.handleError(error)
                    self.isProcessing = false
                    self.processingStatus = ""
                    self.deepResearchProgress = ""
                }
            }
        }
    }
    
    private func getFocusedPodcastPrompt(for generationType: GenerationType) -> String {
        let tone = generationType == .goodListener ? 
            "warm, motivating, occasionally challenging, and always deeply personal" : 
            "warm, clear, and unafraid to challenge. Noticing without judging. Encouraging without sugarcoating"
        
        return """
        You are creating a research-backed personal growth podcast episode based on scientific findings and expert insights.
        
        Your tone should be \(tone).
        
        CRITICAL REQUIREMENTS:
        - MAXIMUM 1,200 words total
        - Reference research naturally without being academic
        - Connect scientific findings to their personal patterns
        - Make evidence-based recommendations feel personal and actionable
        - Balance authority of research with empathy for their journey
        
        Create a complete podcast episode (1,000-1,200 words) that:
        
        **Introduction (200-300 words)**
        - Warmly acknowledge their reflections
        - Preview the research-backed insights you'll share
        - Set the tone that science supports their growth journey
        
        **Main Content (600-800 words)**
        - Weave research findings into personal insights
        - Explain how scientific findings apply to their specific situation
        - Use research to validate their experiences or provide new perspectives
        - Give evidence-based recommendations that feel personally relevant
        
        **Conclusion (200-300 words)**
        - Synthesize research insights with their personal goals
        - Provide specific, research-backed actions for the week ahead
        - End with encouragement rooted in scientific understanding
        
        The research should enhance rather than dominate the personal touch. Make it feel like a knowledgeable friend sharing discoveries, not a research presentation.
        """
    }
    
    private func generateWithOpenAI(text: String) {
        print("🤖 Starting OpenAI API call...")
        
        // Reset previous state
        errorMessage = nil
        transcript = nil
        
        // Extract goals from the input text
        let goals = text.components(separatedBy: "User's Goals:\n").last?
            .components(separatedBy: "\n\n").first?
            .components(separatedBy: ", ") ?? []
        
        print("📊 Extracted goals: \(goals)")
        print("🎭 Using generation type: \(generationType.displayName)")
        
        openAIService.generateTranscript(text: text, goals: goals, generationType: generationType) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let processedTranscript):
                    print("✅ OpenAI API call successful")
                    print("📝 Received transcript length: \(processedTranscript.count)")
                    
                    // Extract original text
                    let originalText = text.components(separatedBy: "User's Weekly Reflections:\n").last?
                        .components(separatedBy: "\n\n").first ?? ""
                    
                    self.processTranscriptWithSpeech(
                        text: originalText,
                        goals: goals,
                        transcript: processedTranscript
                    )
                case .failure(let error):
                    print("❌ OpenAI API call failed: \(error)")
                    HapticManager.shared.playErrorNotification() // Error feedback
                    self.handleError(error)
                }
                
                self.isProcessing = false
                self.processingStatus = ""
            }
        }
    }
    
    func generateTranscript(text: String, goals: [String]) {
        print("📝 Starting transcript generation...")
        print("Input text: \(text)")
        print("Goals: \(goals)")
        print("Dev mode: \(devMode), Mock API Calls: \(mockAPICalls)")
        
        isProcessing = true
        errorMessage = nil  // Reset error message
        
        // Initialize enhanced loading system
        initializeContentReferences(text: text, goals: goals)
        startRealisticProgress()
        
        processingStatus = "Starting generation..."
        
        // Use sample data only if BOTH dev mode AND mock API calls are enabled
        if devMode && mockAPICalls {
            print("🔧 Mock API Calls enabled: Using sample data (no real API calls)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self else { return }
                var sampleTranscript = TranscriptModel.sample
                sampleTranscript.audioFileURL = self.sampleAudioURL
                                        self.transcript = sampleTranscript
                        self.completeProgress()
                        self.isProcessing = false
                        self.processingStatus = ""
                print("✅ Mock transcript generated successfully")
            }
            return
        }
        
        print("🚀 Making real API calls to generate podcast...")
        
        // Start by fetching Google Docs content if connected
        fetchGoogleDocsContent { googleDocsContent in
            // Then fetch health data if enabled
            if self.healthKitEnabled {
                print("🏥 Health data enabled, fetching health summary...")
                DispatchQueue.main.async {
                    self.processingStatus = "Fetching health data..."
                }
                HealthKitManager.shared.fetchWeeklyHealthData { healthSummary in
                    // Update health data reference based on success
                    self.updateHealthDataReference(isIncluded: !healthSummary.isEmpty)
                    
                    // Combine all data sources
                    let combinedInput = self.buildCombinedInput(
                        userText: text,
                        goals: goals,
                        googleDocsContent: googleDocsContent,
                        healthSummary: healthSummary
                    )
                    
                    print("🔄 Generating transcript with health data and Google Docs...")
                    DispatchQueue.main.async {
                        self.processingStatus = "Generating AI insights..."
                    }
                    self.generateWithOpenAI(text: combinedInput)
                }
            } else {
                // Use original input without health data but with Google Docs
                let combinedInput = self.buildCombinedInput(
                    userText: text,
                    goals: goals,
                    googleDocsContent: googleDocsContent,
                    healthSummary: nil
                )
                
                print("🔄 Generating transcript with Google Docs...")
                DispatchQueue.main.async {
                    self.processingStatus = "Generating AI insights..."
                }
                self.generateWithOpenAI(text: combinedInput)
            }
        }
    }
    
    private func processTranscriptWithSpeech(text: String, goals: [String], transcript: String) {
        print("📝 Transcript processed. Length: \(transcript.count) characters")
        
        // Extract mood from transcript with more robust handling
        let mood = transcript.components(separatedBy: "\nMOOD:")
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()  // Ensure lowercase to match PodcastMood enum
        
        print("🎭 Extracted mood: \(mood ?? "nil")")
        
        // Validate mood is one of the expected values
        let validMoods = ["positive", "neutral", "reflective", "energetic", "calm", "mysterious", "happy", "melancholic"]
        let finalMood = mood.flatMap { validMoods.contains($0) ? $0 : nil }
        
        if finalMood == nil {
            print("⚠️ Invalid or missing mood value: \(mood ?? "nil"). Defaulting to neutral.")
        }
        
        // Remove the MOOD line from the transcript
        let cleanTranscript = transcript.components(separatedBy: "\nMOOD:").first ?? transcript
        
        // Convert GoogleDocsContent to GoogleDocsInfo for storage
        let docsInfo: GoogleDocsInfo? = self.googleDocsInfo.map { docsContent in
            GoogleDocsInfo(
                includedDocuments: docsContent.includedDocuments,
                failedDocuments: docsContent.failedDocuments,
                totalCharacters: docsContent.totalCharacters
            )
        }
        
        // Create transcript without audio first
        self.transcript = TranscriptModel(
            originalText: text,
            goals: goals,
            processedTranscript: cleanTranscript,
            audioFileURL: nil,
            mood: finalMood ?? "neutral",
            generationType: generationType,
            googleDocsInfo: docsInfo
        )
        
        // Debug logging
        print("🔍 DEBUG: Transcript stored successfully")
        print("🔍 DEBUG: processedTranscript length: \(cleanTranscript.count)")
        print("🔍 DEBUG: First 100 chars: \(String(cleanTranscript.prefix(100)))")
        
        // Skip audio generation if mock mode is on
        if devMode && mockAPICalls {
            print("🔧 Mock mode: Skipping audio generation")
            DispatchQueue.main.async {
                HapticManager.shared.playGenerationComplete()
                self.completeProgress()
                self.isProcessing = false
                self.processingStatus = ""
            }
            return
        }
        
        // Convert markdown to plain text for audio
        let plainText = convertToPlainText(cleanTranscript)
        print("🔊 Plain text for TTS: \(plainText.prefix(200))...")
        
        // In dev mode: Use Apple TTS to save ElevenLabs credits
        // In production: Use ElevenLabs for scheduled podcasts
        if devMode {
            print("🍎 Dev Mode: Using Apple TTS (saving ElevenLabs credits)")
            DispatchQueue.main.async {
                self.processingStatus = "Generating audio with Apple TTS..."
            }
            
            // Use Apple TTS directly in dev mode
            textToSpeechService.convertToSpeech(text: plainText) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    switch result {
                    case .success(let audioURL):
                        print("✅ Apple TTS audio generated successfully: \(audioURL.path)")
                        self.transcript?.audioFileURL = audioURL
                        
                        // Save the podcast to persistence
                        if let podcast = self.transcript {
                            self.savePodcast(podcast)
                        }
                        
                        HapticManager.shared.playGenerationComplete()
                        
                    case .failure(let error):
                        print("❌ Apple TTS failed: \(error.localizedDescription)")
                        print("⚠️ Transcript available without audio")
                        
                        // Still save the podcast (without audio)
                        if let podcast = self.transcript {
                            self.savePodcast(podcast)
                        }
                        
                        HapticManager.shared.playWarningNotification()
                    }
                    
                    self.completeProgress()
                    self.isProcessing = false
                    self.processingStatus = ""
                }
            }
        } else {
            // Production mode: Use ElevenLabs first, fallback to Apple TTS
            print("🔊 Production Mode: Starting audio generation with ElevenLabs...")
            DispatchQueue.main.async {
                self.processingStatus = "Generating audio with ElevenLabs..."
            }
            
            // Try ElevenLabs first
            elevenLabsService.generateSpeech(from: plainText) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let audioURL):
                    DispatchQueue.main.async {
                        print("✅ ElevenLabs audio generated successfully: \(audioURL.path)")
                        self.transcript?.audioFileURL = audioURL
                        
                        // Save the podcast to persistence
                        if let podcast = self.transcript {
                            self.savePodcast(podcast)
                        }
                        
                        HapticManager.shared.playGenerationComplete()
                        self.completeProgress()
                        self.isProcessing = false
                        self.processingStatus = ""
                    }
                    
                case .failure(let error):
                    print("❌ ElevenLabs failed: \(error.localizedDescription)")
                    print("🔄 Falling back to Apple Text-to-Speech...")
                    
                    DispatchQueue.main.async {
                        self.processingStatus = "Falling back to Apple TTS..."
                    }
                    
                    // Fallback to Apple's TTS
                    self.textToSpeechService.convertToSpeech(text: plainText) { [weak self] fallbackResult in
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            
                            switch fallbackResult {
                            case .success(let audioURL):
                                print("✅ Apple TTS audio generated successfully: \(audioURL.path)")
                                self.transcript?.audioFileURL = audioURL
                                
                                // Save the podcast to persistence
                                if let podcast = self.transcript {
                                    self.savePodcast(podcast)
                                }
                                
                                HapticManager.shared.playGenerationComplete()
                                
                            case .failure(let fallbackError):
                                print("❌ Apple TTS also failed: \(fallbackError.localizedDescription)")
                                print("⚠️ Transcript available without audio")
                                
                                // Still save the podcast (without audio)
                                if let podcast = self.transcript {
                                    self.savePodcast(podcast)
                                }
                                
                                HapticManager.shared.playWarningNotification()
                            }
                            
                            self.completeProgress()
                            self.isProcessing = false
                            self.processingStatus = ""
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Google Docs Integration
    
    private func fetchGoogleDocsContent(completion: @escaping (GoogleDocsContent) -> Void) {
        print("📄 Fetching Google Docs content...")
        
        // Check if Google Docs is enabled and connected
        guard googleDocsService.isConnected && googleDocsService.isGoogleDocsEnabled else {
            print("📄 Google Docs not enabled or not connected, skipping...")
            DispatchQueue.main.async {
                self.processingStatus = "Processing reflections..."
            }
            completion(GoogleDocsContent(
                includedDocuments: [],
                failedDocuments: [],
                contentText: "",
                totalCharacters: 0
            ))
            return
        }
        
        DispatchQueue.main.async {
            self.processingStatus = "Fetching Google Docs..."
        }
        
        // Fetch documents from last 2 weeks
        Task {
            do {
                let documents = try await googleDocsService.fetchLastTwoWeeksDocuments()
                print("📄 Found \(documents.count) documents from last 2 weeks")
                
                DispatchQueue.main.async {
                    if documents.isEmpty {
                        self.processingStatus = "No recent Google Docs found"
                    } else {
                        self.processingStatus = "Loading \(documents.count) Google Docs..."
                    }
                }
                
                // Fetch content for each document
                await fetchDocumentContents(documents: documents, completion: completion)
                
            } catch {
                print("❌ Failed to fetch Google Docs: \(error)")
                DispatchQueue.main.async {
                    self.processingStatus = "Google Docs unavailable, continuing..."
                }
                completion(GoogleDocsContent(
                    includedDocuments: [],
                    failedDocuments: [],
                    contentText: "",
                    totalCharacters: 0
                ))
            }
        }
    }
    
    private func fetchDocumentContents(documents: [GoogleDocsModel], completion: @escaping (GoogleDocsContent) -> Void) async {
        var includedDocuments: [String] = []
        var failedDocuments: [String] = []
        var allContent: [String] = []
        let maxContentLength = 8000 // Reserve space for other content in the prompt
        
        for document in documents {
            do {
                print("📄 Fetching content for: \(document.name)")
                let content = try await googleDocsService.fetchContentForDocument(document.id)
                
                // Truncate content if too long
                let truncatedContent = content.count > maxContentLength ? 
                    String(content.prefix(maxContentLength)) + "...[Content truncated]" : content
                
                allContent.append("## \(document.name)\n\n\(truncatedContent)")
                includedDocuments.append(document.name)
                
                // Track successful document inclusion
                self.addDocumentReference(document.name, isIncluded: true)
                
                print("✅ Successfully fetched content for: \(document.name) (\(content.count) characters)")
                
            } catch {
                print("❌ Failed to fetch content for: \(document.name) - \(error)")
                failedDocuments.append(document.name)
                allContent.append("## \(document.name)\n\n[Failed to load content: \(error.localizedDescription)]")
                
                // Track failed document inclusion
                self.addDocumentReference(document.name, isIncluded: false)
            }
        }
        
        let combinedContent = allContent.joined(separator: "\n\n")
        let result = GoogleDocsContent(
            includedDocuments: includedDocuments,
            failedDocuments: failedDocuments,
            contentText: combinedContent,
            totalCharacters: combinedContent.count
        )
        
        print("📄 Google Docs content summary:")
        print("   - Included documents: \(includedDocuments.count)")
        print("   - Failed documents: \(failedDocuments.count)")
        print("   - Total characters: \(result.totalCharacters)")
        
        DispatchQueue.main.async {
            self.googleDocsInfo = result
            completion(result)
        }
    }
    
    private func buildCombinedInput(userText: String, goals: [String], googleDocsContent: GoogleDocsContent, healthSummary: String?) -> String {
        var combinedInput = """
        User's Weekly Reflections:
        \(userText)
        
        User's Goals:
        \(goals.joined(separator: ", "))
        """
        
        // Add Google Docs content if available
        if !googleDocsContent.contentText.isEmpty {
            combinedInput += """
            
            
            Recent Google Docs Content:
            \(googleDocsContent.contentText)
            """
            
            // Add summary of what was included
            if !googleDocsContent.includedDocuments.isEmpty {
                combinedInput += """
                
                
                Included Documents: \(googleDocsContent.includedDocuments.joined(separator: ", "))
                """
            }
            
            if !googleDocsContent.failedDocuments.isEmpty {
                combinedInput += """
                
                
                Failed to Load: \(googleDocsContent.failedDocuments.joined(separator: ", "))
                """
            }
        }
        
        // Add health data if available
        if let healthSummary = healthSummary {
            combinedInput += """
            
            
            Health Data:
            \(healthSummary)
            """
        }
        
        // Add analysis instructions
        combinedInput += """
        
        
        Please analyze this data and provide insights about the user's week, including their reflections, progress towards goals, and health patterns. Format the response in markdown with clear sections. At the end, add a single line starting with "MOOD:" followed by one of these exact values: "positive", "neutral", "reflective", "energetic", "calm", "mysterious", "happy", or "melancholic" based on the overall tone of the reflections. Choose the mood that best matches the emotional tone and energy level of the reflections.
        """
        
        return combinedInput
    }
    
    // Convert markdown transcript to plain text for audio
    private func convertToPlainText(_ markdown: String) -> String {
        var plainText = markdown
        
        // Remove markdown headers (including any #)
        plainText = plainText.replacingOccurrences(of: #"(?m)^#+\s*.*$"#, with: "", options: .regularExpression)
        
        // Remove emoji characters
        plainText = plainText.replacingOccurrences(of: #"[\u{1F300}-\u{1F9FF}]"#, with: "", options: .regularExpression)
        
        // Remove bullet points and any markdown list formatting
        plainText = plainText.replacingOccurrences(of: #"(?m)^\s*[-*•]\s+"#, with: "", options: .regularExpression)
        plainText = plainText.replacingOccurrences(of: #"\n\s*[-*•]\s+"#, with: "\n", options: .regularExpression)
        
        // Remove any remaining markdown formatting
        plainText = plainText.replacingOccurrences(of: #"[_*`]+"#, with: "", options: .regularExpression)
        plainText = plainText.replacingOccurrences(of: #"\[\^?\d*\]"#, with: "", options: .regularExpression)
        plainText = plainText.replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        
        // Fix common formatting issues
        plainText = plainText.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)  // Normalize whitespace
        plainText = plainText.replacingOccurrences(of: #"\s*\n\s*"#, with: "\n", options: .regularExpression)  // Clean line breaks
        plainText = plainText.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)  // Limit consecutive newlines
        
        // Fix common speech artifacts
        plainText = plainText.replacingOccurrences(of: "'", with: "'")  // Smart quotes
        plainText = plainText.replacingOccurrences(of: #"""#, with: "\"")  // Opening smart quote
        plainText = plainText.replacingOccurrences(of: #"""#, with: "\"")  // Closing smart quote
        plainText = plainText.replacingOccurrences(of: "...", with: ".")  // Replace ellipsis
        plainText = plainText.replacingOccurrences(of: "--", with: "—")  // Em dash
        
        // Remove any remaining special characters that might affect speech
        plainText = plainText.replacingOccurrences(of: #"[|<>{}\\]"#, with: "", options: .regularExpression)
        
        // Trim whitespace and ensure proper spacing
        plainText = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add a period at the end if missing (helps with speech pacing)
        if !plainText.hasSuffix(".") && !plainText.hasSuffix("!") && !plainText.hasSuffix("?") {
            plainText += "."
        }
        
        return plainText
    }
    
    // New method for manual speech generation
    func generateSpeechForTranscript() {
        guard let transcript = transcript?.processedTranscript else {
            errorMessage = "No transcript available to generate speech."
            return
        }
        
        print("🔊 Processing transcript for speech. Length: \(transcript.count) characters")
        
        TextToSpeechService.shared.convertToSpeech(text: transcript) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let audioURL):
                    print("✅ Audio URL generated: \(audioURL)")
                    // Update the transcript with the new audio URL
                    self?.transcript?.audioFileURL = audioURL
                case .failure(let error):
                    print("❌ Text-to-Speech Error: \(error)")
                    self?.errorMessage = "Could not convert transcript to speech: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func generateSpeechWithElevenLabs(transcript: String) {
        isProcessing = true
        errorMessage = nil
        
        // Use sample audio only if BOTH dev mode AND mock API calls are enabled
        if devMode && mockAPICalls {
            print("🔧 Mock API Calls enabled: Using sample audio (no ElevenLabs call)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                if let audioURL = self.sampleAudioURL {
                    self.transcript?.audioFileURL = audioURL
                }
                self.isProcessing = false
            }
            return
        }
        
        print("🔊 Making real ElevenLabs API call for speech synthesis...")
        
        // Convert markdown to plain text for audio
        let plainText = convertToPlainText(transcript)
        
        elevenLabsService.generateSpeech(from: plainText) { [weak self] result in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                switch result {
                case .success(let audioURL):
                    // Update the existing transcript with the new audio URL
                    self?.transcript?.audioFileURL = audioURL
                    
                    // Optional: Automatically play the generated audio
                    do {
                        let audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
                        audioPlayer.play()
                    } catch {
                        self?.errorMessage = "Generated audio, but couldn't play: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    self?.errorMessage = "Audio generation failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Generate a simple audio file for development
    private func generateSampleAudioFile(at url: URL) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            let audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder.record(forDuration: 3.0) // Create a 3-second silent file
            audioRecorder.stop()
            
        } catch {
            print("Failed to create sample audio file: \(error)")
        }
    }
    
    private func handleError(_ error: Error) {
        print("❌ Error in transcript generation: \(error)")
        switch error {
        case OpenAIError.invalidKey:
            errorMessage = "Invalid API key. Please check your OpenAI API key configuration."
        case OpenAIError.networkError:
            errorMessage = "Network error. Please check your internet connection and try again."
        case OpenAIError.parseError:
            errorMessage = "Error processing the response. Please try again."
        case OpenAIError.apiError(let message):
            errorMessage = "API Error: \(message)"
        default:
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        progressTimer?.invalidate()
        isProcessing = false
        processingStatus = ""
    }
    
    // MARK: - Enhanced Loading System Methods
    
    private func initializeContentReferences(text: String, goals: [String]) {
        contentReferences = []
        currentProgress = 0.0
        loadingStartTime = Date()
        
        // Add user text reference
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contentReferences.append(ContentReference(
                type: .userText,
                name: "Your Reflections",
                isIncluded: true
            ))
        }
        
        // Add goals reference
        if !goals.isEmpty {
            let goalText = goals.count == 1 ? "1 Goal" : "\(goals.count) Goals"
            contentReferences.append(ContentReference(
                type: .goals,
                name: goalText,
                isIncluded: true
            ))
        }
        
        // Add health data reference (will be updated when fetched)
        if healthKitEnabled {
            contentReferences.append(ContentReference(
                type: .healthData,
                name: "Health Data",
                isIncluded: false // Will be updated when fetched
            ))
        }
    }
    
    private func addDocumentReference(_ documentName: String, isIncluded: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.contentReferences.append(ContentReference(
                type: .document(documentName),
                name: documentName,
                isIncluded: isIncluded
            ))
        }
    }
    
    private func updateHealthDataReference(isIncluded: Bool) {
        DispatchQueue.main.async { [weak self] in
            if let index = self?.contentReferences.firstIndex(where: { 
                if case .healthData = $0.type { return true }
                return false
            }) {
                self?.contentReferences[index] = ContentReference(
                    type: .healthData,
                    name: "Health Data",
                    isIncluded: isIncluded
                )
            }
        }
    }
    
    private func startRealisticProgress() {
        progressTimer?.invalidate()
        currentProgress = 0.0
        currentLoadingPhase = "Initializing..."
        
        // Start with a realistic progress curve
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self, self.isProcessing else {
                self?.progressTimer?.invalidate()
                return
            }
            
            let elapsed = Date().timeIntervalSince(self.loadingStartTime ?? Date())
            
            // Realistic progress curve that accelerates then slows down near the end
            let targetProgress = self.calculateRealisticProgress(elapsed: elapsed)
            
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.currentProgress = min(targetProgress, 0.95) // Never complete until API finishes
                    self.updateLoadingPhase(progress: self.currentProgress)
                }
            }
        }
    }
    
    private func calculateRealisticProgress(elapsed: TimeInterval) -> Double {
        // More realistic progress curve that hangs less at the end
        let baseProgress = 1 - exp(-elapsed / 12.0) // Exponential approach to 1
        
        // Add some variability and realistic pacing
        switch elapsed {
        case 0..<2: return baseProgress * 0.15 // Quick start: 0-15%
        case 2..<8: return 0.15 + (baseProgress - 0.15) * 0.5 // Steady progress: 15-65%
        case 8..<15: return 0.65 + (baseProgress - 0.65) * 0.25 // Slower: 65-85%
        default: return min(0.9, 0.85 + (baseProgress - 0.85) * 0.1) // Hang at 85-90%
        }
    }
    
    private func updateLoadingPhase(progress: Double) {
        switch progress {
        case 0..<0.2:
            currentLoadingPhase = "Analyzing your reflections..."
        case 0.2..<0.4:
            currentLoadingPhase = "Gathering insights..."
        case 0.4..<0.7:
            currentLoadingPhase = "Crafting your personalized podcast..."
        case 0.7..<0.9:
            currentLoadingPhase = "Generating audio content..."
        default:
            currentLoadingPhase = "Finalizing your reflection..."
        }
    }
    
    private func completeProgress() {
        progressTimer?.invalidate()
        DispatchQueue.main.async { [weak self] in
            withAnimation(.easeOut(duration: 0.8)) {
                self?.currentProgress = 1.0
                self?.currentLoadingPhase = "Complete!"
            }
        }
    }
}
