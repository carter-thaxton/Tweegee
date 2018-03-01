//
//  TweeLocation.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/26/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

struct TweeLocation {
    var filename : String?
    var passage: String?
    var fileLineNumber : Int
    var passageLineNumber : Int

    func getLine(story: TweeStory?) -> String? {
        if let passage = story?.passagesByName[passage ?? ""] {
            return passage.rawTwee[passageLineNumber]
        }
        return nil
    }
}
