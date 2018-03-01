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
    
    func testNormalizeExpression() {
        let str = TweeExpression.normalize("(a or b) and not (5 gt 6)")
        XCTAssertEqual(str, "(a || b) && ! (5 > 6)")
    }
    
    func testBasicExpression() throws {
        checkEvalAsString("'a' + 5", expect: "a5")
        checkEvalAsInt("6 + 5", expect: 11)
        checkEvalAsBool("false || true", expect: true)
    }


    func checkEvalAsString(_ expr: String, expect: String) {
        let result = eval(expr) as String
        XCTAssertEqual(result, expect)
    }

    func checkEvalAsBool(_ expr: String, expect: Bool) {
        let result = eval(expr) as Bool
        XCTAssertEqual(result, expect)
    }
    
    func checkEvalAsInt(_ expr: String, expect: Int) {
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
