//
//  StringTests.swift
//  TweegeeTests
//
//  Created by Carter Thaxton on 3/1/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import XCTest

class StringTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }
    
    func testStringReplace() {
        let str = "one, two, three, many"
        let replaced = str.replacing(pattern: "\\bt(\\w+)\\b") { m in "XX" + m[1]! }
        XCTAssertEqual(replaced, "one, XXwo, XXhree, many")
    }
    
    func testStringMatch() {
        let str = "one, two, three, many"
        let matches = str.matches(pattern: "t\\w+")
        XCTAssertEqual(matches.count, 2)
    }
}
