//
//  StringHelpers.swift
//  Tweegee
//
//  Created by Carter Thaxton on 1/16/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

// Unfortunate additions to workaround interop on Linux
extension NSString {
    #if !os(Linux)
    func bridge() -> String {
        return self as String
    }
    #endif
}

extension String {
    func bridge() -> NSString {
        #if !os(Linux)
        return self as NSString
        #else
        return NSString(string: self)
        #endif
    }
}


fileprivate var regularExpressions = [String: NSRegularExpression]()

fileprivate func getRegex(pattern: String) -> NSRegularExpression {
    let regex: NSRegularExpression
    if let exists = regularExpressions[pattern] {
        regex = exists
    } else {
        regex = try! NSRegularExpression(pattern: pattern, options: [])
        regularExpressions[pattern] = regex
    }
    return regex
}

extension String {
    func matches(pattern: String) -> [NSTextCheckingResult] {
        let regex = getRegex(pattern: pattern)
        return matches(regex: regex)
    }
    
    func matches(regex: NSRegularExpression) -> [NSTextCheckingResult] {
        return regex.matches(in: self, options: [], range: NSMakeRange(0, self.utf16.count))
    }
    
    func match(pattern: String) -> [String?]? {
        let regex = getRegex(pattern: pattern)
        return match(regex: regex)
    }
    
    func match(regex: NSRegularExpression) -> [String?]? {
        let matches = self.matches(regex: regex)

        guard let match = matches.first else { return nil }
        var results = [String?]()
        
        for i in 0..<match.numberOfRanges {
            let capturedGroupIndex = match.range(at: i)
            if capturedGroupIndex.length > 0 {
                let matchedString = self.bridge().substring(with: capturedGroupIndex)
                results.append(matchedString)
            } else {
                results.append(nil)
            }
        }
        
        return results
    }

    typealias ReplaceFunction = (_ captures: [String?]) -> String?

    // replaces each match using a function
    func replacing(regex: NSRegularExpression, using: ReplaceFunction) -> String {
        var result = self
        self.matches(regex: regex).reversed().forEach() { match in
            var capturedGroups = [String?]()
            for i in 0..<match.numberOfRanges {
                let capturedGroupIndex = match.range(at: i)
                if capturedGroupIndex.length > 0 {
                    let matchedString = self.bridge().substring(with: capturedGroupIndex)
                    capturedGroups.append(matchedString)
                } else {
                    capturedGroups.append(nil)
                }
            }
            let replacementRange = Range(match.range(at: 0), in: result)!
            if let replacementString = using(capturedGroups) {
                result.replaceSubrange(replacementRange, with: replacementString)
            }
        }
        return result
    }
    
    func replacing(regex: NSRegularExpression, with: String) -> String {
        return self.replacing(regex: regex) { _ in with }
    }
    
    func replacing(pattern: String, using: ReplaceFunction) -> String {
        let regex = getRegex(pattern: pattern)
        return self.replacing(regex: regex, using: using)
    }

    func replacing(pattern: String, with: String) -> String {
        let regex = getRegex(pattern: pattern)
        return self.replacing(regex: regex, with: with)
    }
}

extension String {
    func trimmingWhitespace() -> String {
        return self.trimmingCharacters(in: .whitespaces)
    }

    func trimmingTrailingWhitespace() -> String {
        return self.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)  // trim trailing whitespace
    }
    
    func trimmingCharacters(in string: String) -> String {
        return self.trimmingCharacters(in: CharacterSet.init(charactersIn: string))
    }
}
