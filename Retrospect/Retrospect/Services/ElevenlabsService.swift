import Foundation
import Combine

class ElevenLabsService {
    /// Legacy on-device TTS. As of the v2 migration the iOS app does NOT ship
    /// an ElevenLabs key. The weekly podcast renders TTS server-side, and the
    /// "play my reflection out loud" feature should be migrated to a backend
    /// endpoint in a follow-up. For now, on-device TTS is disabled unless the
    /// caller explicitly configures a key via `configure(apiKey:voiceID:)`.
    static let shared = ElevenLabsService()
    
    private var apiKey: String
    private var voiceID: String
    private let baseURL = "https://api.elevenlabs.io/v1"
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // No hardcoded key. Callers must use `configure(apiKey:voiceID:)` or
        // route TTS through the backend.
        self.apiKey = ""
        self.voiceID = "21m00Tcm4TlvDq8ikWAM" // Default voice (Rachel)
    }
    
    func generateSpeech(from text: String, completion: @escaping (Result<URL, Error>) -> Void) {
        print("🔊 DEBUG: Starting ElevenLabs speech generation")
        print("🔊 DEBUG: Text length: \(text.count) characters")
        print("🔊 DEBUG: API Key exists: \(!apiKey.isEmpty)")
        print("🔊 DEBUG: Voice ID: \(voiceID)")
        
        guard let url = URL(string: "\(baseURL)/text-to-speech/\(voiceID)") else {
            print("❌ DEBUG: Invalid URL construction")
            completion(.failure(NSError(domain: "ElevenLabsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        print("🔊 DEBUG: Request URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        // Add timeout configuration to fix timeout errors
        request.timeoutInterval = 60.0 // Increase timeout to 60 seconds
        
        let parameters: [String: Any] = [
            "text": text,
            "model_id": "eleven_v3",  // Updated to Eleven v3 (alpha) - most emotionally rich, expressive model with 5,000 character limit
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            completion(.failure(error))
            return
        }
        
        // Create URLSession with custom configuration for better timeout handling
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        let session = URLSession(configuration: config)
        
        session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                // Log detailed response information
                print("🌐 Response Status Code: \(httpResponse.statusCode)")
                print("🌐 Response Headers: \(httpResponse.allHeaderFields)")
                
                // Check for specific error status codes
                if !(200...299).contains(httpResponse.statusCode) {
                    // Try to parse error response
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("❌ Error Response: \(errorString)")
                        throw NSError(domain: "ElevenLabsService",
                                      code: httpResponse.statusCode,
                                      userInfo: [NSLocalizedDescriptionKey: errorString])
                    }
                    throw URLError(.badServerResponse)
                }
                
                return data
            }
            .tryMap { audioData -> URL in
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = documentsDirectory.appendingPathComponent("reflection_\(Date().timeIntervalSince1970).mp3")
                try audioData.write(to: fileURL)
                return fileURL
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completionResult in
                switch completionResult {
                case .failure(let error):
                    print("❌ Eleven Labs API Error: \(error)")
                    completion(.failure(error))
                case .finished:
                    break
                }
            }, receiveValue: { fileURL in
                completion(.success(fileURL))
            })
            .store(in: &cancellables)
    }
    
    // Optional: Method to set custom voice and API key
    func configure(apiKey: String, voiceID: String? = nil) {
        // Now can modify properties
        self.apiKey = apiKey
        if let voiceID = voiceID {
            self.voiceID = voiceID
        }
    }
}

// Error type for more specific error handling
enum ElevenLabsError: Error {
    case invalidAPIKey
    case networkError
    case audioGenerationFailed
}
