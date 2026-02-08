import Foundation

// MARK: - Citation Model
struct Citation: Codable {
    let title: String
    let url: String
    let startIndex: Int
    let endIndex: Int
}

// MARK: - Generation Types
enum GenerationType: String, CaseIterable, Codable {
    case goodListener = "good_listener"
    case growthMentor = "growth_mentor"
    
    var displayName: String {
        switch self {
        case .goodListener:
            return "Good Listener"
        case .growthMentor:
            return "Growth Mentor"
        }
    }
    
    var description: String {
        switch self {
        case .goodListener:
            return "Supportive and encouraging, highlights your achievements and progress"
        case .growthMentor:
            return "Provides constructive feedback and actionable advice for improvement"
        }
    }
}

struct TranscriptModel: Identifiable, Equatable, Codable {
    let id: UUID
    let originalText: String
    let goals: [String]
    var processedTranscript: String?
    var audioFileURL: URL?
    var mood: String? // Can be: "Positive", "Neutral", or "Reflective"
    var generationType: GenerationType? // Track which generation type was used
    var googleDocsInfo: GoogleDocsInfo? // Track which Google Docs were included
    var isDeepResearch: Bool = false // Track if Supercharge mode was used
    var citations: [Citation]? // Citations from Supercharge mode
    var researchQueries: [String]? // Queries used during research
    var createdAt: Date = Date() // When the transcript was generated
    var backendEpisodeId: String? // UUID from backend if this came from server
    var insightIds: [String]? // Backend insight IDs associated with this episode
    
    // Equatable conformance - compare by ID for onChange detection
    static func == (lhs: TranscriptModel, rhs: TranscriptModel) -> Bool {
        lhs.id == rhs.id && lhs.createdAt == rhs.createdAt
    }
    
    init(
        id: UUID = UUID(),
        originalText: String,
        goals: [String],
        processedTranscript: String? = nil,
        audioFileURL: URL? = nil,
        mood: String? = nil,
        generationType: GenerationType? = nil,
        googleDocsInfo: GoogleDocsInfo? = nil,
        isDeepResearch: Bool = false,
        citations: [Citation]? = nil,
        researchQueries: [String]? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.originalText = originalText
        self.goals = goals
        self.processedTranscript = processedTranscript
        self.audioFileURL = audioFileURL
        self.mood = mood
        self.generationType = generationType
        self.googleDocsInfo = googleDocsInfo
        self.isDeepResearch = isDeepResearch
        self.citations = citations
        self.researchQueries = researchQueries
        self.createdAt = createdAt
    }
    
    // Sample data for development
    static let sample = TranscriptModel(
        originalText: "This week was quite productive. I managed to complete most of my tasks and started a new project. I've been feeling more energetic since starting my morning routine. However, I still struggle with work-life balance.",
        goals: ["Improve work-life balance", "Exercise 3 times a week", "Read more books"],
        processedTranscript: """
        # Weekly Overview
        Your week showed significant progress in several areas, particularly in productivity and personal development. The implementation of your morning routine has yielded positive results in your energy levels.

        # Achievements
        - Successfully completed majority of planned tasks
        - Initiated a new project
        - Maintained consistent morning routine
        - Increased energy levels observed

        # Areas for Growth
        The main challenge identified is work-life balance. This aligns with your primary goal and deserves focused attention in the coming week.

        # Progress on Goals
        1. Work-Life Balance
           - Currently a challenge area
           - Opportunity to implement structured boundaries
           - Consider scheduling dedicated personal time

        2. Exercise Routine
           - Not specifically mentioned in reflections
           - Can be integrated into morning routine
           - Recommend starting with morning walks

        3. Reading Habit
           - No specific mention of reading progress
           - Suggest allocating evening time for reading
           - Start with 15-minute daily sessions

        # Recommendations
        1. Set specific work hours and stick to them
        2. Schedule breaks throughout the day
        3. Integrate exercise into your morning routine
        4. Designate evening time for reading and relaxation
        5. Continue with the effective morning routine

        # Focus for Next Week
        Priority should be establishing clear work-life boundaries while maintaining the positive momentum from your morning routine.
        """,
        audioFileURL: nil,
        mood: "Positive",
        generationType: .goodListener,
        googleDocsInfo: nil,
        isDeepResearch: false,
        citations: nil,
        researchQueries: nil
    )
    
            // Supercharge mode sample for development
    static let deepResearchSample = TranscriptModel(
        originalText: "This week I've been struggling with procrastination and finding it hard to stick to my exercise routine. I keep putting off important tasks until the last minute.",
        goals: ["Overcome procrastination", "Exercise 4 times a week", "Improve time management"],
        processedTranscript: """
        # Research-Backed Insights for Your Growth Journey

        ## Welcome
        This week, I want to share some fascinating research that directly relates to your experiences with procrastination and exercise consistency. What you're going through is deeply understood by behavioral science, and there are proven strategies that can help.

        ## The Science Behind Your Patterns
        Recent studies in behavioral psychology show that procrastination often stems from what researchers call "temporal discounting" - our brains literally value immediate rewards more highly than future ones. Dr. Tim Pychyl's research at Carleton University found that procrastination is essentially emotion regulation, not time management.

        Your struggle with exercise consistency aligns with research from the American College of Sports Medicine showing that 67% of people abandon new exercise routines within the first month. However, studies also reveal specific strategies that dramatically improve success rates.

        ## Evidence-Based Strategies for You
        Based on your patterns, here are research-backed approaches:

        **For Procrastination:**
        - Implementation intentions: Studies show that people who use "if-then" planning are 2-3 times more likely to follow through
        - The 2-minute rule: Research by behavioral economist Dan Ariely shows that starting with just 2 minutes reduces the emotional resistance that triggers procrastination

        **For Exercise Consistency:**
        - Habit stacking: Research by Dr. BJ Fogg at Stanford shows that linking new behaviors to existing routines increases success by 40%
        - Social accountability: Studies demonstrate that having a workout partner increases adherence by 95%

        ## Your Personal Action Plan
        This week, try implementing these research-backed strategies:
        1. Use implementation intentions: "If it's 7 AM, then I will put on my workout clothes"
        2. Apply the 2-minute rule: Just commit to 2 minutes of movement each day
        3. Create environmental cues: Research shows that laying out workout clothes increases exercise likelihood by 35%

        The science is clear: you're not lacking willpower, you're navigating predictable psychological patterns that can be strategically addressed.
        """,
        audioFileURL: nil,
        mood: "Reflective",
        generationType: .growthMentor,
        googleDocsInfo: nil,
        isDeepResearch: true,
        citations: [
            Citation(
                title: "The Procrastination Equation: How to Stop Putting Things Off and Start Getting Stuff Done",
                url: "https://www.psychologytoday.com/us/blog/dont-delay/research-procrastination",
                startIndex: 234,
                endIndex: 298
            ),
            Citation(
                title: "Exercise Adherence and Dropout Patterns: A Meta-Analysis",
                url: "https://www.acsm.org/docs/default-source/files-for-resource-library/exercise-adherence.pdf",
                startIndex: 456,
                endIndex: 523
            )
        ],
        researchQueries: [
            "procrastination behavioral psychology research",
            "exercise adherence strategies scientific studies",
            "habit formation implementation intentions"
        ]
    )
}

// MARK: - Google Docs Info for TranscriptModel
struct GoogleDocsInfo: Codable {
    let includedDocuments: [String]
    let failedDocuments: [String]
    let totalCharacters: Int
}
