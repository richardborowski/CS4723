import SwiftUI

@main
struct SpeechtotextmlApp: App {
    
    @ObservedObject var modelManager: ModelManager

    init() {
        modelManager = ModelManager()
        let userID = getUniqueUserID()
        print("Unique User ID: \(userID)")
    }
    
    
    func getUniqueUserID() -> String {
        let key = "com.speechtotextml.uniqueUserID"

        if let existingID = Keychain.load(key: key) {
            return existingID
        } else {
            let newUUID = UUID().uuidString
            Keychain.save(key: key, data: newUUID)
            return newUUID
        }
    }
    
    var body: some Scene {
        WindowGroup {
            TabView {
                SpeechToTextView(modelManager: modelManager, userID: getUniqueUserID())
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
//                ContentView()
//                    .tabItem {
//                        Label("Model", systemImage: "app.fill")
//                    }
//                TokenizerTest()
//                    .tabItem {
//                        Label("Tokenizer Test", systemImage: "app.fill")
//                    }
                SpeechSessionsView(userID: getUniqueUserID())
                    .tabItem {
                        Label("Speech Sessions", systemImage: "list.bullet")
                    }
                TuneModelView(modelManager: modelManager, userID: getUniqueUserID())
                    .tabItem {
                        Label("Fine Tune Model", systemImage: "list.dash")
                    }
            }
        }
    }
}


