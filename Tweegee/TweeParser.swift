//
//  TweeParser.swift
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
    case Macro(name: String)  // TODO: add other aspects of macro
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
        case (.Macro(let name), .Macro(let name2)):
            return name == name2
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

private let bracketsCharacterSet = CharacterSet(charactersIn: "[<")


class TweeParser {
    func parse(filename: String, block: @escaping (TweeToken) -> Void) throws {
        let str = try String(contentsOfFile: filename, encoding: .utf8)
        parse(string: str, block: block)
    }
    
    func parse(string: String, block: @escaping (TweeToken) -> Void) {
        string.enumerateLines { line, _ in
            self.parse(line: line, block: block)
        }
    }

    func parse(line: String, block handleToken: (TweeToken) -> Void) {
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
                        if s.match("[[") {
                            if !accText.isEmpty {
                                handleToken(.Text(accText))
                                accText = ""
                            }
                            let link = try? s.scan(upTo: "]]")
                            if link != nil && link! != nil {
                                let nameAndTitle = link!!.components(separatedBy: "|")
                                if nameAndTitle.count >= 2 {
                                    handleToken(.Link(name: nameAndTitle[1], title: nameAndTitle[0]))
                                } else {
                                    handleToken(.Link(name: nameAndTitle[0], title: nil))
                                }
                                s.match("]]")
                            } else {
                                // Invalid link syntax
                            }
                        } else if s.match("<<") {
                            if !accText.isEmpty {
                                handleToken(.Text(accText))
                                accText = ""
                            }
                        } else {
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
