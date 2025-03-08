import SwiftUI

struct TokenizerTest: View {
    @State private var inputText: String = ""
    @State private var encodedText: [Int] = []
    @State private var decodedText: String = ""
    @State private var resultText: String = ""
    @State private var inputTokens: String = ""
    @State private var tokenizerWrapper = TokenizerWrapper()

    var body: some View {
        VStack {
            Text("Tokenizer Test")
                .font(.largeTitle)
                .padding()
            
            TextField("Enter text to tokenize", text: $inputText)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Encode Text") {
                Task {
                    do {
                        encodedText = try await tokenizerWrapper.encode(text: inputText)
                        resultText = "Text encoded successfully!"
                    } catch {
                        resultText = "Error encoding text: \(error.localizedDescription)"
                    }
                }
            }
            .padding()
            .buttonStyle(.borderedProminent)
            
            Text("Encoded Tokens: \(encodedText.description)")
                .padding()
            
            TextField("Enter encoded tokens (space-separated)", text: $inputTokens)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Decode Text") {
                Task {
                    do {
                        let tokens = inputTokens.split(separator: " ").compactMap { Int($0) }
                        
                        decodedText = tokenizerWrapper.decode(tokens: tokens)
                        resultText = "Text decoded successfully!"
                    } catch {
                        resultText = "Error decoding text: \(error.localizedDescription)"
                    }
                }
            }
            .padding()
            .buttonStyle(.borderedProminent)
            
            Text("Decoded Text: \(decodedText)")
                .padding()
            
            Text(resultText)
                .padding()
                .foregroundColor(.green)
        }
        .onAppear {
            Task {
                do {
                    try await tokenizerWrapper.initialize()
                    resultText = "Tokenizer initialized successfully!"
                } catch {
                    resultText = "Error initializing tokenizer: \(error.localizedDescription)"
                }
            }
        }
    }
}
