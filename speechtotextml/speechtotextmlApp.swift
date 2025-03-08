import SwiftUI

@main
struct SpeechtotextmlApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                SpeechToTextView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                ContentView()
                    .tabItem {
                        Label("Model", systemImage: "app.fill")
                    }
                TokenizerTest()
                    .tabItem {
                        Label("Tokenizer Test", systemImage: "app.fill")
                    }
            }
        }
    }
}


