//
//  TweegeeParserTests.swift
//  TweegeeTests
//
//  Created by Carter Thaxton on 1/18/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import XCTest

class TweegeeParserTests: XCTestCase {

    func testBasicParse() {
        checkParse(string: """
            Some normal text
            Brackets, like I <3 U, and/or [this] thing
            Text [[link]] text
            <<set $i = 5>>
            <<if $i > 0 >>I have <<$i>> items<<else>>No items<<endif>>
            [[Choice 1|choice_1]] | [[ Choice 2 | choice_2 ]]
            // Comment is ignored
        """,
        tokens: [
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
    
    func testMissingEnd() {
        checkParseFails(string: """
            Missing [[Choice
        """)
    }

    
    // MARK: Helper methods

    func checkParse(string: String, tokens: [TweeToken]) {
        var result = [TweeToken]()
        let p = TweeParser()
        try! p.parse(string: string) { result.append($0) }
        XCTAssertEqual(result, tokens)
    }

    func checkParseFails(string: String) {
        let p = TweeParser()
        XCTAssertThrowsError(try p.parse(string: string) { _ in } )
    }
}
