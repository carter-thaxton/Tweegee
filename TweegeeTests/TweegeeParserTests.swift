//
//  TweegeeParserTests.swift
//  TweegeeTests
//
//  Created by Carter Thaxton on 1/18/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import XCTest

class TweegeeParserTests: XCTestCase {

    func testParse() {
        checkParse(string: """
            Text [[link]] text
            [[Choice 1|choice_1]] | [[Choice 2|choice_2]]
        """,
        tokens: [
            .Text("Text "),
            .Link(name: "link", title: nil),
            .Text(" text"),
            .Newline,
            .Link(name: "choice_1", title: "Choice 1"),
            .Text(" | "),
            .Link(name: "choice_2", title: "Choice 2"),
            .Newline
        ])
    }
    
    func checkParse(string: String, tokens: [TweeToken]) {
        var result = [TweeToken]()
        let p = TweeParser()
        p.parse(string: string) { result.append($0) }
        XCTAssertEqual(result, tokens)
    }

}
