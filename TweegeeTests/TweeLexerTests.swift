//
//  TweeLexerTests.swift
//  TweegeeTests
//
//  Created by Carter Thaxton on 1/18/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import XCTest

class TweeLexerTests: XCTestCase {

    func testBasicLexer() {
        checkLexer("""
            :: Start [tag tag2] <5,25>
            Some normal text
            Brackets, like I <3 U, and/or [this] thing
            Text [[link]] text
            <<set $i = 5>>
            <<if $i > 0 >>I have <<$i>> items<<else>>No items<<endif>>
            [[Choice 1|choice_1]] | [[ Choice 2 | choice_2 ]]
            // Comment is ignored
        """,
        tokens: [
            .Passage(name: "Start", tags: ["tag", "tag2"], position: CGPoint(x: 5, y: 25)),
            .Text("Some normal text"),
            .Newline,
            .Text("Brackets, like I <3 U, and/or [this] thing"),
            .Newline,
            .Text("Text "),
            .Link(name: "link", title: nil),
            .Text(" text"),
            .Newline,
            .Macro(name: "set", expr: "$i = 5"),
            .Newline,
            .Macro(name: "if", expr: "$i > 0"),
            .Text("I have "),
            .Macro(name: nil, expr: "$i"),
            .Text(" items"),
            .Macro(name: "else", expr: nil),
            .Text("No items"),
            .Macro(name: "endif", expr: nil),
            .Newline,
            .Link(name: "choice_1", title: "Choice 1"),
            .Text(" | "),
            .Link(name: "choice_2", title: "Choice 2"),
            .Newline,
            .Comment("Comment is ignored"),
            .Newline,
        ])
    }
    
    func testInvalidLink() {
        checkLexerFails("""
            Missing [[Choice
        """, expectedError: .InvalidLinkSyntax, lineNumber: 1
        )
    }
    
    func testInvalidLinkWords() {
        checkLexerFails("""
            [[OK]]
            [[OK|Also]]
            [[Too|many|words]]
        """, expectedError: .InvalidLinkSyntax, lineNumber: 3
        )
    }

    func testInvalidMacro() {
        checkLexerFails("""
            <<if $ok>>
            Missing <<if
        """, expectedError: .InvalidMacroSyntax, lineNumber: 2
        )
    }

    
    // MARK: Helper methods

    func checkLexer(_ string: String, tokens: [TweeToken]) {
        var result = [TweeToken]()
        let lexer = TweeLexer()
        try! lexer.lex(string: string) { tok, _ in result.append(tok) }
        XCTAssertEqual(result, tokens)
    }

    func checkLexerFails(_ string: String, expectedError: TweeError? = nil, lineNumber: Int? = nil) {
        let lexer = TweeLexer()
        do {
            try lexer.lex(string: string) { _, _ in }
        } catch let error as TweeErrorLocation {
            if expectedError != nil {
                XCTAssertEqual(error.error as! TweeError, expectedError!)
            }
            if lineNumber != nil {
                XCTAssertEqual(error.location.lineNumber, lineNumber)
            }
            return
        } catch {
            XCTFail("Unexpected error thrown from lexer")
        }
        XCTFail("Expected lexer to throw an error")
    }
}
