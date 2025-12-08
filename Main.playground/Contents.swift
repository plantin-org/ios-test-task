import UIKit

// MARK: - ImageFetcher
protocol ImageFetcher: Sendable {
    func fetchImage(from url: URL) async -> UIImage?
}

// MARK: - Validation
class Validator {
    struct ValidateRequest: Codable, Sendable {
        let imageIds: Set<String>
    }
    
    struct ValidateResponse: Codable, Sendable {
        let success: Bool
        let violations: [Violation]?
    }
    
    struct Violation: Codable, Sendable {
        let imageId: String
        let reason: String
        let totalRequests: Int
        let success: Int
        let failed: Int
    }
    
    private let url = "https:/test-tasks.myplantin.com"
    
    func validate(using fetcher: ImageFetcher) async {
        await reset()
        
        var imageIds: Set<String> = []
        let sessionToken = UUID().uuidString
        let iterations = 1000
        let maxImageId = 100
        let images = await withTaskGroup(of: UIImage?.self) { group in
            for _ in 0...iterations {
                let imageId = "image_\(Int.random(in: 1...maxImageId))"
                imageIds.insert(imageId)
                let url = URL(string: "\(url)/test-tasks/get-image/\(imageId).png?session-token=\(sessionToken)")!
                group.addTask {
                    await fetcher.fetchImage(from: url)
                }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }

        let validateURL = URL(string: "\(url)/test-tasks/validate?session-token=\(sessionToken)")!
        var request = URLRequest(url: validateURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = ValidateRequest(imageIds: imageIds)
        request.httpBody = try! JSONEncoder().encode(requestBody)

        let (data, _) = try! await URLSession.shared.data(for: request)
        let response = try! JSONDecoder().decode(ValidateResponse.self, from: data)

        if response.success {
            print("✅ Success!")
        } else if let violations = response.violations {
            print("❌ Failed with violations:")
            for violation in violations {
                print(violation)
            }
        }
    }
    
    func reset() async {
        let validateURL = URL(string: "\(url)/test-tasks/clear")!
        var request = URLRequest(url: validateURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (_, _) = try! await URLSession.shared.data(for: request)
    }

}

//Mark: - Main
Task {
    let start = Date().timeIntervalSince1970
    let validator = Validator()
//    await validator.validate(using: SimpleImageFetcher()) TODO: uncomment and provide implementation for image fetcher
    let end = Date().timeIntervalSince1970
    print("Total time: \(end - start) seconds")
}
