//
//  TweeExpressionTests.swift
//  TweegeeTests
//
//  Created by Carter Thaxton on 2/28/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import XCTest

class TweeExpressionTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }
    
    func testNormalizeExpression() {
        let e1 = TweeExpression("($a or $b) and not (5 gt 6)")
        XCTAssertEqual(e1.string, "($a || $b) && ! (5 > 6)")
        XCTAssertNil(e1.error)
    }
    
    func testExpressions() {
        checkExpression("$a gt 2", variables: ["$a": 3], expectBool: true)
        checkExpression("$a gt 2 and $a neq 6", variables: ["$a": 3], expectBool: true)
    }
    
    func testBooleanConversion() {
        // Ints can be used as bools, 0 is false, others true
        checkExpression("$a", variables: ["$a": 0], expectBool: false)
        checkExpression("$a", variables: ["$a": 3], expectBool: true)
        checkExpression("!$a", variables: ["$a": 0], expectBool: true)
        checkExpression("!$a", variables: ["$a": 3], expectBool: false)

        // Can't use strings as bools
        checkExpressionFails("$a", variables: ["$a": "foo"],
                             message: "Result type String is not compatible with expected type Bool")
        checkExpressionFails("!$a", variables: ["$a": "foo"],
                             message: "Argument of type String is not compatible with prefix operator !")
    }
    
    func testFunctions() {
        checkExpression("visited()", expectBool: false)
        checkExpression("visited('passage')", expectBool: false)
        checkExpressionFails("visited('passage', 'passage2')", message: "visited() function takes 0 or 1 arguments")
        checkExpressionFails("visited2()", message: "Invalid function: visited2")
        checkExpressionFails("either()", message: "either() function requires at least 1 argument")
    }
    
    func testEither() throws {
        let e = TweeExpression("either(5,6,7)")
        XCTAssertNil(e.error)
        let result = try e.eval() as Int
        XCTAssert(result >= 5 && result <= 7)
    }
    
    func testSyntaxError() {
        let e2 = TweeExpression("(junk*")
        XCTAssertEqual(e2.error?.message, "Missing `)`")
    }
    
    
    func checkExpression(_ expr: String, variables: [String:Any] = [:], expectInt: Int) {
        let e = TweeExpression(expr)
        XCTAssertNil(e.error)
        do {
            let result = try e.eval(variables: variables) as Int
            XCTAssertEqual(result, expectInt)
        } catch {
            XCTFail("eval() failed: \(error)")
        }
    }
    
    func checkExpression(_ expr: String, variables: [String:Any] = [:], expectBool: Bool) {
        let e = TweeExpression(expr)
        XCTAssertNil(e.error)
        do {
            let result = try e.eval(variables: variables) as Bool
            XCTAssertEqual(result, expectBool)
        } catch {
            XCTFail("eval() failed: \(error)")
        }
    }
    
    func checkExpressionFails(_ expr: String, variables: [String:Any] = [:], message: String? = nil) {
        let e = TweeExpression(expr)
        do {
            let _ = try e.eval(variables: variables) as Bool
            XCTFail("Expected expression to fail: \(expr)")
        } catch let error as TweeError {
            if message != nil {
                XCTAssertEqual(error.message, message)
            }
        } catch {
            XCTFail("Unexpected exception from eval(): \(error)")
        }
    }
}
