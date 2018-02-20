//
//  TweeParserTests.swift
//  TweegeeTests
//
//  Created by Carter Thaxton on 2/7/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import XCTest

// Helper functions to aid testing
extension TweeStory {
    var firstPassage : TweePassage {
        return passagesInOrder[0]
    }
    
    var secondPassage : TweePassage {
        return passagesInOrder[1]
    }
}

class TweeParserTests: XCTestCase {
    
    func testBasicParse() {
        let story = parse("""
            ::Passage1
            <<set $test = 5>>
            <<if $test is 5>>Say this<<else>>Don't say this<<endif>>

            ::Passage2
            Some more text
        """)
        
        XCTAssertEqual(story.passageCount, 2)
        XCTAssertEqual(story.passagesByName["Passage1"]!.location.lineNumber, 1)
        XCTAssertEqual(story.passagesByName["Passage2"]!.location.lineNumber, 5)
        XCTAssertNil(story.passagesByName["Passage1"]!.location.filename)
        XCTAssertNil(story.passagesByName["Passage2"]!.location.filename)
        XCTAssertNil(story.startPassage)
    }

    func testNestedStatements() {
        let story = parse("""
            ::Passage1
            <<set $test = 5>>
            <<if $test is 5>>
                Say this
                <<if $test < 10>>
                    <<if $test > 6>>Not this<<else>>Then this<<endif>>
                    [[Passage2]]
                <<else>>
                    <<if $test > 6>>Not this either [[Passage3]]<<else>>Then this<<endif>>
                    [[Passage4]]
                <<endif>>
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

        XCTAssertEqual(story.passageCount, 5)
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
        
        XCTAssertEqual(story.passageCount, 3)
        XCTAssertNotNil(story.startPassage)
        XCTAssertEqual(story.startPassage!.name, "Start")
        XCTAssert(story.firstPassage === story.startPassage)
    }

    func testTextOutsidePassage() {
        checkParserFails("""
            Some text
        """, expectedError: .TextOutsidePassage, lineNumber: 1)
    }
    
    func testBadLexInParser() {
        checkParserFails("""
            ::Start
            [[OK]]
            [[OK|Also]]
            [[Too|many|words]]
        """, expectedError: .InvalidLinkSyntax, lineNumber: 4)
    }
    
    func testUnmatchedIf() {
        checkParserFails("""
            ::Start
            Some text
            <<if true>>
        """, expectedError: .MissingEndIf, lineNumber: 3)
    }

    func testUnmatchedIfAtPassage() {
        checkParserFails("""
            ::Start
            Some text
            <<if true>>

            ::NextPassage
        """, expectedError: .MissingEndIf, lineNumber: 3)
    }
    
    func testUnmatchedIfWithElseIf() {
        checkParserFails("""
            ::Start
            Some text
            <<if true>>
            <<elseif true>>
        """, expectedError: .MissingEndIf, lineNumber: 3)
    }
    
    func testUnmatchedIfWithElseIfAndElse() {
        checkParserFails("""
            ::Start
            Some text
            <<if true>>
            <<elseif true>>
            <<else>>
        """, expectedError: .MissingEndIf, lineNumber: 3)
    }
    
    func testUnmatchedElse() {
        checkParserFails("""
            ::Start
            Some text
            <<else>>
        """, expectedError: .MissingIf, lineNumber: 3)
    }

    func testUnmatchedEndIf() {
        checkParserFails("""
            ::Start
            Some text
            <<endif>>
        """, expectedError: .MissingIf, lineNumber: 3)
    }

    func testDuplicateElse() {
        checkParserFails("""
            ::Start
            <<if true>>
                OK
            <<else>>
                OK2
            <<else>>
                Dupe
            <<endif>>
        """, expectedError: .DuplicateElse, lineNumber: 6)
    }
    
    func testElseIfAfterElse() {
        checkParserFails("""
            ::Start
            <<if true>>
                OK
            <<else>>
                OK2
            <<elseif true>>
                Dupe
            <<endif>>
        """, expectedError: .DuplicateElse, lineNumber: 6)
    }

    func testNestedIfs() {
        let _ = parse("""
            ::Start
            <<if true>>
                <<if false>>
                Not here
                <<elseif true>>
                YES
                <<endif>>
            <<else>>
                Not here either
            <<endif>>
            Some final words
        """)
    }
    
    func testNewlinesAndIfs() {
        let _ = parse("""
            ::Start
            I see <<if $x>>a bird<<else>>nothing<<endif>>.
            On the horizon, I see <<if $y>>a...
            really...
            big...
            elephant!
            <<else>>just a smudge<<endif>>.
        """)
        
        // I see a bird.
        // I see nothing.
        // On the horizon, I see a...
        // really...
        // big...
        // elephant!
        // On the horizon, I see just a smudge.
//        XCTFail("TODO")
    }
    
    func testChoiceSyntax() {
        let story = parse("""
            ::Start
            Some text

            ::ChoicesAsLinks
            [[choice1]] | [[Choice 2|choice2]]

            ::ChoicesAsMacros
            <<choice [[choice1]]>> | <<choice [[Choice 2|choice2]]>>

            ::ChoicesMixed1
            <<choice [[choice1]]>> | [[Choice 2|choice2]]

            ::ChoicesMixed2
            [[choice1]] | <<choice [[Choice 2|choice2]]>>
        """)
        
        func checkTwoChoices(_ passage: TweePassage) {
            let stmts = passage.block.statements
            XCTAssertEqual(stmts.count, 1)
            
            let choice = stmts[0] as? TweeChoiceStatement
            XCTAssertNotNil(choice)
            XCTAssertEqual(choice!.choices.count, 2)
            
            let link1 = choice!.choices[0]
            XCTAssertEqual(link1.name, "choice1")
            XCTAssertNil(link1.title)

            let link2 = choice!.choices[1]
            XCTAssertEqual(link2.name, "choice2")
            XCTAssertEqual(link2.title, "Choice 2")
        }

        checkTwoChoices(story.passagesByName["ChoicesAsLinks"]!)
        checkTwoChoices(story.passagesByName["ChoicesAsMacros"]!)
        checkTwoChoices(story.passagesByName["ChoicesMixed1"]!)
        checkTwoChoices(story.passagesByName["ChoicesMixed2"]!)
    }
    
    func testInvalidChoice() {
        checkParserFails("""
            ::Passage1
            Some text
            <<choice [[Missing close|missing]] | <<choice [[This is ok|itsok]]>>
        """, expectedError: .InvalidChoiceSyntax, lineNumber: 3)
    }
    
    func testSpecialPassages() {
        let story = parse("""
            ::StoryTitle
            The Time Machine

            ::StoryAuthor
            H.G. Wells

            ::Twee2Settings
            @story_start_name = 'TheEnd'

            ::TheEnd
            In the beginning...
        """)
        
        XCTAssertEqual(story.title, "The Time Machine")
        XCTAssertEqual(story.author, "H.G. Wells")
        XCTAssertEqual(story.startPassageName, "TheEnd")
        XCTAssertEqual(story.startPassage?.getSingleTextStatement()?.text, "In the beginning...")
        XCTAssertEqual(story.passageCount, 1)  // after removing special passages, only one passage remains
    }

    func testInvalidTwee2Settings() {
        checkParserFails("""
            ::Twee2Settings
            @story_start_name = Fail!
        """, expectedError: .InvalidTwee2Settings, lineNumber: 2)
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
