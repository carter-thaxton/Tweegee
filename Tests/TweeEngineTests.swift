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
    
    func testLooping() {
        let result = interpret("""
            ::Start
            <<set $x = 1>>
            [[Loop]]

            ::Loop
            X = <<$x>>
            That's <<if $x > 2>>big<<else>>small<<endif>>
            <<if $x < 4>>
                <<set $x = $x + 1>>
                [[Loop]]
            <<else>>
                Done
            <<endif>>
        """)

        XCTAssertEqual(result, [
            .Message(text: "X = 1"),
            .Message(text: "That's small"),
            .Message(text: "X = 2"),
            .Message(text: "That's small"),
            .Message(text: "X = 3"),
            .Message(text: "That's big"),
            .Message(text: "X = 4"),
            .Message(text: "That's big"),
            .Message(text: "Done"),
            .End
        ])
    }

    func testInclude() {
        let result = interpret("""
            ::Start
            <<set $x = 1>>
            <<include "showX">>
            <<set $x = 2>>
            <<include "showX">>
            Done

            ::showX
            X = <<$x>>
        """)
        
        XCTAssertEqual(result, [
            .Message(text: "X = 1"),
            .Message(text: "X = 2"),
            .Message(text: "Done"),
            .End
            ])
    }
    
    // MARK: Helper methods
    
    func parse(_ string : String) -> TweeStory {
        let parser = TweeParser()
        let story = parser.parse(string: string)
        XCTAssert(story.errors.isEmpty, "Errors produced while parsing: \(story.errors)")
        return story
    }
    
    typealias Interpreter = (TweeAction) -> TweeChoice?
    
    func interpret(_ string : String, block: Interpreter = { _ in nil } ) -> [TweeAction] {
        let story = parse(string)
        let engine = TweeEngine(story: story)
        return interpret(engine: engine, block: block)
    }

    func interpret(engine: TweeEngine, block: Interpreter = { _ in nil } ) -> [TweeAction] {
        let maxActions = 100
        var result = [TweeAction]()

        loop: repeat {
            let action = engine.getNextAction()
            result.append(action)

            let choice = block(action)

            switch action {
            case .Choice:
                if choice == nil {
                    XCTFail("Must make a choice when action is choice")
                } else {
                    engine.makeChoice(choice!)
                }

            case .End, .Error:
                break loop

            default:
                if choice != nil {
                    XCTFail("Cannot make a choice unless action is choice: \(action)")
                }
            }
        } while result.count < maxActions

        XCTAssert(result.count < maxActions, "Reached \(result.count) actions without finishing story")
        
        return result
    }

}
