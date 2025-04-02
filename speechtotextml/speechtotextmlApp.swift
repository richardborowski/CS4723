import SwiftUI

@main
struct SpeechtotextmlApp: App {
    @State private var wordCountDictionary: [String: Int] = [:]

    
    var body: some Scene {
        WindowGroup {
            TabView {
                SpeechToTextView(wordCountDictionary: $wordCountDictionary)
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
                WordCountView(wordCountDictionary: $wordCountDictionary)
                    .tabItem {
                        Label("Word Count", systemImage: "list.dash")
                    }
            }
        }
    }
}


