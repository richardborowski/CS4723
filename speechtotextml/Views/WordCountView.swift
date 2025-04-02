import SwiftUI

struct WordCountView: View {
    @Binding var wordCountDictionary: [String: Int] 
    
    var body: some View {
        VStack {
            Text("Word Counts")
                .font(.largeTitle)
                .padding()
            
            List(wordCountDictionary.keys.sorted(), id: \.self) { word in
                HStack {
                    Text(word)
                        .font(.body)
                    Spacer()
                    Text("\(wordCountDictionary[word]!)")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            .frame(maxHeight: .infinity)
        }
        .padding()
        .onAppear {
            loadWordCounts()
        }
    }
    
    private func loadWordCounts() {
        if let savedWordCounts = UserDefaults.standard.object(forKey: "wordCounts") as? [String: Int] {
            wordCountDictionary = savedWordCounts
        }
    }
}


