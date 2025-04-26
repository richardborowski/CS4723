import CoreData
import UIKit

class DataManager {
    
    static let shared = DataManager()

    private init() {}

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Model")
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()

    func getContext() -> NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func saveContext() {
        let context = getContext()
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    func exportDataToJSON(userID: String) {
        let context = getContext()
        let fetchRequest: NSFetchRequest<SpeechSession> = SpeechSession.fetchRequest()

        let dateFormatter = ISO8601DateFormatter()

        do {
            let sessions = try context.fetch(fetchRequest)

            let sessionDictionaries = sessions.map { session in
                return [
                    "sessionID": session.sessionID ?? "",
                    "startTime": session.startTime != nil ? dateFormatter.string(from: session.startTime!) : "",
                    "endTime": session.endTime != nil ? dateFormatter.string(from: session.endTime!) : "",
                    "speechText": session.speechText ?? ""
                ]
            }

            let jsonData = try JSONSerialization.data(withJSONObject: sessionDictionaries, options: .prettyPrinted)
            let fileURL = getDocumentsDirectory().appendingPathComponent("speech_sessions_\(userID).json")
            try jsonData.write(to: fileURL)
            print("Exported JSON to: \(fileURL.path)")

        } catch {
            print("Failed to export data: \(error)")
        }
    }

    func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    func deleteSession(sessionID: String, userID: String) {
        let context = getContext()
        let request: NSFetchRequest<SpeechSession> = SpeechSession.fetchRequest()
        request.predicate = NSPredicate(format: "sessionID == %@", sessionID)

        do {
            let results = try context.fetch(request)
            for session in results {
                context.delete(session)
            }
            try context.save()
            exportDataToJSON(userID: userID)
            print("Deleted session \(sessionID)")
        } catch {
            print("Error deleting session: \(error)")
        }
    }

    func deleteAllSessions(userID: String) {
        let context = getContext()
        let request: NSFetchRequest<SpeechSession> = SpeechSession.fetchRequest()

        do {
            let sessions = try context.fetch(request)
            for session in sessions {
                context.delete(session)
            }
            try context.save()
            exportDataToJSON(userID: userID)
            print("Deleted all sessions")
        } catch {
            print("Error deleting all sessions: \(error)")
        }
    }
}
