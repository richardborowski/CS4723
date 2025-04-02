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

    @State private var model: Model?
    
    @State private var totalElapsedTime: TimeInterval = 0
    @State private var intervalCount: Int = 0
    @State private var averageElapsedTime: String = "0.00 s"
    @State private var startTime: Date?
    
    init(wordCountDictionary: Binding<[String: Int]>) {
        audioEngine = AVAudioEngine()
        _wordCountDictionary = wordCountDictionary
    }

    var body: some View {
        VStack {
            GeometryReader { geometry in
                VStack {
                    HStack {
                        Spacer()
                        Text("MT: \(averageElapsedTime)")
                            .font(.system(size: 10))
                            .padding(.top, 2)
                            .padding(.trailing, 5)
                    }

                    Text(text)
                        .font(.title)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.black)
                        .frame(minHeight: 100)

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16)], spacing: 16) {
                            ForEach(outputTokens, id: \.self) { token in
                                Text(token)
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .padding(12)
                                    .background(Color.blue.opacity(0.3))
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(Color.blue.opacity(0.6), lineWidth: 2)
                                    )
                                    .shadow(radius: 5)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        .padding(.horizontal)
                        .id(outputTokens)
                    }
                    .frame(maxHeight: .infinity)

                    Spacer()

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
            }
            .onAppear {
                requestPermissions()
            }
        }
        .frame(maxHeight: .infinity)
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
                DispatchQueue.main.async {
                    if let result = result {
                        let inputText = result.bestTranscription.formattedString

                        let words = inputText.split { $0 == " " }.map { String($0) }
                        if let lastWord = words.last {
                            self.updateWordCounts(word: lastWord)
                        }

                        let last100Words = words.suffix(18)
                        let resultText = last100Words.joined(separator: " ")

                        self.text = resultText
                    }

                    if let error = error {
                        self.text = "Error: \(error.localizedDescription)"
                        self.stopRecording()
                    }
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
            
            try? loadModel()
            
            while self.isRecording {
                await self.processAndRunModel(input_text: self.text)

                try? await Task.sleep(nanoseconds: 1_000_000_000)

                if let startTime = self.startTime {
                    let endTime = Date()
                    let timeInterval = endTime.timeIntervalSince(startTime)
                    
                    totalElapsedTime += timeInterval
                    intervalCount += 1
                    
                    let averageTime = totalElapsedTime / Double(intervalCount)
                    self.averageElapsedTime = String(format: "%.2f s", averageTime)
                    
                    self.startTime = Date()
                }
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
        
        saveWordCounts()
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

    private func loadModel() throws {
        if model == nil {
            model = try Model(configuration: MLModelConfiguration())
        }
    }
    
    private func resetTimer() {
        self.startTime = Date()
    }

    private func processAndRunModel(input_text: String) async {
        self.resetTimer()

        do {
            if tokenizerWrapper.tokenizer == nil {
                try await tokenizerWrapper.initialize()
            }
            
            let (paddedTokens, attentionMask, len) = try await tokenizerWrapper.padTokensAndMask(text: input_text)

            resultText = "Text encoded and attention mask created!"
            
            try await runModel(paddedTokens: paddedTokens, attentionMask: attentionMask, size: len)
        } catch {
            resultText = "Error: \(error.localizedDescription)"
            print("Error: \(error.localizedDescription)")
        }
    }

    func runModel(paddedTokens: [Int], attentionMask: [Int], size: Int) async throws {
        guard let model = model else {
            throw NSError(domain: "CoreMLModelError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model loading failed."])
        }

        let inputTokens = try MLMultiArray(shape: [1, 128] as [NSNumber], dataType: .int32)
        let inputMask = try MLMultiArray(shape: [1, 128] as [NSNumber], dataType: .int32)
        
        async let tokenProcessing = Task {
            for (index, token) in paddedTokens.prefix(128).enumerated() {
                inputTokens[index] = NSNumber(value: token)
            }
        }
        
        async let maskProcessing = Task {
            for (index, mask) in attentionMask.prefix(128).enumerated() {
                inputMask[index] = NSNumber(value: mask)
            }
        }
        
        await tokenProcessing.value
        await maskProcessing.value

        let output = try model.prediction(input_ids: inputTokens, attention_mask: inputMask)
        
        var lastTokenLogits: [Float] = []
        if let logits = output.featureValue(for: "logits")?.multiArrayValue {
            let vocabSize = logits.shape[2].intValue
            for i in 0..<vocabSize {
                let index = (size - 1) * vocabSize + i
                lastTokenLogits.append(logits[index].floatValue)
            }
        }
        
        let smLogits = softmax(logits: lastTokenLogits)
        let topTokens = getTopNIndices(probabilities: smLogits, n: 60)
        
        self.outputTokens.removeAll()
        for token in topTokens {
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
        return probabilities.enumerated()
            .sorted { $0.element > $1.element }
            .prefix(n)
            .map { $0.offset }
    }
}

