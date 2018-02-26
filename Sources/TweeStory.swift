//
//  TweeStory.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/7/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

class TweeStory : AsJson {
    var passagesByName = [String : TweePassage]()
    var passagesInOrder = [TweePassage]()
    
    var passageCount : Int { return passagesInOrder.count }
    var wordCount : Int = 0
    
    var startPassageName : String = "Start"
    var title : String?
    var author : String?
    
    var errors = [TweeError]()

    var startPassage : TweePassage? {
        // For now, don't support Twee2Settings to specify the start passage.
        // Just hardcode to use "Start" as the passage name.
        return passagesByName[startPassageName]
    }

    func addPassage(passage: TweePassage) -> TweePassage? {
        // If there are duplicate passages with the same name, passagesByName will refer to the first encountered,
        // and the duplicate will be present in passagesInOrder.
        passagesInOrder.append(passage)

        // If there is an existing passage with that name, return it
        if let existing = passagesByName[passage.name] {
            return existing
        }

        // Otherwise return nil, indicating success
        passagesByName[passage.name] = passage
        return nil
    }

    func removePassage(name: String) -> TweePassage? {
        if let passage = passagesByName.removeValue(forKey: name) {
            passagesInOrder = passagesInOrder.filter { $0.name != name }  // remove all that match the name
            return passage
        }
        return nil
    }

    func asJson() -> Dict {
        return asJson(includePassages: true)
    }

    // Linux swift can't handle AsJson prototype with optional arguments.  Grr...
    func asJson(includePassages: Bool) -> Dict {
        var passagesData = DictArr()
        if includePassages {
            for passage in passagesInOrder {
                passagesData.append(passage.asJson())
            }
        }
        
        var errorsData = DictArr()
        for error in errors {
            errorsData.append(error.asJson())
        }
        
        let statistics = ["passageCount": passageCount, "wordCount": wordCount]

        return ["title": title ?? NSNull(), "author": author ?? NSNull(), "start": startPassageName, "errors": errorsData,
                "statistics": statistics, "passages": includePassages ? passagesData : NSNull()]
    }

    func visit(fn: (TweeStatement) -> Void) {
        for passage in passagesInOrder {
            passage.visit(fn: fn)
        }
    }

    func getAllLinks() -> [TweeLinkStatement] {
        var result = [TweeLinkStatement]()
        
        visit() { (stmt) in
            if let link = stmt as? TweeLinkStatement {
                result.append(link)
            } else if let choice = stmt as? TweeChoiceStatement {
                result.append(contentsOf: choice.choices)
            } else if let include = stmt as? TweeIncludeStatement {
                // TODO: if include.passageExpr.isLiteral
                _ = include
            }
        }
        
        return result
    }
}
