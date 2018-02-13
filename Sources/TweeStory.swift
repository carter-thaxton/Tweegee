//
//  TweeStory.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/7/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

class TweeStory {
    var passages = [String : TweePassage]()

    var startPassage : TweePassage? {
        // For now, don't support Twee2Settings to specify the start passage.
        // Just hardcode to use "Start" as the passage name.
        return passages["Start"]
    }

    func addPassage(passage: TweePassage) throws {
        if let _ = passages[passage.name] {
            // TODO: include reference to existing passage in error
            throw TweeErrorLocation(error: TweeError.DuplicatePassageName, location: passage.location)
        }
        passages[passage.name] = passage
    }
}

class TweePassage {
    let location : TweeLocation
    let name : String
    let position : CGPoint?
    let tags : [String]
    var statements = [TweeStatement]()
    
    init(location: TweeLocation, name: String, position: CGPoint?, tags: [String]) {
        self.location = location
        self.name = name
        self.position = position
        self.tags = tags
    }
}

class TweeStatement {
    let location : TweeLocation
    
    init(location: TweeLocation) {
        self.location = location
    }
}

