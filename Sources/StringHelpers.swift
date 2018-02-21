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

extension String {
    func match(pattern: String) -> [String?]? {
        let regex: NSRegularExpression
        if let exists = regularExpressions[pattern] {
            regex = exists
        } else {
            regex = try! NSRegularExpression(pattern: pattern, options: [])
            regularExpressions[pattern] = regex
        }
        
        return match(regex: regex)
    }
    
    func match(regex: NSRegularExpression) -> [String?]? {
        let matches = regex.matches(in: self, options: [], range: NSMakeRange(0, self.utf16.count))
        guard let match = matches.first else { return nil }
        
        var results = [String?]()
        
        for i in 0...match.numberOfRanges - 1 {
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
}


extension String {
    func trimmingWhitespace() -> String {
        return self.trimmingCharacters(in: .whitespaces)
    }

    func trimmingTrailingWhitespace() -> String {
        return self.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)  // trim trailing whitespace
    }
}
