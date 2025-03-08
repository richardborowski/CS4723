//
//  ContentView.swift
//  speechtotextml
//
//  Created by Richard Borowski on 3/6/25.
//

import SwiftUI
import CoreML

struct ContentView: View {
    @State private var inputText: String = ""
    @State private var paddedTokens: [Int] = []
    @State private var attentionMask: [Int] = []
    @State private var resultText: String = ""
    @State private var tokenizerWrapper = TokenizerWrapper()
    
    var coreMLModel: Model!

    var body: some View {
        VStack {
            Text("Tokenizer and CoreML Inference")
                .font(.largeTitle)
                .padding()
            
            TextField("Enter text to encode", text: $inputText)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Process and Encode") {
                Task {
                    do {
                        if tokenizerWrapper.tokenizer == nil {
                            try await tokenizerWrapper.initialize()
                        }
                        
                        (paddedTokens, attentionMask) = try await tokenizerWrapper.padTokensAndMask(text: inputText)
                        resultText = "Text encoded and attention mask created!"
                        
                        try await runModel(paddedTokens: paddedTokens, attentionMask: attentionMask)
                    } catch {
                        resultText = "Error: \(error.localizedDescription)"
                        print("Error: \(error.localizedDescription)")
                    }
                }
            }
            .padding()
            .buttonStyle(.borderedProminent)
            
            Text("Padded Tokens: \(paddedTokens.description)")
                .padding()
            
            Text("Attention Mask: \(attentionMask.description)")
                .padding()
            
            Text(resultText)
                .padding()
                .foregroundColor(.green)
        }
    }

    func runModel(paddedTokens: [Int], attentionMask: [Int]) async throws {
        guard let model = try? Model(configuration: MLModelConfiguration()) else {
            throw NSError(domain: "CoreMLModelError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model loading failed."])
        }
        
        let inputTokens = try MLMultiArray(shape: [1, 128] as [NSNumber], dataType: .int32)
        for (index, token) in paddedTokens.prefix(128).enumerated() {
            inputTokens[index] = NSNumber(value: token)
        }
        let inputMask = try MLMultiArray(shape: [1, 128] as [NSNumber], dataType: .int32)
        for (index, mask) in attentionMask.prefix(128).enumerated() {
            inputMask[index] = NSNumber(value: mask)
        }
        
        let output = try model.prediction(input_ids: inputTokens, attention_mask: inputMask)
        
        var logitsArray: [Float] = []
        if let logits = output.featureValue(for: "logits")?.multiArrayValue {
            let shape = logits.shape

            for i in 0..<50257 {
                let tokenLogit = logits[i].floatValue
                logitsArray.append(tokenLogit)
            }
        }
    
        var smLogits = softmax(logits: logitsArray)
        var topNLTokens = getTopNIndices(probabilities: logitsArray, n: 10)
        var topTokens = getTopNIndices(probabilities: smLogits, n: 10)
    
        var stdTokens: [String] = []
        for i in 0..<10 {
            let token = topTokens[i]
            stdTokens.append(tokenizerWrapper.decode(tokens: [token]))
        }
        
        print("test: test")
        print("test: test")
        print("test: test")
        print("test: test")
        print("test: test")
        

        
        
    }
    
    func softmax(logits: [Float]) -> [Float] {
        let maxLogit = logits.max() ?? 0.0
        let exponentiated = logits.map { exp($0 - maxLogit) }
        let sum = exponentiated.reduce(0, +)
        return exponentiated.map { $0 / sum }
    }
    
    
    func getTopNIndices(probabilities: [Float], n: Int) -> [Int] {
        let sortedIndices = probabilities.enumerated()
            .sorted { $0.element > $1.element }
        let topNIndices = sortedIndices.prefix(n).map { $0.offset }
        
        return topNIndices
    }
}
