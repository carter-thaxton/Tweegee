//
//  TweeLexer.swift
//  Tweegee
//
//  Created by Carter Thaxton on 1/16/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

enum TweeToken {
    case Newline
    case Passage(name: String, tags: [String], position: CGPoint?)
    case Text(String)
    case Link(name: String, title: String?)
    case Macro(name: String?, expr: String?)
    case Comment(String)
}

extension TweeToken : Equatable {
    // Kinda lame that we have to do this
    func isEqual(_ t : TweeToken) -> Bool {
        switch (self, t) {
        case (.Newline, .Newline):
            return true
        case (.Passage(let name, let tags, let position), .Passage(let name2, let tags2, let position2)):
            return name == name2 && tags == tags2 && position == position2
        case (.Text(let text), .Text(let text2)):
            return text == text2
        case (.Link(let name, let title), .Link(let name2, let title2)):
            return name == name2 && title == title2
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
    let lettersAndSlash = CharacterSet.letters.union(CharacterSet(charactersIn: "/"))

    func lex(filename: String, block: @escaping (TweeToken, TweeLocation) throws -> Void) throws {
        let str = try String(contentsOfFile: filename, encoding: .utf8)
        try lex(string: str, filename: filename, block: block)
    }

    func lex(string: String, filename: String? = nil, block: @escaping (TweeToken, TweeLocation) throws -> Void) throws {
        var location = TweeLocation(filename: filename, line: nil, lineNumber: 1)
        let lines = string.components(separatedBy: .newlines)  // TODO: consider enumerateLines, which doesn't work on Linux
        for line in lines {
            location.line = line
            try self.lex(line: line, location: location, block: block)
            location.lineNumber += 1
        }
    }

    func lex(line: String, location: TweeLocation, block handleToken: (TweeToken, TweeLocation) throws -> Void) throws {
        if let matches = line.match(regex: passageHeaderRegex) {
            let name = matches[1]!.trimmingCharacters(in: .whitespaces)
            let tags = matches[2]
            let posx = matches[3]
            let posy = matches[4]
            
            let tagsArr = tags?.components(separatedBy: .whitespaces).filter {!$0.isEmpty} ?? []
            
            var pos : CGPoint?
            if posx != nil && posy != nil {
                pos = CGPoint(x: Int(posx!)!, y: Int(posy!)!)
            }
            
            try handleToken(.Passage(name: name, tags: tagsArr, position: pos), location)
        } else {
            let text = line.trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                var accText = ""
                
                let s = StringScanner(text)
                while !s.isAtEnd {
                    let str = try? s.scan(upTo: bracketsCharacterSet)
                    if str != nil && str! != nil {
                        accText += str!!
                    }
                    if !s.isAtEnd {
                        if s.match("[[") {  // link, e.g [[Choice|choice_1]]
                            if !accText.isEmpty {
                                try handleToken(.Text(accText), location)
                                accText = ""
                            }
                            let link = try? s.scan(upTo: "]]")
                            if link != nil && link! != nil {
                                // split on pipe, and trim each component
                                let nameAndTitle = link!!.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                                if nameAndTitle.count == 2 {
                                    try handleToken(.Link(name: nameAndTitle[1], title: nameAndTitle[0]), location)
                                } else if nameAndTitle.count == 1 {
                                    try handleToken(.Link(name: nameAndTitle[0], title: nil), location)
                                } else {
                                    throw TweeErrorLocation(error: .InvalidLinkSyntax, location: location, message: "Invalid link syntax.  Too many | symbols")
                                }
                                s.match("]]")
                            } else {
                                throw TweeErrorLocation(error: .InvalidLinkSyntax, location: location, message: "Invalid link syntax.  Missing ]]")
                            }
                        } else if s.match("<<") {  // macro, e.g. <<set $i = 5>>
                            if !accText.isEmpty {
                                try handleToken(.Text(accText), location)
                                accText = ""
                            }
                            let macro = try? s.scan(upTo: ">>")
                            if macro != nil && macro! != nil {
                                let text = macro!!.trimmingCharacters(in: .whitespaces)
                                if text.isEmpty {
                                    throw TweeErrorLocation(error: .InvalidMacroSyntax, location: location, message: "Found empty macro")
                                } else if !lettersAndSlash.contains(text.unicodeScalars.first!) {
                                    // doesn't start with a letter or slash, so it's a raw expression
                                    try handleToken(.Macro(name: nil, expr: text), location)
                                } else {
                                    // starts with a latter, split on name and rest of expression
                                    let nameAndExpr = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                                    if nameAndExpr.count >= 2 {
                                        try handleToken(.Macro(name: String(nameAndExpr[0]), expr: String(nameAndExpr[1])), location)
                                    } else {
                                        try handleToken(.Macro(name: String(nameAndExpr[0]), expr: nil), location)
                                    }
                                }
                                s.match(">>")
                            } else {
                                throw TweeErrorLocation(error: .InvalidMacroSyntax, location: location, message: "Invalid macro syntax.  Missing >>")
                            }
                        } else if s.match("//") {  // comment, e.g. // here's a comment
                            accText = accText.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)  // trim trailing whitespace
                            if !accText.isEmpty {
                                try handleToken(.Text(accText), location)
                                accText = ""
                            }
                            s.match("//")
                            let comment = s.remainder.trimmingCharacters(in: .whitespaces)
                            try handleToken(.Comment(comment), location)
                            s.peekAtEnd()
                        } else {
                            try! s.back()
                            accText += String(try! s.scanChar())
                        }
                    }
                }
                
                accText = accText.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)  // trim trailing whitespace
                if !accText.isEmpty {
                    try handleToken(.Text(accText), location)
                }
            }
            try handleToken(.Newline, location)
        }
    }
}
