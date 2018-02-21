//
//  TweeParser.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/7/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

class TweeParser {

    // MARK: Properties

    let lexer = TweeLexer()
    let story = TweeStory()
    var currentPassage : TweePassage?
    var numTokensParsed = 0
    var lineHasText = false

    var currentStatements = [NestableStatement]()
    var currentStatement : NestableStatement? { return currentStatements.last }
    var currentCodeBlock : TweeCodeBlock? { return currentStatement?.block }

    // MARK: Public Methods

    func parse(filename: String) throws -> TweeStory {
        try lexer.lex(filename: filename, block: handleToken)
        return try finish()
    }

    func parse(string: String) throws -> TweeStory {
        try lexer.lex(string: string, block: handleToken)
        return try finish()
    }
    
    func parse(expression: String?, location: TweeLocation, for macro: String) throws -> TweeExpression {
        guard let expression = expression else {
            throw TweeErrorLocation(error: .MissingExpression, location: location, message: "Missing expression for \(macro)")
        }
        // TODO: finish this
        return TweeExpression(from: expression)
    }

    // MARK: Parser Implementation

    private func finish() throws -> TweeStory {
        try closePassageAndEnsureNoOpenStatements()
        try parseSpecialPassages()
        return story
    }

    private func parseSpecialPassages() throws {
        // ::StoryTitle
        // Title of Story
        if let titlePassage = story.removePassage(name: "StoryTitle") {
            if let title = titlePassage.getSingleTextStatement()?.text {
                story.title = title
            }
        }

        // ::StoryAuthor
        // Author of Story
        if let authorPassage = story.removePassage(name: "StoryAuthor") {
            if let author = authorPassage.getSingleTextStatement()?.text {
                story.author = author
            }
        }
        
        // ::Twee2Settings
        // @story_start_name = 'Start'
        if let twee2SettingsPassage = story.removePassage(name: "Twee2Settings") {
            if let settings = twee2SettingsPassage.getSingleTextStatement() {
                if let result = settings.text.match(pattern: "^@story_start_name\\s*=\\s*['\"]([^.\"]*)['\"];?$") {
                    story.startPassageName = result[1]!
                } else {
                    throw TweeErrorLocation(error: .InvalidTwee2Settings, location: settings.location, message: "@story_start_name found in Twee2Settings passage, but has invalid syntax")
                }
            }
        }
    }

    private func closePassageAndEnsureNoOpenStatements() throws {
        if let stmt = currentStatement {
            if stmt is TweePassage {
                if currentStatements.count != 1 {
                    fatalError("TweePassage found in nested position")
                }
                // ok to have open passage, but close it now
                currentPassage = nil
                currentStatements.removeAll()
            }
            else if stmt is TweeIfStatement {
                throw TweeErrorLocation(error: .MissingEndIf, location: stmt.location, message: "Passage ended without closing endif")
            } else {
                fatalError("Unexpected type of open statement: \(stmt)")
            }
        }
    }

    private func handleToken(token: TweeToken, location: TweeLocation) throws {
        numTokensParsed += 1
        
        func ensureCodeBlock() throws {
            if currentPassage == nil || currentCodeBlock == nil {
                throw TweeErrorLocation(error: .TextOutsidePassage, location: location, message: "No text is allowed outside of a passage")
            }
        }
        
        switch token {

        case .Passage(let name, let tags, let position):
            try closePassageAndEnsureNoOpenStatements()

            currentPassage = TweePassage(location: location, name: name, position: position, tags: tags)
            currentStatements.append(currentPassage!)
            try story.addPassage(passage: currentPassage!)
            lineHasText = false  // by definition, starts a new line

        case .Comment(let comment):
            // ignore comments
            _ = comment
            break

        case .Newline:
            endLineOfText(location: location)

        case .Text(let text):
            try ensureCodeBlock()
            
            // Special case for | separating links
            if text.trimmingWhitespace() == "|" {
                if let link = currentCodeBlock?.last as? TweeLinkStatement {
                    // convert previous link to list of choices
                    currentCodeBlock!.pop()
                    let stmt = TweeChoiceStatement(location: link.location)
                    stmt.choices.append(link)
                    currentCodeBlock!.add(stmt)
                } else if let choices = currentCodeBlock?.last as? TweeChoiceStatement {
                    // already a list of choices, simply ignore the |
                    _ = choices
                }
            } else {
                let stmt = TweeTextStatement(location: location, text: text)
                currentCodeBlock!.add(stmt)
                lineHasText = true  // add some text to line
            }

        case .Link(let name, let title):
            try ensureCodeBlock()
            let stmt = TweeLinkStatement(location: location, name: name, title: title)

            // check if link is part of a list of choices
            if let choiceStmt = currentCodeBlock!.last as? TweeChoiceStatement {
                choiceStmt.choices.append(stmt)
            } else {
                endLineOfText(location: location)  // end any text before following a link
                currentCodeBlock!.add(stmt)
            }

        case .Macro(let name, let expr):
            try ensureCodeBlock()
            if name == nil {
                // raw expression used in macro
                let expression = try parse(expression: expr, location: location, for: "exprStmt")
                let exprStmt = TweeExpressionStatement(location: location, expression: expression)
                currentCodeBlock!.add(exprStmt)
            } else {
                switch name! {
                case "if", "else", "elseif", "endif", "/if":
                    try parseIf(name: name!, expr: expr, location: location)

                case "delay", "enddelay", "/delay":
                    try parseDelay(name: name!, expr: expr, location: location)

                case "set":
                    try parseSet(expr: expr, location: location)
                    break

                case "choice":
                    try parseChoice(expr: expr, location: location)

                case "silently", "endsilently", "/silently":
                    // ignore these for now
                    break

                case "d", "endd", "/d":
                    // ignore these for now
                    break
                
                case "textinput":
                    // TODO: support this
                    break

                case "include", "display":
                    // TODO: support this
                    break

                default:
                    throw TweeErrorLocation(error: .UnrecognizedMacro, location: location, message: "Unrecognized macro: \(name!)")
                }
            }
        }
    }
    
