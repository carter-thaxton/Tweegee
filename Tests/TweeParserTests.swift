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

            ::Start
            Some text
            Some more text
            [[Passage2]]


            ::Passage2
            <<set $test = 5>>
            <<if $test is 5>>Say this<<else>>Don't say this<<endif>>

        """)
        
        XCTAssertEqual(story.passageCount, 2)
        XCTAssertEqual(story.passagesByName["Start"]!.location.fileLineNumber, 2)
        XCTAssertEqual(story.passagesByName["Passage2"]!.location.fileLineNumber, 8)
        XCTAssertNil(story.passagesByName["Start"]!.location.filename)
        XCTAssertNil(story.passagesByName["Passage2"]!.location.filename)
        XCTAssertNotNil(story.startPassage)

        checkCodeForPassage(story, "Start", "TNTNL")
        checkCodeForPassage(story, "Passage2", "SI(T:T)N")
        
        XCTAssertEqual(story.startPassage!.rawTwee.count, 4)
        XCTAssertEqual(story.passagesByName["Passage2"]!.rawTwee.count, 3)
    }
    
    func testNestedStatements() {
        let story = parse("""
            ::Start
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
        XCTAssertNotNil(story.startPassage)

        checkCodeForPassage(story, "Start", "SI(TNI(I(T:T)NL:I(TNL:TN)L):L)")

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


    func testMissingStartPassage() {
        let story = checkParserFails("""
            ::Passage1
            Some text
        """, expectedError: .MissingPassage)

        XCTAssertEqual(story.passageCount, 1)
        XCTAssertNil(story.startPassage)
    }

    func testDuplicatePassages() {
        let story = parse("""
            ::Passage1
            Some text

            ::Passage2
            Some other text

            ::Passage1
            Uh oh!
        """, allowErrors: true)
        
        checkError(story: story, expectedError: .DuplicatePassageName, lineNumber: 7)
    }
    
    func testSpecialPassages() {
        let story = parse("""
            ::StoryTitle
            The Time Machine

            ::StoryAuthor
            H.G. Wells

            ::Twee2Settings
            @story_start_name = 'TheEnd'

            ::StoryAuthor
            Jules Verne

            ::Start
            Not the start

            ::TheEnd
            In the beginning...
        """, allowErrors: true)
        
        XCTAssertEqual(story.title, "The Time Machine")
        XCTAssertEqual(story.author, "H.G. Wells")  // Not Jules Verne
        XCTAssertEqual(story.startPassageName, "TheEnd")
        XCTAssertEqual(story.startPassage?.getSingleTextStatement()?.text, "In the beginning...")
        XCTAssertEqual(story.passageCount, 2)  // after removing special passages, including the bogus StoryAuthor, only two passages remain  (Start, TheEnd)

        checkError(story: story, expectedError: .DuplicatePassageName, lineNumber: 10)
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
            <<set $x = false>>
            <<set $y = true>>
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
        checkCodeForPassage(story, "Start", "SSTI(T:T)TNTI(TNTNTNTN:T)TN")
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
            <<set $x = 2>>
            <<include "Included">>
            Text between
            <<set $x = 7>>
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
        
        let includeStmt1 = story.startPassage!.block.statements[3] as! TweeIncludeStatement
        let includeStmt2 = story.startPassage!.block.statements[7] as! TweeIncludeStatement
        XCTAssertEqual(includeStmt1.passage, "Included")
        XCTAssertEqual(includeStmt2.passage, "Included")
    }
    
    func testDynamicLinks() {
        let story = parse("""
            ::Start
            Text before
            <<set $next = "Passage1">>
            <<include $next>>
            <<set $next = "Passage2">>
            [[$next]]

            ::Passage1 [noreferror]
            Included

            ::Passage2 [noreferror]
            Linked
        """)
        
        checkCodeForPassage(story, "Start", "TNSUSL")
        checkCodeForPassage(story, "Passage1", "TN")
        checkCodeForPassage(story, "Passage2", "TN")

        let includeStmt = story.startPassage!.block.statements[3] as! TweeIncludeStatement
        let linkStmt = story.startPassage!.block.statements[5] as! TweeLinkStatement
        XCTAssertTrue(includeStmt.isDynamic)
        XCTAssertEqual(includeStmt.expression!.string, "$next")
        XCTAssert(includeStmt.expression!.variables.contains("$next"))
        XCTAssertTrue(linkStmt.isDynamic)
        XCTAssertEqual(linkStmt.expression!.string, "$next")
        XCTAssert(linkStmt.expression!.variables.contains("$next"))
    }
    
    func testUndefinedVariableInLink() {
        checkParserFails("""
            ::Start
            [[$shoulderror]]
        """, expectedError: .UndefinedVariable, lineNumber: 2)
    }
    
    func testDelayParsing() {
        XCTAssertNil(TweeDelay(fromString: "junk"))
        XCTAssertNil(TweeDelay(fromString: "10"))
        XCTAssertNil(TweeDelay(fromString: "s"))
        XCTAssertNil(TweeDelay(fromString: "10ss"))
        XCTAssertNil(TweeDelay(fromString: " 10s "))  // not even whitespace

        XCTAssertEqual(TweeDelay(fromString: "10s")?.seconds, 10)
        XCTAssertEqual(TweeDelay(fromString: "3m")?.seconds, 180)
        XCTAssertEqual(TweeDelay(fromString: "2h")?.seconds, 7200)
    }
    
    func testDelayStatement() {
        let story = parse("""
            ::Start
            Text
            <<delay "10m">>I'm waiting for you<<enddelay>>
            More text
            Before delay <<delay "10s">>In the delay<<enddelay>> After delay
        """)

        checkCodeForPassage(story, "Start", "TND(T)TNTND(T)TN")  // Note that it adds a newline after "Before delay"
        let delayStmt = story.startPassage!.block.statements[2] as! TweeDelayStatement
        XCTAssertEqual(delayStmt.delay.string, "10m")
    }

    func testDelayLinks() {
        let story = parse("""
            ::Start
            Text before delay
            [[delay 10m|Passage2]]

            ::Passage2
            After delay
        """)
        
        checkCodeForPassage(story, "Start", "TND()L")  // Link with delay results in empty delay, then link
        let delayStmt = story.startPassage!.block.statements[2] as! TweeDelayStatement
        XCTAssertEqual(delayStmt.delay.string, "10m")
        XCTAssertEqual(delayStmt.block.statements.count, 0)
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

            ::choice1

            ::choice2
        """, ignoreErrors: [.UnreferencedPassage])
        
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
            XCTAssertEqual(link1.passage, "choice1")
            XCTAssertNil(link1.title)

            let link2 = choice.choices[1]
            XCTAssertEqual(link2.passage, "choice2")
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
    
    func testExpressionStatements() {
        let story = parse("""
            ::Start
            <<set $x = 5>>
            <<set $y = 'foo'>>
            <<set $z = true>>
            Some text with <<$x>> or <<= $y>> or <<- $z>> or <<print $x>>
            // TODO: this doesn't work:  <<=$x>> or <<-$x>>
        """)

        checkCodeForPassage(story, "Start", "SSSTETETETEN")
    }
    
    // MARK: Helper methods

    func parse(_ string : String, allowErrors: Bool = false, ignoreErrors: [TweeErrorType] = []) -> TweeStory {
        let parser = TweeParser()
        let story = parser.parse(string: string)

        if !allowErrors {
            let errors = story.errors.filter { !ignoreErrors.contains($0.type) }
            XCTAssert(errors.isEmpty, "Errors produced while parsing: \(errors)")
        }
        return story
    }

    func checkError(story: TweeStory, expectedError: TweeErrorType? = nil, lineNumber: Int? = nil) {
        if let error = story.errors.first {
            if expectedError != nil {
                XCTAssertEqual(error.type, expectedError!)
            }
            if lineNumber != nil {
                XCTAssertEqual(error.location?.fileLineNumber, lineNumber)
            }
            return
        } else {
            XCTFail("Expected parser to produce an error")
        }
    }
    
    @discardableResult func checkParserFails(_ string: String, expectedError: TweeErrorType? = nil, lineNumber: Int? = nil) -> TweeStory {
        let story = parse(string, allowErrors: true)
        checkError(story: story, expectedError: expectedError, lineNumber: lineNumber)
        return story
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
            case is TweeIncludeStatement:
                result += "U"
            case is TweeLinkStatement:
                result += "L"
            case is TweeChoiceStatement:
                result += "C"
            case let delayStmt as TweeDelayStatement:
                result += "D("
                result += codeBlockToPattern(delayStmt.block)
                result += ")"
            case let ifStmt as TweeIfStatement:
                result += "I("
                for (index, clause) in ifStmt.clauses.enumerated() {
                    if clause.condition == nil {
                        result += ":"  // else
                    } else if index > 0 {
                        result += ","  // elseif
                    }
                    result += codeBlockToPattern(clause.block)
                }
                result += ")"
            default:
                fatalError("Unexpected type of statement: \(stmt)")
            }
        }
        return result
    }
    
}
