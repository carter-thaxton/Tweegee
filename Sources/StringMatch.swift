//
//  StringMatch.swift
//  Tweegee
//
//  Created by Carter Thaxton on 1/16/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

fileprivate var expressions = [String: NSRegularExpression]()

extension String {
    func match(pattern: String) -> [String?]? {
        let expression: NSRegularExpression
        if let exists = expressions[pattern] {
            expression = exists
        } else {
            expression = try! NSRegularExpression(pattern: pattern, options: [])
            expressions[pattern] = expression
        }
        
        return match(regex: expression)
    }
    
    func match(regex: NSRegularExpression) -> [String?]? {
        let matches = regex.matches(in: self, options: [], range: NSMakeRange(0, self.utf16.count))
        guard let match = matches.first else { return nil }
        
        var results = [String?]()
        
        for i in 0...match.numberOfRanges - 1 {
            let capturedGroupIndex = match.range(at: i)
            if capturedGroupIndex.length > 0 {
                let matchedString = (self as NSString).substring(with: capturedGroupIndex)
                results.append(matchedString)
            } else {
                results.append(nil)
            }
        }
        
        return results
    }
}
