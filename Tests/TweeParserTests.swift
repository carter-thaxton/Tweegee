//
//  TweeParserTests.swift
//  TweegeeTests
//
//  Created by Carter Thaxton on 2/7/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import XCTest

class TweeParserTests: XCTestCase {
    
    func testBasicParse() {
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
        XCTAssertNil(story.startPassage)
    }

    func testNestedStatements() {
        let story = parse("""
            ::Passage1
            <<let $test = 5>>
            <<if $test is 5>>
                Say this
                <<if $test < 10>>
                    <<if $test > 6>>Not this<<else>>Then this<<endif>>
                    [[Passage2]]
                <<else>>
                    <<if $test > 6>>Not this either [[Passage3]]<<else>>Then this<<endif>>
                    [[Passage4]]
            <<else>>
                [[Passage5]]
            <<endif>>

            ::Passage2
            After nested if

            ::Passage3
            After nested else and if

            ::Passage4
            After nested else and fallthrough else

            ::Passage5
            After outer else
        """)

        XCTAssertEqual(story.passages.count, 5)
        XCTAssertNil(story.startPassage)
    }
    
    func testStartPassage() {
        let story = parse("""
            ::Start
            [[Choose 1|Passage1]] | [[or 2|Passage2]]

            ::Passage1
            Chose 1

            ::Passage2
            Chose 2
        """)
        
        XCTAssertEqual(story.passages.count, 3)
        XCTAssertNotNil(story.startPassage)
        XCTAssertEqual(story.startPassage!.name, "Start")
    }

    func testTextOutsidePassage() {
        checkParserFails("""
            Some text
        """, expectedError: .TextOutsidePassage, lineNumber: 1)
    }
    
    func testBadLexInParser() {
        checkParserFails("""
            ::Passage
            [[OK]]
            [[OK|Also]]
            [[Too|many|words]]
        """, expectedError: .InvalidLinkSyntax, lineNumber: 4)
    }
    
    
    // MARK: Helper methods

    func parse(_ string : String) -> TweeStory {
        let parser = TweeParser()
        return try! parser.parse(string: string)
    }

    func checkParserFails(_ string: String, expectedError: TweeError? = nil, lineNumber: Int? = nil) {
        let parser = TweeParser()
        do {
            let _ = try parser.parse(string: string)
        } catch let error as TweeErrorLocation {
            if expectedError != nil {
                XCTAssertEqual(error.error, expectedError!)
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
