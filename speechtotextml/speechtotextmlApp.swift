import SwiftUI

@main
struct SpeechtotextmlApp: App {

    init() {
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
                SpeechToTextView(userID: getUniqueUserID())
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
                TuneModelView(userID: getUniqueUserID())
                    .tabItem {
                        Label("Fine Tune Model", systemImage: "list.dash")
                    }
            }
        }
    }
}


