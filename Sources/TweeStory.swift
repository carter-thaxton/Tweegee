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

    func addPassage(passage: TweePassage) throws {
        if let existing = passagesByName[passage.name] {
            throw TweeError(type: .DuplicatePassageName, location: passage.location,
                                    message: "Passage \(passage.name) is already defined on line \(existing.location.lineNumber)")
        }
        passagesByName[passage.name] = passage
        passagesInOrder.append(passage)
    }
    
    func removePassage(name: String) -> TweePassage? {
        if let passage = passagesByName.removeValue(forKey: name) {
            if let index = passagesInOrder.index(where: { $0 === passage }) {
                passagesInOrder.remove(at: index)
            } else {
                fatalError("Passage found by name, but not in passagesInOrder: \(name)")
            }
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
