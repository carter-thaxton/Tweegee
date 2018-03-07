//
//  TweeLocation.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/26/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

struct TweeLocation : Equatable {
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

func ==(lhs: TweeLocation, rhs: TweeLocation) -> Bool {
    return lhs.filename == rhs.filename &&
        lhs.passage == rhs.passage &&
        lhs.fileLineNumber == rhs.fileLineNumber &&
        lhs.passageLineNumber == rhs.passageLineNumber
}
