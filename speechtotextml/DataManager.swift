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

    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }


    func getContext() -> NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func exportDataToJSON() {
        let context = getContext()
        let fetchRequest: NSFetchRequest<SpeechSession> = SpeechSession.fetchRequest()
        
        let dateFormatter = ISO8601DateFormatter()
        
        do {
            let sessions = try context.fetch(fetchRequest)
            
            var sessionDictionaries: [[String: Any]] = []
            for session in sessions {
                let dict: [String: Any] = [
                    "sessionID": session.sessionID ?? "",
                    "startTime": session.startTime != nil ? dateFormatter.string(from: session.startTime!) : "",
                    "endTime": session.endTime != nil ? dateFormatter.string(from: session.endTime!) : "",
                    "speechText": session.speechText ?? ""
                ]
                sessionDictionaries.append(dict)
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: sessionDictionaries, options: .prettyPrinted)
            
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            
            guard let documentsDirectory = documentsURL else {
                print("Could not find Documents directory.")
                return
            }
            
            let fileURL = documentsDirectory.appendingPathComponent("speech_sessions.json")
            
            try jsonData.write(to: fileURL)
            print("Data exported to: \(fileURL.path)")
            
        } catch {
            print("Error fetching or exporting data: \(error)")
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func clearDatabase() {
        let context = getContext()
        
        let fetchRequest: NSFetchRequest<SpeechSession> = SpeechSession.fetchRequest()
        
        do {
            let sessions = try context.fetch(fetchRequest)
            
            for session in sessions {
                context.delete(session)
            }
            
            try context.save()
            print("Database cleared successfully.")
            
        } catch {
            print("Error clearing database: \(error)")
        }
    }
}

