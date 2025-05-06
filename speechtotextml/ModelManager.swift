import Foundation
import CoreML

class ModelManager: ObservableObject {
    @Published var model: Model? = nil
    @Published var modelPath: String? = nil
    @Published var isUsingCustomModel: Bool = UserDefaults.standard.bool(forKey: "isUsingCustomModel")
    
    init() {
    }

    func resetModel() {
        self.model = nil
        self.modelPath = nil
        self.isUsingCustomModel = false
        UserDefaults.standard.set(false, forKey: "isUsingCustomModel")
    }

    func loadModel() async throws {
        do {
            if isUsingCustomModel {
                if let modelPath = UserDefaults.standard.string(forKey: "customModelPath") {
                    
                    let mlpackageURL = URL(fileURLWithPath: modelPath)

                    await MainActor.run {
                        self.model = try? Model(contentsOf: mlpackageURL)
                        self.modelPath = mlpackageURL.path
                        self.isUsingCustomModel = true
                    }
                    print("Custom model loaded from \(modelPath)")
                    UserDefaults.standard.set(true, forKey: "isUsingCustomModel")
                } else {
                    print("No custom model found. Loading default model instead.")
                    await MainActor.run {
                        self.model = try! Model(configuration: MLModelConfiguration())
                        self.isUsingCustomModel = false

                    }
                    UserDefaults.standard.set(false, forKey: "isUsingCustomModel")
                }
            } else {
                print("Loading default model")
                await MainActor.run {
                    self.model = try! Model(configuration: MLModelConfiguration())
                    self.isUsingCustomModel = false

                }


                UserDefaults.standard.set(false, forKey: "isUsingCustomModel")
            }
        } catch {
            print("Failed to load model: \(error.localizedDescription)")
            await MainActor.run {
                self.model = try! Model(configuration: MLModelConfiguration())
                self.isUsingCustomModel = false
            }
            UserDefaults.standard.set(false, forKey: "isUsingCustomModel")
        }
    }

    func toggleModel() {
        isUsingCustomModel.toggle()
        
        UserDefaults.standard.set(isUsingCustomModel, forKey: "isUsingCustomModel")
        
        Task {
            await MainActor.run {
                self.model = nil
            }
            do {
                try await loadModel()
            } catch {
                print("Failed to load model after switching: \(error.localizedDescription)")
                await MainActor.run {
                    self.model = nil
                }
            }
        }
    }
}
