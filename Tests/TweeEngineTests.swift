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

        checkActions(result, [
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
        
        checkActions(result, [
            .Message(text: "X = 1"),
            .Message(text: "X = 2"),
            .Message(text: "Done"),
            .End
        ])
    }
    
    func testDelay() {
        let result = interpret("""
            ::Start
            <<delay 20m>>Twenty minutes<<enddelay>>
            <<delay "1h">>One hour<</delay>>
            <<delay 5s>><<enddelay>>  // no text
            [[delay 10s|Next]]

            ::Next
            After 10 seconds
        """)
        
        checkActions(result, [
            .Delay(text: "Twenty minutes", delay: TweeDelay(fromString: "20m")!),
            .Delay(text: "One hour", delay: TweeDelay(fromString: "1h")!),
            .Delay(text: "[Waiting]", delay: TweeDelay(fromString: "5s")!),
            .Delay(text: "[Waiting]", delay: TweeDelay(fromString: "10s")!),
            .Message(text: "After 10 seconds"),
            .End
        ])
    }
    
    func testChoice() {
        let result = interpret("""
            ::Start
            What next?
            [[Pick me]] | [[Not this]]

            ::Pick me
            Correct!
            [[Maybe?|maybe]] | [[Definitely!|definitely]]

            ::Not this
            No!!!

            ::maybe
            Wrong

            ::definitely
            Yes!
            <<choice [[Right|theend]]>> | <<choice [["Really?" what's up?|whatsup]]>>

            ::theend
            All good

            ::whatsup
            No!!!
        """, choose: ["Pick me", "definitely", "theend"])
        
        checkActions(result, [
            .Message(text: "What next?"),
            .Choice(choices: [TweeChoice(name: "Pick me", title: "Pick me"), TweeChoice(name: "Not this", title: "Not this")]),
            .Message(text: "Correct!"),
            .Choice(choices: [TweeChoice(name: "maybe", title: "Maybe?"), TweeChoice(name: "definitely", title: "Definitely!")]),
            .Message(text: "Yes!"),
            .Choice(choices: [TweeChoice(name: "theend", title: "Right"), TweeChoice(name: "whatsup", title: "\"Really?\" what's up?")]),
            .Message(text: "All good"),
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
    
    func interpret(_ string : String, choose: [String] = []) -> [TweeAction] {
        let story = parse(string)
        let engine = TweeEngine(story: story)
        return interpret(engine: engine, choose: choose)
    }

    func interpret(engine: TweeEngine, choose: [String] = []) -> [TweeAction] {
        let maxActions = 100
        var result = [TweeAction]()
        var chooseIndex = 0

        do {
            repeat {
                let action = try engine.getNextAction()
                result.append(action)
                
                // handle choice
                if case .Choice(choices: let choices) = action {
                    XCTAssert(chooseIndex < choose.count, "Reached an unexpected choice: \(choices)")
                    let name = choose[chooseIndex]
                    try engine.makeChoice(name: name)
                    chooseIndex += 1
                }

                if case .End = action { break }
            } while result.count < maxActions

            XCTAssert(result.count < maxActions, "Reached \(result.count) actions without finishing story")
            XCTAssertEqual(chooseIndex, choose.count, "Did not use all provided choices")
        } catch {
            XCTFail("TweeEngine failed with: \(error)")
        }
        
        return result
    }

    func checkActions(_ actual: [TweeAction], _ expected: [TweeAction]) {
        for i in 0..<min(actual.count, expected.count) {
            let a = actual[i]
            let e = expected[i]
            XCTAssertEqual(a, e)
        }
        XCTAssertEqual(actual.count, expected.count)
    }

}
