//
//  TweeLexer.swift
//  Tweegee
//
//  Created by Carter Thaxton on 1/16/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

enum TweeToken : Equatable {
    case Newline(String)
    case Passage(name: String, tags: [String], posX: Int?, posY: Int?)
    case Text(String)
    case Link(passage: String, text: String?)
    case Macro(name: String?, expr: String?)
    case Comment(String)
    case Error(type: TweeErrorType, message: String)
}

// Kinda lame that we have to do this
func ==(lhs: TweeToken, rhs: TweeToken) -> Bool {
    switch (lhs, rhs) {
    case (.Newline(let line), .Newline(let line2)):
        return line == line2
    case (.Passage(let name, let tags, let posX, let posY), .Passage(let name2, let tags2, let posX2, let posY2)):
        return name == name2 && tags == tags2 && posX == posX2 && posY == posY2
    case (.Text(let text), .Text(let text2)):
        return text == text2
    case (.Link(let passage, let text), .Link(let passage2, let text2)):
        return passage == passage2 && text == text2
    case (.Macro(let name, let expr), .Macro(let name2, let expr2)):
        return name == name2 && expr == expr2
    case (.Comment(let comment), .Comment(let comment2)):
        return comment == comment2
    default:
        return false
    }
}

class TweeLexer {
    // MARK: Private Definitions

    private let passageHeaderRegex = try! NSRegularExpression(pattern:
        """
        ^\\s*                       (?# ignore whitespace at beginning of line )

        (?:                         (?# -- passage header -- )
            ::([^\\[<]+)            (?# match passage name )
            \\s*
            (?:                     (?# optional tags like [tag1 tag2] )
                \\[\\s*(.*)\\s*\\]  (?# matches all text between the brackets )
            )?
            \\s*
            (?:                     (?# optional position like <5,6> )
                <\\s*(\\d+)\\s*,\\s*(\\d+)\\s*>
            )?
        )
    """, options: .allowCommentsAndWhitespace)

    private let macroNameCharacters = CharacterSet.letters.union(CharacterSet(charactersIn: "/"))
    
    private enum LexerState : Equatable {
        case text
        case link
        case macro
        case comment
    }

    // MARK: Public Interface
    
    func lex(filename: String, block: @escaping (TweeToken, TweeLocation) -> Void) throws {
        let str = try String(contentsOfFile: filename, encoding: .utf8)
        lex(string: str, filename: filename, block: block)
    }

    func lex(string: String, filename: String? = nil, block: @escaping (TweeToken, TweeLocation) -> Void) {
        var location = TweeLocation(filename: filename, passage: nil, fileLineNumber: 1, passageLineNumber: 0)
        let lines = string.components(separatedBy: .newlines)  // TODO: consider enumerateLines, which doesn't work on Linux
        for line in lines {
            lex(line: line, location: &location, block: block)
            location.fileLineNumber += 1
            location.passageLineNumber += 1
        }
    }

