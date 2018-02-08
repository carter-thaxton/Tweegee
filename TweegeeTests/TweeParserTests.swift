//
//  TweeParserTests.swift
//  TweegeeTests
//
//  Created by Carter Thaxton on 2/7/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import XCTest

class TweeParserTests: XCTestCase {
    
    func testParse() {
        let story = parse("""
            ::Passage1
            <<let $test = 5>>
            <<if $test is 5>>Say this<<else>>Don't say this<<endif>>

            ::Passage2
            Some more text
        """)
        
        XCTAssertEqual(story.passages.count, 2)
        XCTAssertEqual(story.passages["Passage1"]!.location.lineNumber, 1)
        XCTAssertEqual(story.passages["Passage2"]!.location.lineNumber, 5)
        XCTAssertNil(story.passages["Passage1"]!.location.filename)
        XCTAssertNil(story.passages["Passage2"]!.location.filename)
    }

    func testTextOutsidePassage() {
        checkParseFails("Some text", expectedError: TweeError.TextOutsidePassage, lineNumber: 1)
    }
    
    
    // MARK: Helper methods

    func parse(_ string : String) -> TweeStory {
        let parser = TweeParser()
        return try! parser.parse(string: string)
    }

    func checkParseFails(_ string: String, expectedError: TweeError? = nil, lineNumber: Int? = nil) {
        let parser = TweeParser()
        do {
            let _ = try parser.parse(string: string)
        } catch let error as TweeErrorLocation {
            if expectedError != nil {
                XCTAssertEqual(error.error as! TweeError, expectedError!)
            }
            if lineNumber != nil {
                XCTAssertEqual(error.location.lineNumber, lineNumber)
            }
            return
        } catch {
            XCTFail("Unexpected error thrown from parser")
        }
        XCTFail("Expected parser to throw an error")
    }

}
