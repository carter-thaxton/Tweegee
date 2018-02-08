//
//  TweeParser.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/7/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

class TweeParser {
    let lexer = TweeLexer()
    let story = TweeStory()
    var currentPassage : TweePassage?
    
    func parse(filename: String) throws -> TweeStory {
        try lexer.lex(filename: filename, block: handleToken)
        return story
    }

    func parse(string: String) throws -> TweeStory {
        try lexer.lex(string: string, block: handleToken)
        return story
    }

    func handleToken(token: TweeToken, location: TweeLocation) throws {
        switch token {
        case .Passage(let name, let tags, let position):
            let passage = TweePassage(location: location, name: name, position: position, tags: tags)
            try story.addPassage(passage: passage)
        default:
            // TODO: implement the rest
            break
        }
    }
}
