//
//  TweeLexer.swift
//  Tweegee
//
//  Created by Carter Thaxton on 1/16/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

enum TweeToken {
    case Newline(String)
    case Passage(name: String, tags: [String], position: CGPoint?)
    case Text(String)
    case Link(passage: String, title: String?)
    case Macro(name: String?, expr: String?)
    case Comment(String)
    case Error(type: TweeErrorType, message: String)
}

extension TweeToken : Equatable {
    // Kinda lame that we have to do this
    func isEqual(_ t : TweeToken) -> Bool {
        switch (self, t) {
        case (.Newline(let line), .Newline(let line2)):
            return line == line2
        case (.Passage(let name, let tags, let position), .Passage(let name2, let tags2, let position2)):
            return name == name2 && tags == tags2 && position == position2
        case (.Text(let text), .Text(let text2)):
            return text == text2
        case (.Link(let passage, let title), .Link(let passage2, let title2)):
            return passage == passage2 && title == title2
        case (.Macro(let name, let expr), .Macro(let name2, let expr2)):
            return name == name2 && expr == expr2
        case (.Comment(let comment), .Comment(let comment2)):
            return comment == comment2
        default:
            return false
        }
    }
}

func ==(lhs: TweeToken, rhs: TweeToken) -> Bool {
    return lhs.isEqual(rhs)
}

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

private let bracketsCharacterSet = CharacterSet(charactersIn: "[</")


class TweeLexer {
    let macroNameCharacters = CharacterSet.letters.union(CharacterSet(charactersIn: "/="))
    
    enum LexerState : Equatable {
        case text
        case link
        case macro
        case comment
    }

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
            
            var pos : CGPoint?
            if posx != nil && posy != nil {
                pos = CGPoint(x: Int(posx!)!, y: Int(posy!)!)
            }

            location.passage = name  // keep track of most recent passage name in location
            location.passageLineNumber = 0  // and line number within passage
            handleToken(.Passage(name: name, tags: tagsArr, position: pos), location)
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
                            let passageAndTitle = accText.components(separatedBy: "|").map { $0.trimmingWhitespace() }
                            if passageAndTitle.count == 2 {
                                handleToken(.Link(passage: passageAndTitle[1], title: passageAndTitle[0]), location)
                            } else if passageAndTitle.count == 1 {
                                handleToken(.Link(passage: passageAndTitle[0], title: nil), location)
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
                            } else {
                                // doesn't start with a macro name, so it's a raw expression
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
