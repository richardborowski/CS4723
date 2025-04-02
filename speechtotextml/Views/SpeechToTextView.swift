import SwiftUI
import AVFoundation
import Speech
import CoreML

struct SpeechToTextView: View {

    @State private var text = ""
    @State private var isRecording = false
    @State private var startButtonEnabled = true
    
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var audioEngine: AVAudioEngine!
    private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    @State private var inputText: String = ""
    @State private var paddedTokens: [Int] = []
    @State private var attentionMask: [Int] = []
    @State private var resultText: String = ""
    @State private var len: Int = 0
    @State private var outputTokens: [String] = []
    @State private var tokenizerWrapper = TokenizerWrapper()
    
    @Binding var wordCountDictionary: [String: Int]

    var coreMLModel: Model!

    init(wordCountDictionary: Binding<[String: Int]>) {
        audioEngine = AVAudioEngine()
        _wordCountDictionary = wordCountDictionary
    }

    var body: some View {
        VStack {
            Text(text)
                .font(.title)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.black)
            
            // List takes up available space by using .frame(maxHeight: .infinity)
            List(outputTokens, id: \.self) { token in
                Text(token)
                    .padding()
            }
            .frame(maxHeight: .infinity)  // Ensure the list takes the available height
            
            Button(action: startButtonPressed) {
                Text(isRecording ? "Stop" : "Start")
                    .font(.title2)
                    .padding()
                    .background(isRecording ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!startButtonEnabled)
            .padding()
        }
        .frame(maxHeight: .infinity)  // Ensure VStack takes full height
        .onAppear {
            requestPermissions()
        }
    }

    private func startButtonPressed() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.startButtonEnabled = true
                case .denied, .restricted, .notDetermined:
                    self.startButtonEnabled = false
                    self.text = "Speech recognition is not authorized."
                @unknown default:
                    break
                }
            }
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { isGranted in
            DispatchQueue.main.async {
                if !isGranted {
                    self.text = "Microphone access is denied."
                }
            }
        }
    }

    private func startRecording() {
        Task {
            guard let recognizer = speechRecognizer, recognizer.isAvailable else {
                self.text = "Speech recognizer is not available."
                return
            }
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            recognitionRequest?.shouldReportPartialResults = true
            
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest!, resultHandler: { result, error in
                if let result = result {
                    let inputText = result.bestTranscription.formattedString
                    
                    let words = inputText.split { $0 == " " }.map { String($0) }
                    if let lastWord = words.last {
                        self.updateWordCounts(word: lastWord)
                    }

                    
                    let last100Words = words.suffix(30)
                    let resultText = last100Words.joined(separator: " ")
                    
                    self.text = resultText
                }
                
                if let error = error {
                    self.text = "Error: \(error.localizedDescription)"
                    self.stopRecording()
                }
            })
            
            inputNode.removeTap(onBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, time) in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try? audioEngine.start()
            
            self.text = "Listening..."
            self.isRecording = true
            
            while self.isRecording{
                let input_text = self.text
                
                await self.processAndRunModel(input_text: input_text)
                await Task.sleep(2 * 1_000_000_000)
                    
            }
        }
    }
    
    
    private func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        self.isRecording = false
        self.text = ""
        
        saveWordCounts() // Save word count dictionary to UserDefaults
    }

    private func updateWordCounts(word: String) {
        if let count = wordCountDictionary[word] {
            wordCountDictionary[word] = count + 1
        } else {
            wordCountDictionary[word] = 1
        }
        saveWordCounts()
    }


    private func loadWordCounts() {
        if let savedWordCounts = UserDefaults.standard.object(forKey: "wordCounts") as? [String: Int] {
            wordCountDictionary = savedWordCounts
        }
    }

    private func saveWordCounts() {
        UserDefaults.standard.set(wordCountDictionary, forKey: "wordCounts")
    }
    
    private func processAndRunModel(input_text: String) async {
            do {
                if tokenizerWrapper.tokenizer == nil {
                    try await tokenizerWrapper.initialize()
                }
                (paddedTokens, attentionMask, len) = try await tokenizerWrapper.padTokensAndMask(text: input_text)
                resultText = "Text encoded and attention mask created!"
                
                try await runModel(paddedTokens: paddedTokens, attentionMask: attentionMask, size: len)
            } catch {
                resultText = "Error: \(error.localizedDescription)"
                print("Error: \(error.localizedDescription)")
            }
        }
    
    func runModel(paddedTokens: [Int], attentionMask: [Int], size: Int) async throws {
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
        var lastTokenLogits: [Float] = []
        if let logits = output.featureValue(for: "logits")?.multiArrayValue {
            let vocabSize = logits.shape[2].intValue  // Vocabulary size (e.g., 50257 for GPT-based models)

    
            for i in 0..<vocabSize {
                let index = (size - 1) * vocabSize + i  // Compute index for last token
                lastTokenLogits.append(logits[index].floatValue)
            }

        }
    
        let smLogits = softmax(logits: lastTokenLogits)
        print("Softmax of last token:", smLogits)
        let num = 30
        var topNLTokens = getTopNIndices(probabilities: logitsArray, n: num)
        var topTokens = getTopNIndices(probabilities: smLogits, n: num)
    
        self.outputTokens.removeAll()
        for i in 0..<num {
            let token = topTokens[i]
            self.outputTokens.append(tokenizerWrapper.decode(tokens: [token]))
        }
        
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

