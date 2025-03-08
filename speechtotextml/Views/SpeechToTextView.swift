//
//  SpeechToTextView.swift
//  speechtotextml
//
//  Created by Richard Borowski on 3/6/25.
//

import SwiftUI
import AVFoundation
import Speech

struct SpeechToTextView: View {
    
    @State private var text = ""
    @State private var isRecording = false
    @State private var startButtonEnabled = true
    
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var audioEngine: AVAudioEngine!
    private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    init() {
        audioEngine = AVAudioEngine()
    }
    
    var body: some View {
        VStack {
            Text(text)
                .font(.title)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.black)
            
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
                self.text = result.bestTranscription.formattedString
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
    }
    
    private func stopRecording() {
        audioEngine.stop()
        
        recognitionRequest?.endAudio()
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        self.text = ""
        self.isRecording = false
    }
}
