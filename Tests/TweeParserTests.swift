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
    override func setUp() {
        continueAfterFailure = false
    }

    func testBasicParse() {
        let story = parse("""
            ::Passage1
            Some text
            Some more text

            ::Passage2
            <<set $test = 5>>
            <<if $test is 5>>Say this<<else>>Don't say this<<endif>>
        """)
        
        XCTAssertEqual(story.passageCount, 2)
        XCTAssertEqual(story.passagesByName["Passage1"]!.location.lineNumber, 1)
        XCTAssertEqual(story.passagesByName["Passage2"]!.location.lineNumber, 5)
        XCTAssertNil(story.passagesByName["Passage1"]!.location.filename)
        XCTAssertNil(story.passagesByName["Passage2"]!.location.filename)
        XCTAssertNil(story.startPassage)

        checkCodeForPassage(story, "Passage1", "TNTN")
        checkCodeForPassage(story, "Passage2", "SI(T:T)N")
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
                    <<if $test > 6>>
                        Not this either [[Passage3]]
                    <<else>>
                        Then this
                    <<endif>>
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

        checkCodeForPassage(story, "Passage1", "SI(TNI(I(T:T)NL:I(TNL:TN)L):L)")

        checkCodeForPassage(story, "Passage2", "TN")
        checkCodeForPassage(story, "Passage3", "TN")
        checkCodeForPassage(story, "Passage4", "TN")
        checkCodeForPassage(story, "Passage5", "TN")
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

        checkCodeForPassage(story, "Start", "C")
        checkCodeForPassage(story, "Passage1", "TN")
        checkCodeForPassage(story, "Passage2", "TN")
    }

    func testSpecialPassages() {
        let story = parse("""
            ::StoryTitle
            The Time Machine

            ::StoryAuthor
            H.G. Wells

            ::Twee2Settings
            @story_start_name = 'TheEnd'

            ::Start
            Not the start

            ::TheEnd
            In the beginning...
        """)
        
        XCTAssertEqual(story.title, "The Time Machine")
        XCTAssertEqual(story.author, "H.G. Wells")
        XCTAssertEqual(story.startPassageName, "TheEnd")
        XCTAssertEqual(story.startPassage?.getSingleTextStatement()?.text, "In the beginning...")
        XCTAssertEqual(story.passageCount, 2)  // after removing special passages, only two passages remain  (Start, TheEnd)
    }
    
    func testInvalidTwee2Settings() {
        checkParserFails("""
            ::Twee2Settings
            @story_start_name = Fail!
        """, expectedError: .InvalidTwee2Settings, lineNumber: 2)
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
        let story = parse("""
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

        checkCodeForPassage(story, "Start", "I(I(TN,TN):TN)TN")
    }

    func testNewlinesAndIfs() {
        let story = parse("""
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
        checkCodeForPassage(story, "Start", "TI(T:T)TNTI(TNTNTNTN:T)TN")
    }
    
    func testSilently() {
        let story = parse("""
            ::Start
            I see <<silently>>nothing should be here<<endsilently>> some text.
        """)

        checkCodeForPassage(story, "Start", "TTN")
        let text1 = story.startPassage!.block.statements[0] as! TweeTextStatement
        let text2 = story.startPassage!.block.statements[1] as! TweeTextStatement
        XCTAssertEqual(text1.text, "I see ")
        XCTAssertEqual(text2.text, " some text.")
    }
    
    func testMissingEndSilently() {
        checkParserFails("""
            ::Start
            I see <<silently>>nothing should be here
            It should fail without endsilently
        """, expectedError: .MissingEndSilently)
    }
    
    func testInclude() {
        let story = parse("""
            ::Start
            Text before
            <<set $a = 2>>
            <<include "Included">>
            Text between
            <<set $a = 7>>
            <<include "Included">>
            Text after

            ::Included
            Text inside the passage
            <<if $x > 5>>
                X is big.
            <<else>>
                X is small.
            <<endif>>
        """)

        checkCodeForPassage(story, "Start", "TNSUTNSUTN")
        checkCodeForPassage(story, "Included", "TNI(TN:TN)")
    }
    
    func testDelay() {
        let story = parse("""
            ::Start
            Text
            <<delay "10m">>I'm waiting for you<<enddelay>>
            More text
            Before delay <<delay "10s">>In the delay<<enddelay>> After delay
        """)

        checkCodeForPassage(story, "Start", "TND(T)TNTND(T)TN")  // Note that it adds a newline after "Before delay"
        let delayStmt = story.startPassage!.block.statements[2] as! TweeDelayStatement
        XCTAssertEqual(delayStmt.expression.string, "\"10m\"")
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
        
        func checkTwoChoices(_ name: String) {
            guard let passage = story.passagesByName[name] else {
                return XCTFail("No passage named \(name)")
            }

            let stmts = passage.block.statements
            XCTAssertEqual(stmts.count, 1)
            
            guard let choice = stmts.first as? TweeChoiceStatement else {
                return XCTFail("No choice statement")
            }
            XCTAssertEqual(choice.choices.count, 2)

            let link1 = choice.choices[0]
            XCTAssertEqual(link1.name, "choice1")
            XCTAssertNil(link1.title)

            let link2 = choice.choices[1]
            XCTAssertEqual(link2.name, "choice2")
            XCTAssertEqual(link2.title, "Choice 2")
        }

        checkTwoChoices("ChoicesAsLinks")
        checkTwoChoices("ChoicesAsMacros")
        checkTwoChoices("ChoicesMixed1")
        checkTwoChoices("ChoicesMixed2")
    }
    
    func testInvalidChoice() {
        checkParserFails("""
            ::Passage1
            Some text
            <<choice [[Missing close|missing]] | <<choice [[This is ok|itsok]]>>
        """, expectedError: .InvalidChoiceSyntax, lineNumber: 3)
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
    
    func checkCodeForPassage(_ story: TweeStory, _ passageName: String, _ pattern: String) {
        guard let passage = story.passagesByName[passageName] else {
            return XCTFail("Did not find passage named \(passageName)")
        }
        let actual = codeBlockToPattern(passage.block)
        XCTAssertEqual(actual, pattern)
    }

    // Creates a pattern like "STNTNI(S,TN:TNTN)"
    func codeBlockToPattern(_ block: TweeCodeBlock) -> String {
        var result = ""
        for stmt in block.statements {
            switch stmt {
            case is TweeNewlineStatement:
                result += "N"
            case is TweeTextStatement:
                result += "T"
            case is TweeSetStatement:
                result += "S"
            case is TweeExpressionStatement:
                result += "E"
            case is TweeLinkStatement:
                result += "L"
            case is TweeChoiceStatement:
                result += "C"
            case is TweeIncludeStatement:
                result += "U"
            case let delayStmt as TweeDelayStatement:
                result += "D("
                result += codeBlockToPattern(delayStmt.block)
                result += ")"
            case let ifStmt as TweeIfStatement:
                result += "I("
                result += ifStmt.clauses.map({ codeBlockToPattern($0.block) }).joined(separator: ",")
                if let elseClause = ifStmt.elseClause {
                    result += ":" + codeBlockToPattern(elseClause.block)
                }
                result += ")"
            default:
                fatalError("Unexpected type of statement: \(stmt)")
            }
        }
        return result
    }
    
}
