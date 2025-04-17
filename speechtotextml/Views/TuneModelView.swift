import SwiftUI
import CoreML
import ZIPFoundation

struct TuneModelView: View {
    let userID: String
    
    @State private var uploadStatus: String = ""
    @State private var isFineTuning = false
    @State private var progress: Double = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Update Recommendations")
                .font(.title2)
                .padding()
            
            Button(action: {
                uploadFile(userId: userID)
            }) {
                Text("Send")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .disabled(isFineTuning)
            ProgressView(uploadStatus, value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .padding()
        }
        .padding()
    }
    
    func uploadFile(userId: String) {

        Task {
            let fileManager = FileManager.default
            guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                await MainActor.run {
                    self.uploadStatus = "Cannot access documents directory."
                    self.isFineTuning = false
                }
                return
            }

            let uniqueFilename = "speech_sessions_\(userId).json"
            let uniqueFileURL = documentsURL.appendingPathComponent(uniqueFilename)

            guard fileManager.fileExists(atPath: uniqueFileURL.path) else {
                await MainActor.run {
                    self.uploadStatus = "Need to record more audio first."
                    self.isFineTuning = false
                }
                return
            }

            await MainActor.run {
                self.uploadStatus = "Uploading..."
                self.progress = 0.0
                self.isFineTuning = true
            }

            Task {
                for _ in 0..<10 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await MainActor.run {
                        if self.progress < 0.3 {
                            self.progress += 0.03
                        }
                    }
                }
                await MainActor.run {
                    self.uploadStatus = "Fine Tuning..."
                }
            }
            

            await performUpload(userId: userId)
        }
    }
    
    func performUpload(userId: String) async {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            await MainActor.run {
                self.uploadStatus = "Cannot access documents directory."
                self.isFineTuning = false
            }
            return
        }

        let uniqueFilename = "speech_sessions_\(userId).json"
        let uniqueFileURL = documentsURL.appendingPathComponent(uniqueFilename)

        guard fileManager.fileExists(atPath: uniqueFileURL.path) else {
            await MainActor.run {
                self.uploadStatus = "Need to record more audio first."
                self.isFineTuning = false
            }
            return
        }

        guard let serverURL = URL(string: "https://polishhammer11.com/upload") else {
            await MainActor.run {
                self.uploadStatus = "Invalid server URL."
                self.isFineTuning = false
            }
            return
        }

        do {
            var request = URLRequest(url: serverURL)
            request.httpMethod = "POST"
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"userId\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(userId)\r\n".data(using: .utf8)!)

            let mimeType = "application/json"
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"fileData\"; filename=\"\(uniqueFilename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(try Data(contentsOf: uniqueFileURL))
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

            let (data, response) = try await URLSession.shared.upload(for: request, from: body)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run {
                    self.uploadStatus = "Upload failed. Status code: \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                    self.isFineTuning = false
                }
                return
            }

            await unzipAndLoadModel(data: data, userId: userId)

        } catch {
            await MainActor.run {
                self.uploadStatus = "Upload error: \(error.localizedDescription)"
                self.isFineTuning = false
            }
        }
    }
    
    func unzipAndLoadModel(data: Data, userId: String) async {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            await MainActor.run {
                self.uploadStatus = "Could not access documents directory"
                self.isFineTuning = false
            }
            return
        }

        let zipFilename = "DownloadedModel_\(userId).zip"
        let zipFileURL = documentsURL.appendingPathComponent(zipFilename)

        do {
            try data.write(to: zipFileURL)

            let unzipDirectoryURL = documentsURL.appendingPathComponent("UnzippedModel_\(userId)")
            try? fileManager.removeItem(at: unzipDirectoryURL)
            try fileManager.createDirectory(at: unzipDirectoryURL, withIntermediateDirectories: true)

            guard let archive = Archive(url: zipFileURL, accessMode: .read) else {
                await MainActor.run {
                    self.uploadStatus = "Failed to read zip archive"
                    self.isFineTuning = false
                }
                return
            }

            for entry in archive {
                let destinationURL = unzipDirectoryURL.appendingPathComponent(entry.path)
                try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try archive.extract(entry, to: destinationURL)
            }

            let compiledModelURL = unzipDirectoryURL.appendingPathComponent("Model.mlpackage")
            let compiledModel = try await MLModel.compileModel(at: compiledModelURL)
            let _ = try MLModel(contentsOf: compiledModel)

            UserDefaults.standard.set(compiledModelURL.path, forKey: "customModelPath")

            for _ in 0..<25 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    self.progress = min(1.0, self.progress + 0.03)
                }
            }

            await MainActor.run {
                self.uploadStatus = "Fine Tuning Complete!"
                self.isFineTuning = false
            }

        } catch {
            await MainActor.run {
                self.uploadStatus = "Error processing model: \(error.localizedDescription)"
                self.isFineTuning = false
            }
        }
    }

}