    func lex(line: String, location: inout TweeLocation, block handleToken: (TweeToken, TweeLocation) -> Void) {
        if let matches = line.match(regex: passageHeaderRegex) {
            let name = matches[1]!.trimmingWhitespace()
            let tags = matches[2]
            let posx = matches[3]
            let posy = matches[4]
            
            let tagsArr = tags?.components(separatedBy: .whitespaces).filter {!$0.isEmpty} ?? []
            
            var posX : Int?
            var posY : Int?
            if posx != nil && posy != nil {
                posX = Int(posx!)
                posY = Int(posy!)
            }

            location.passage = name  // keep track of most recent passage name in location
            location.passageLineNumber = 0  // and line number within passage
            handleToken(.Passage(name: name, tags: tagsArr, posX: posX, posY: posY), location)
        } else {
            let text = line.trimmingWhitespace()
            if !text.isEmpty {
                var accText = ""
                var state = LexerState.text

                // Look for <<, [[, or // to start a token, and >>, ]] to end a token.
                // Since these are all two-character strings, go ahead and always get the next two chars.
                var i = text.startIndex
                var skipChar = false
                while i < text.endIndex {
                    let ci = text[i]
                    let j = text.index(after: i)
                    if j < text.endIndex {
                        let cj = text[j]
                        
                        switch (state, ci, cj) {

                        case (.text, "[", "["):
                            // start link, match until ]]
                            if !accText.isEmpty {
                                handleToken(.Text(accText), location)
                            }
                            accText = ""
                            skipChar = true
                            state = .link

                        case (.link, "]", "]"):
                            // end link
                            // split on pipe, and trim each component
                            let passageAndText = accText.components(separatedBy: "|").map { $0.trimmingWhitespace() }
                            if passageAndText.count == 2 {
                                handleToken(.Link(passage: passageAndText[1], text: passageAndText[0]), location)
                            } else if passageAndText.count == 1 {
                                handleToken(.Link(passage: passageAndText[0], text: nil), location)
                            } else {
                                return handleToken(.Error(type: .InvalidLinkSyntax, message: "Invalid link syntax.  Too many | symbols"), location)
                            }
                            accText = ""
                            skipChar = true
                            state = .text

                        case (.text, "<", "<"):
                            // start macro, match until >>
                            if !accText.isEmpty {
                                handleToken(.Text(accText), location)
                            }
                            accText = ""
                            skipChar = true
                            state = .macro

                        case (.macro, ">", ">"):
                            // end macro
                            let macro = accText.trimmingWhitespace()
                            if macro.isEmpty {
                                return handleToken(.Error(type: .InvalidMacroSyntax, message: "Found empty macro"), location)
                            } else if macroNameCharacters.contains(macro.unicodeScalars.first!) {
                                // starts with a macro, split on whitespace, giving name and rest of expression
                                let nameAndExpr = macro.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                                if nameAndExpr.count >= 2 {
                                    handleToken(.Macro(name: String(nameAndExpr[0]), expr: String(nameAndExpr[1])), location)
                                } else {
                                    handleToken(.Macro(name: String(nameAndExpr[0]), expr: nil), location)
                                }
                            } else if macro.first == "=" {
                                // macro like <<=$x>>, behaves similar to <<$x>> below, but with macro name "="
                                let expr = String(macro.dropFirst())
                                handleToken(.Macro(name: "=", expr: expr), location)
                            } else {
                                // doesn't start with a macro name, so it's a raw expression like <<$x>>
                                handleToken(.Macro(name: nil, expr: macro), location)
                            }
                            accText = ""
                            skipChar = true
                            state = .text
                            
                        case (.text, "/", "/"):
                            // start comment, match until end of line
                            // trim any whitespace before comment begins
                            accText = accText.trimmingTrailingWhitespace()
                            if !accText.isEmpty {
                                handleToken(.Text(accText), location)
                            }
                            accText = ""
                            skipChar = true
                            state = .comment

                        default:
                            // no match, accumulate and move on
                            accText.append(ci)
                        }
                    } else {
                        // last char of line
                        accText.append(ci)
                    }
                    // advance index
                    i = j
                    if skipChar {
                        i = text.index(after: i)
                        skipChar = false
                    }
                }

                // reached end of line, check state
                switch state {
                case .text:
                    if !accText.isEmpty {
                        handleToken(.Text(accText), location)
                    }

                case .comment:
                    handleToken(.Comment(accText.trimmingWhitespace()), location)

                case .link:
                    handleToken(.Error(type: .InvalidLinkSyntax, message: "Invalid link syntax.  Missing ]]"), location)
                    
                case .macro:
                    return handleToken(.Error(type: .InvalidMacroSyntax, message: "Invalid macro syntax.  Missing >>"), location)
                }
            }
        }

        // always include a newline token with entire line
        handleToken(.Newline(line), location)
    }

}
