import SwiftUI
import CoreData

struct SpeechSessionModel: Codable, Identifiable {
    var id: String { sessionID }
    let sessionID: String
    let startTime: String // ISO date format
    let endTime: String
    let speechText: String
}

struct SpeechSessionsView: View {
    @State private var sessions: [SpeechSessionModel] = []
    @State private var showDeleteAllConfirmation = false
    @State private var expandedSessions: Set<String> = []
    
    let userID: String
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session: \(formattedStartTime(from: session.startTime))")
                            .font(.headline)
                        
                        if expandedSessions.contains(session.sessionID) {
                            Text(session.speechText)
                                .font(.body)
                                .padding(.top, 4)
                        } else {
                            Text(session.speechText)
                                .font(.body)
                                .lineLimit(3)
                                .padding(.top, 4)
                        }

                        Button(action: {
                            toggleSessionExpansion(sessionID: session.sessionID)
                        }) {
                            Text(expandedSessions.contains(session.sessionID) ? "Collapse" : "Expand")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteSession)
            }
            .navigationTitle("Speech Sessions")
            .onAppear(perform: loadSessionsFromJSON)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteAllConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .alert("Delete All Sessions?", isPresented: $showDeleteAllConfirmation) {
                Button("Delete All", role: .destructive, action: deleteAllSessions)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    func getFileURL() -> URL {
        let filename = "speech_sessions_\(userID).json"
        return DataManager.shared.getDocumentsDirectory().appendingPathComponent(filename)
    }

    func loadSessionsFromJSON() {
        let fileURL = getFileURL()

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([SpeechSessionModel].self, from: data)
            self.sessions = decoded
        } catch {
            print("Error loading JSON: \(error)")
        }
    }

    func deleteSession(at offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            DataManager.shared.deleteSession(sessionID: session.sessionID, userID: userID)
        }
        loadSessionsFromJSON()
    }

    func deleteAllSessions() {
        DataManager.shared.deleteAllSessions(userID: userID)
        loadSessionsFromJSON()
    }

    func saveSessionsToJSON() {
        let fileURL = getFileURL()

        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: fileURL)
        } catch {
            print("Error saving updated JSON: \(error)")
        }
    }

    func toggleSessionExpansion(sessionID: String) {
        if expandedSessions.contains(sessionID) {
            expandedSessions.remove(sessionID)
        } else {
            expandedSessions.insert(sessionID)
        }
    }
    
    // Helper function to format the startTime to desired format
    func formattedStartTime(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "hh:mma MM/dd/yyyy"
            displayFormatter.locale = Locale.current
            displayFormatter.timeZone = TimeZone.current

            return displayFormatter.string(from: date)
        }
        
        return isoString // Return original if date parsing fails
    }
}
