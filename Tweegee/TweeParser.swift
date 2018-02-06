//
//  TweeParser.swift
//  Tweegee
//
//  Created by Carter Thaxton on 1/16/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

struct TweeErrorLocation : Error {
    var error : Error
    var filename : String?
    var line : String?
    var lineNumber : Int?
}

enum TweeError : Error {
    case InvalidLinkSyntax
    case InvalidMacroSyntax
}

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


class TweeParser {
    func parse(filename: String, block: @escaping (TweeToken) -> Void) throws {
        let str = try String(contentsOfFile: filename, encoding: .utf8)
        do {
            try parse(string: str, block: block)
        } catch var error as TweeErrorLocation {
            error.filename = filename
            throw error
        }
    }
    
    func parse(string: String, block: @escaping (TweeToken) -> Void) throws {
        var err : Error? = nil
        var errLine : String? = nil
        var lineNumber : Int = 1
        
        string.enumerateLines { line, stop in
            do {
                try self.parse(line: line, block: block)
                lineNumber += 1
            } catch {
                stop = true
                err = error
                errLine = line
            }
        }
        if err != nil { throw TweeErrorLocation(error: err!, filename: nil, line: errLine, lineNumber: lineNumber) }
    }

    func parse(line: String, block handleToken: (TweeToken) -> Void) throws {
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
            
            handleToken(.Passage(name: name, tags: tagsArr, position: pos))
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
                                handleToken(.Text(accText))
                                accText = ""
                            }
                            let link = try? s.scan(upTo: "]]")
                            if link != nil && link! != nil {
                                // split on pipe, and trim each component
                                let nameAndTitle = link!!.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                                if nameAndTitle.count == 2 {
                                    handleToken(.Link(name: nameAndTitle[1], title: nameAndTitle[0]))
                                } else if nameAndTitle.count == 1 {
                                    handleToken(.Link(name: nameAndTitle[0], title: nil))
                                } else {
                                    throw TweeError.InvalidLinkSyntax
                                }
                                s.match("]]")
                            } else {
                                throw TweeError.InvalidLinkSyntax
                            }
                        } else if s.match("<<") {  // macro, e.g. <<set $i = 5>>
                            if !accText.isEmpty {
                                handleToken(.Text(accText))
                                accText = ""
                            }
                            let macro = try? s.scan(upTo: ">>")
                            if macro != nil && macro! != nil {
                                let text = macro!!.trimmingCharacters(in: .whitespaces)
                                let nameAndExpr = text.split(separator: " ", maxSplits: 1)
                                if nameAndExpr.count >= 2 {
                                    handleToken(.Macro(name: String(nameAndExpr[0]), expr: String(nameAndExpr[1])))
                                } else if nameAndExpr[0].starts(with: "$") {
                                    handleToken(.Macro(name: nil, expr: String(nameAndExpr[0])))
                                } else {
                                    handleToken(.Macro(name: String(nameAndExpr[0]), expr: nil))
                                }
                                s.match(">>")
                            } else {
                                throw TweeError.InvalidMacroSyntax
                            }
                        } else if s.match("//") {  // comment, e.g. // here's a comment
                            if !accText.isEmpty {
                                handleToken(.Text(accText))
                                accText = ""
                            }
                            s.match("//")
                            let comment = s.remainder.trimmingCharacters(in: .whitespaces)
                            handleToken(.Comment(comment))
                            s.peekAtEnd()
                        } else {
                            try! s.back()
                            accText += String(try! s.scanChar())
                        }
                    }
                }
                
                if !accText.isEmpty {
                    handleToken(.Text(accText))
                }
            }
            handleToken(.Newline)
        }
    }
}
