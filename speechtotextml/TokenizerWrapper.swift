import Tokenizers
import Foundation

class TokenizerWrapper {
    var tokenizer: (any Tokenizer)?
    
    func initialize() async throws {
        self.tokenizer = try await AutoTokenizer.from(pretrained: "gpt2")
    }
    
    func encode(text: String) throws -> [Int] {
        guard let tokenizer = tokenizer else {
            throw NSError(domain: "Tokenizer not initialized", code: 1, userInfo: nil)
        }
        return tokenizer.encode(text: text)
    }
    
    func decode(tokens: [Int]) -> String {
        guard let tokenizer = tokenizer else {
            return "Tokenizer not initialized"
        }
        let re = tokenizer.decode(tokens: tokens)
        return re
    }
    
    func padTokensAndMask(text: String) async throws -> ([Int], [Int], Int) {
            var paddedTokens = try encode(text: text)
            let len = paddedTokens.count
            var attentionMask = [Int]()
            
            let paddingToken = 50256
            
            
            while paddedTokens.count < 128 {
                paddedTokens.append(paddingToken)
                attentionMask.append(0)
            }
            
            if paddedTokens.count > 128 {
                paddedTokens = Array(paddedTokens.prefix(128))
                attentionMask = Array(attentionMask.prefix(128))
            }
            
            for i in 0..<paddedTokens.count {
                if paddedTokens[i] != paddingToken {
                    attentionMask[i] = 1
                }
            }
            
            return (paddedTokens, attentionMask, len)
    }
    
}
