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
    
    var startPassageName : String = "Start"
    var title : String?
    var author : String?

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
        var passages = DictArr()
        for passage in passagesInOrder {
            passages.append(passage.asJson())
        }
        
        return ["title": title ?? NSNull(), "author": author ?? NSNull(), "start": startPassageName, "passageCount": passageCount, "passages": passages]
    }
}
