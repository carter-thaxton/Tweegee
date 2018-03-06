//
//  TweeDelay.swift
//  Tweegee
//
//  Created by Carter Thaxton on 3/5/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

struct TweeDelay : CustomStringConvertible {
    let string: String
    let seconds: Int

    init?(fromString string: String) {
        self.string = string
        
        guard let match = string.match(pattern: "^(\\d+)([smh])$") else { return nil }
        guard let num = Int(match[1]!) else { return nil }
        
        switch match[2]! {
        case "s":
            self.seconds = num
        case "m":
            self.seconds = num * 60
        case "h":
            self.seconds = num * 3600
        default:
            return nil
        }
    }

    var description: String {
        return string
    }
}