    private func endLineOfText(location: TweeLocation) {
        if currentCodeBlock != nil && lineHasText {
            // add newline at end of lines with any text
            currentCodeBlock!.add(TweeNewlineStatement(location: location))
        }
        lineHasText = false  // start new line
    }
    
    private func parseIf(name: String, expr: String?, location: TweeLocation) throws {
        switch name {
        case "if":
            guard let expr = expr else {
                throw TweeErrorLocation(error: .MissingExpression, location: location, message: "Missing expression for if")
            }
            let cond = try parse(expression: expr, location: location, for: "if")
            let ifStmt = TweeIfStatement(location: location, condition: cond)
            currentCodeBlock!.add(ifStmt)
            currentStatements.append(ifStmt)
            assert(currentCodeBlock === ifStmt.clauses[0].block)

        case "else":
            if expr != nil {
                throw TweeErrorLocation(error: .UnexpectedExpression, location: location, message: "Unexpected expression in else")
            }
            guard let ifStmt = currentStatement as? TweeIfStatement else {
                throw TweeErrorLocation(error: .MissingIf, location: location, message: "Found else without corresponding if")
            }
            if ifStmt.elseClause != nil {
                throw TweeErrorLocation(error: .DuplicateElse, location: location, message: "Duplicate else clause")
            }
            let elseBlock = ifStmt.addElse(location: location)
            assert(currentCodeBlock === elseBlock)

        case "elseif":
            guard let expr = expr else {
                throw TweeErrorLocation(error: .MissingExpression, location: location, message: "Missing expression for elseif")
            }
            let cond = try parse(expression: expr, location: location, for: "elseif")
            guard let ifStmt = currentStatement as? TweeIfStatement else {
                throw TweeErrorLocation(error: .MissingIf, location: location, message: "Found elseif without corresponding if")
            }
            if ifStmt.elseClause != nil {
                throw TweeErrorLocation(error: .DuplicateElse, location: location, message: "Found elseif after else")
            }
            let elseIfBlock = ifStmt.addElseIf(location: location, condition: cond)
            assert(currentCodeBlock === elseIfBlock)

        case "endif", "/if":
            if expr != nil {
                throw TweeErrorLocation(error: .UnexpectedExpression, location: location, message: "Unexpected expression in endif")
            }
            if !(currentStatement is TweeIfStatement) {
                throw TweeErrorLocation(error: .MissingIf, location: location, message: "Found endif without corresponding if")
            }
            _ = currentStatements.popLast()
            
        default:
            fatalError("Unexpected macro for if: \(name)")
        }
    }

    private func parseDelay(name: String, expr: String?, location: TweeLocation) throws {
        switch name {
        case "delay":
            guard let expr = expr else {
                throw TweeErrorLocation(error: .MissingExpression, location: location, message: "Missing expression for delay")
            }
            let delayExpr = try parse(expression: expr, location: location, for: "delay")
            let stmt = TweeDelayStatement(location: location, expression: delayExpr)
            endLineOfText(location: location)  // end any text before delay
            currentCodeBlock!.add(stmt)
            currentStatements.append(stmt)
            assert(currentCodeBlock === stmt.block)

        case "enddelay", "/delay":
            if expr != nil {
                throw TweeErrorLocation(error: .UnexpectedExpression, location: location, message: "Unexpected expression in enddelay")
            }
            if !(currentStatement is TweeDelayStatement) {
                throw TweeErrorLocation(error: .MissingDelay, location: location, message: "Found enddelay without corresponding delay")
            }
            _ = currentStatements.popLast()
            lineHasText = false  // don't need a newline, unless some text appears after enddelay

        default:
            fatalError("Unexpected macro for delay: \(name)")
        }
    }
    
    private func parseSet(expr: String?, location: TweeLocation) throws {
        guard let expr = expr else {
            throw TweeErrorLocation(error: .MissingExpression, location: location, message: "No expression given for set")
        }

        let variableAndExpr = expr.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespaces) }
        if variableAndExpr.count != 2 {
            throw TweeErrorLocation(error: .InvalidExpression, location: location, message: "Invalid expression for set.  Should be <<set $var = val>>")
        }
        let variable = variableAndExpr[0]
        let setExpr = try parse(expression: variableAndExpr[1], location: location, for: "set")

        let setStmt = TweeSetStatement(location: location, variable: variable, expression: setExpr)
        currentCodeBlock!.add(setStmt)
    }
    
    private func parseChoice(expr: String?, location: TweeLocation) throws {
        guard let expr = expr else {
            throw TweeErrorLocation(error: .MissingExpression, location: location, message: "No expression given for choice")
        }

        // This is a weird one.  Just lex the contents of a choice macro, as though the choice didn't even exist.
        // Technically this will allow just about anything inside the macro, but it works well enough.  We don't plan on using this going forward.
        do {
            try lexer.lex(string: expr, includeNewlines: false, block: handleToken)
        } catch let error as TweeErrorLocation {
            throw TweeErrorLocation(error: .InvalidChoiceSyntax, location: location, message: "Error while parsing choice: \(error.message)")
        }
    }
}
