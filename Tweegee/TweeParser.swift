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
        print(token)
        func ensurePassage() throws {
            if currentPassage == nil {
                throw TweeErrorLocation(error: TweeError.TextOutsidePassage, location: location)
            }
        }

        switch token {

        case .Passage(let name, let tags, let position):
            currentPassage = TweePassage(location: location, name: name, position: position, tags: tags)
            try story.addPassage(passage: currentPassage!)

        case .Comment(let comment):
            // ignore comments
            _ = comment
            break

        case .Newline:
            // TODO: figure this out
            break

        case .Text(let text):
            // TODO: handle this
            _ = text
            try ensurePassage()

        case .Link(let name, let title):
            // TODO: handle this
            _ = name
            _ = title
            try ensurePassage()

        case .Macro(let name, let expr):
            // TODO: handle this
            _ = name
            _ = expr
            try ensurePassage()
        }
    }
}
