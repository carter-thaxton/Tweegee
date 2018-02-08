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

    func parse(_ string : String) -> TweeStory {
        let p = TweeParser()
        return try! p.parse(string: string)
    }

}
