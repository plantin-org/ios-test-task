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
    
    actor ProgressTracker {
        var latestIteration: Int
        let totalIterations: Int
        
        init(latestIteration: Int, totalIterations: Int) {
            self.latestIteration = latestIteration
            self.totalIterations = totalIterations
        }
        
        func reportIteration(iter: Int) {
            let latest = self.latestIteration
            let newLatest = max(iter, latest)
            if newLatest != latest {
                self.latestIteration = newLatest
                let progressPercentage = Double(latestIteration) / Double(totalIterations) * 100
                print("Progress: \(Int(progressPercentage.rounded(.up)))%")
                if progressPercentage > 99.9 {
                    print("Wrapping up...")
                }
            }
        }
    }
    
    private let url = "https:/test-tasks.myplantin.com"
    
    func validate(using fetcher: ImageFetcher) async {
        await reset()
        
        var imageIds: Set<String> = []
        let sessionToken = UUID().uuidString
        let iterations = 100
        let maxImageId = 10
        print("Starting validation")
        
        let tracker = ProgressTracker(latestIteration: 0, totalIterations: iterations)

        let images = await withTaskGroup(of: UIImage?.self) { group in
            for i in 0...iterations {
                let imageId = "image_\(Int.random(in: 1...maxImageId))"
                imageIds.insert(imageId)
                let url = URL(string: "\(url)/test-tasks/get-image/\(imageId).png?session-token=\(sessionToken)")!
                group.addTask {
                    let image = await fetcher.fetchImage(from: url)
                    await tracker.reportIteration(iter: i)
                    return image
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
            print("❌ Validation not passed. See validation errors below:")
            for violation in violations {
                print(violation)
            }
            print("❌ Validation not passed. See validation errors above")
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
//    await validator.validate(using: SimpleImageFetcher())
    let end = Date().timeIntervalSince1970
    print("Total time: \(end - start) seconds")
}
