//
//  TweeEngineTests.swift
//  TweegeeTests
//
//  Created by Carter Thaxton on 3/6/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import XCTest

class TweeEngineTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }
    
    func testSimpleStory() {
        let story = parse("""
            ::Start
            <<set $x = 1>>
            X = <<$x>>
            Say <<if $x > 2>>Nope<<else>>Yes!!<<endif>>
        """)
        
        let engine = TweeEngine(story: story)
        let action = engine.getNextAction()
        XCTAssertEqual(action, .End)
    }

    // MARK: Helper methods
    
    func parse(_ string : String) -> TweeStory {
        let parser = TweeParser()
        let story = parser.parse(string: string)
        XCTAssert(story.errors.isEmpty, "Errors produced while parsing: \(story.errors)")
        return story
    }
    

}
