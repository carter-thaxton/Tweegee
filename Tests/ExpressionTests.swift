//
//  ExpressionTests.swift
//  TweegeeTests
//
//  Created by Carter Thaxton on 2/28/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import XCTest

class ExpressionTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }
    
    func testStringReplace() {
        let str = "one, two, three, many"
        let replaced = str.replacing(pattern: "\\bt(\\w+)\\b") { m in "XX" + m[1]! }
        XCTAssertEqual(replaced, "one, XXwo, XXhree, many")
    }
    
    func testNormalizeExpression() {
        let str = TweeExpression.normalize("(a or b) and not (5 gt 6)")
        XCTAssertEqual(str, "(a || b) && ! (5 > 6)")
    }
    
    func testBasicExpression() throws {
        testEvalAsString("'a' + 5", expect: "a5")
        testEvalAsInt("6 + 5", expect: 11)
        testEvalAsBool("false || true", expect: true)
    }


    func testEvalAsString(_ expr: String, expect: String) {
        let result = eval(expr) as String
        XCTAssertEqual(result, expect)
    }

    func testEvalAsBool(_ expr: String, expect: Bool) {
        let result = eval(expr) as Bool
        XCTAssertEqual(result, expect)
    }
    
    func testEvalAsInt(_ expr: String, expect: Int) {
        let result = eval(expr) as Int
        XCTAssertEqual(result, expect)
    }
    
    func eval<T>(_ expr: String) -> T {
        do {
            let expression = AnyExpression(expr)
            return try expression.evaluate()
        } catch {
            XCTFail("Failed with error: \(error)")
            fatalError("Never get here")
        }
    }

}
