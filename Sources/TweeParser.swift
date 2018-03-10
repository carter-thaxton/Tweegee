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
    var silently = false
    var handlingError = false

    var currentStatements = [NestableStatement]()
    var currentStatement : NestableStatement? { return currentStatements.last }
    var currentCodeBlock : TweeCodeBlock? { return currentStatement?.block }

    // MARK: Public Methods

    func parse(filename: String) throws -> TweeStory {
        try lexer.lex(filename: filename, block: handleToken)
        return finish()
    }

    func parse(string: String) -> TweeStory {
        lexer.lex(string: string, block: handleToken)
        return finish()
    }

    func parse(expression: String?, location: TweeLocation, for macro: String) throws -> TweeExpression {
        guard let expression = expression else {
            throw TweeError(type: .MissingExpression, location: location, message: "Missing expression for \(macro)")
        }
        let result = TweeExpression(expression, location: location)
        if result.error != nil {
            throw result.error!
        }
        return result
    }

    // MARK: Parser Implementation

    private func finish() -> TweeStory {
        trimTrailingEmptyLinesOfRawTwee()
        ensureNoOpenStatements()
        parseSpecialPassages()
        calculateWordCount()
        calculateDefinedVariables()
        checkUndefinedVariables()
        checkMissingAndUnreferencedPassages()
        return story
    }

    private func parseSpecialPassages() {
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
                    story.errors.append(TweeError(type: .InvalidTwee2Settings, location: settings.location, message: "@story_start_name found in Twee2Settings passage, but has invalid syntax"))
                }
            }
        }
    }
    
    private func checkMissingAndUnreferencedPassages() {
        var unreferencedPassageNames = Set(story.passagesByName.keys)

        // Make sure every link refers to a passage
        let links = story.getAllLinks()
        for link in links {
            if !link.isDynamic {
                if story.passagesByName[link.passage!] == nil {
                    story.errors.append(TweeError(type: .MissingPassage, location: link.location, message: "Link refers to passage named '\(link.passage!)' but no passage exists with that name"))
                } else {
                    unreferencedPassageNames.remove(link.passage!)
                }
            }
        }
        
        // Check for start passage
        if story.startPassage == nil {
            story.errors.append(TweeError(type: .MissingPassage, location: nil, message: "Missing start passage named '\(story.startPassageName)'"))
        }
        unreferencedPassageNames.remove(story.startPassageName)

        // Any remaining passages are unreferenced
        // However, adding a tag of 'noreferror' will suppress this error
        for name in unreferencedPassageNames {
            if let p = story.passagesByName[name] {
                if !p.tags.contains("noreferror") {
                    story.errors.append(TweeError(type: .UnreferencedPassage, location: p.location, message: "Passage '\(name)' is never referenced"))
                }
            }
        }
    }
    
    private func calculateDefinedVariables() {
        // collect all of the variables that are ever set
        story.definedVariables.removeAll()
        story.visit() { stmt in
            if let setStmt = stmt as? TweeSetStatement {
                story.definedVariables.insert(setStmt.variable)
            }
        }
    }
    
    private func checkUndefinedVariables() {
        // helper function used below
        func checkVariables(expression: TweeExpression, location: TweeLocation) {
            for variable in expression.variables {
                if !story.definedVariables.contains(variable) {
                    story.errors.append(TweeError(type: .UndefinedVariable, location: location,
                                                  message: "Variable \(variable) is used but never set"))
                }
            }
        }

        // check every use of a variable
        story.visit() { (stmt) in
            switch stmt {
            case let setStmt as TweeSetStatement:
                checkVariables(expression: setStmt.expression, location: stmt.location)

            case let exprStmt as TweeExpressionStatement:
                checkVariables(expression: exprStmt.expression, location: stmt.location)

            case let ifStmt as TweeIfStatement:
                for clause in ifStmt.clauses where clause.condition != nil {
                    checkVariables(expression: clause.condition!, location: stmt.location)
                }

            case let linkStmt as TweeLinkStatement where linkStmt.isDynamic:  // handles both link and include
                checkVariables(expression: linkStmt.expression!, location: stmt.location)

            default:
                break
            }
        }
    }
    
    private func calculateWordCount() {
        var wordCount = 0
        story.visit() { stmt in
            if let textStmt = stmt as? TweeTextStatement {
                let words = textStmt.text.split(separator: " ", omittingEmptySubsequences: true)
                wordCount += words.count
            }
        }
        story.wordCount = wordCount
    }
    
    private func ensureNoOpenStatements() {
        if let stmt = currentStatement {
            if silently {
                // simply use passage location for endsilently error
                story.errors.append(TweeError(type: .MissingEndSilently, location: stmt.location, message: "Passage ended without closing endsilently"))
            }
            if stmt is TweePassage {
                if currentStatements.count != 1 {
                    fatalError("TweePassage found in nested position")
                }
            }
            else if stmt is TweeIfStatement {
                story.errors.append(TweeError(type: .MissingEndIf, location: stmt.location, message: "Passage ended without closing endif"))
            } else {
                fatalError("Unexpected type of open statement: \(stmt)")
            }
        }
    }

    private func resetPassage() {
        currentStatements.removeAll()
        lineHasText = false
        silently = false
    }
    
    private func trimTrailingEmptyLinesOfRawTwee() {
        if let passage = currentPassage {
            var i = passage.rawTwee.count - 1
            while (i > 0 && passage.rawTwee[i].trimmingWhitespace().isEmpty) {  // never remove first line
                passage.rawTwee.remove(at: i)
                i -= 1
            }
        }
    }

    private func handleToken(token: TweeToken, location: TweeLocation) {
        // collect lines for current passage
        if case .Newline(let line) = token {
            currentPassage?.rawTwee.append(line)
        }
        
        // return early while handling errors, up until the next passage symbol
        if handlingError {
            if case .Passage = token {
                handlingError = false
            } else {
                return
            }
        }

        numTokensParsed += 1

        func ensureCodeBlock() throws {
            if currentPassage == nil || currentCodeBlock == nil {
                throw TweeError(type: .TextOutsidePassage, location: location, message: "No text is allowed outside of a passage")
            }
        }
        
        do {
            switch token {
            case .Error(let type, let message):
                throw TweeError(type: type, location: location, message: message)

            case .Passage(let name, let tags, let posX, let posY):
                trimTrailingEmptyLinesOfRawTwee()
                ensureNoOpenStatements()
                resetPassage()

                currentPassage = TweePassage(location: location, name: name, posX: posX, posY: posY, tags: tags)
                currentStatements.append(currentPassage!)
                let existing = story.addPassage(passage: currentPassage!)
                
                // if an existing passage already exists by name, add an error, but continue parsing
                if let existing = existing {
                    story.errors.append(TweeError(type: .DuplicatePassageName, location: currentPassage!.location,
                        message: "Passage \(existing.name) is already defined on line \(existing.location.fileLineNumber)"))
                }

            case .Comment(let comment):
                // ignore comments
                _ = comment
                break

            case .Newline:
                endLineOfText(location: location)

            case .Text(let text):
                try ensureCodeBlock()
                try parseText(text: text, location: location)
                
            case .Link(let passage, let title):
                try ensureCodeBlock()
                try parseLink(passage: passage, title: title, location: location)

            case .Macro(let name, let expr):
                try ensureCodeBlock()
                if name == nil || name == "=" || name == "print" {
                    // raw expression used in macro (or one of the various print macros)
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

                    case "choice":
                        try parseChoice(expr: expr, location: location)

                    case "include", "display":
                        try parseInclude(expr: expr, location: location)
                        
                    case "silently":
                        silently = true

                    case "endsilently", "/silently":
                        silently = false

                    case "textinput":
                        // TODO: support this
                        break

                    case "d", "endd", "/d":
                        // ignore these for now
                        break
                        
                    default:
                        throw TweeError(type: .UnrecognizedMacro, location: location, message: "Unrecognized macro: \(name!)")
                    }
                }
            }
        } catch let error as TweeError {
            // Error occurred while parsing line.  Collect the errors, reset the passage, and move on until start of next passage.
            story.errors.append(error)
            resetPassage()
            handlingError = true
        } catch {
            fatalError("Unexpected error while parsing: \(error)")
        }
    }
    
    private func endLineOfText(location: TweeLocation) {
        if currentCodeBlock != nil && lineHasText {
            // add newline at end of lines with any text
            currentCodeBlock!.add(TweeNewlineStatement(location: location))
        }
        lineHasText = false  // start new line
    }
    
    private func parseText(text: String, location: TweeLocation) throws {
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
        } else if !silently {
            let stmt = TweeTextStatement(location: location, text: text)
            currentCodeBlock!.add(stmt)
            lineHasText = true  // add some text to line
        }
    }
    
    private func parseLink(passage: String, title: String?, location: TweeLocation) throws {
        let linkStmt : TweeLinkStatement
        if passage.starts(with: "$") {
            // link uses a dynamic expression
            let expression = try parse(expression: passage, location: location, for: "link")
            linkStmt = TweeLinkStatement(location: location, expression: expression, title: title)
        } else {
            linkStmt = TweeLinkStatement(location: location, passage: passage, title: title)
        }
        
        // check if link is part of a list of choices
        let choiceStmt = currentCodeBlock!.last as? TweeChoiceStatement
        
        // end any text before following a link or choice
        endLineOfText(location: location)
        
        if choiceStmt != nil {
            choiceStmt!.choices.append(linkStmt)
        } else {
            // if link has a title like "delay 10m", then insert an empty delay before following the link
            if let delayMatch = title?.match(pattern: "^delay\\s+(\\w+)$") {
                let delayStr = delayMatch[1]!
                guard let delay = TweeDelay(fromString: delayStr) else {
                    throw TweeError(type: .InvalidDelay, location: location, message: "Invalid expression for delay: \(delayStr)")
                }
                
                let delayStmt = TweeDelayStatement(location: location, delay: delay)
                currentCodeBlock!.add(delayStmt)
                
                // don't use any title for the link
                linkStmt.title = nil
            }
            
            // add the link
            currentCodeBlock!.add(linkStmt)
        }
    }
    
    private func parseIf(name: String, expr: String?, location: TweeLocation) throws {
        switch name {
        case "if":
            guard let expr = expr else {
                throw TweeError(type: .MissingExpression, location: location, message: "Missing expression for if")
            }
            let cond = try parse(expression: expr, location: location, for: "if")
            let ifStmt = TweeIfStatement(location: location, condition: cond)
            currentCodeBlock!.add(ifStmt)
            currentStatements.append(ifStmt)
            assert(currentCodeBlock === ifStmt.clauses[0].block)

        case "else":
            if expr != nil {
                throw TweeError(type: .UnexpectedExpression, location: location, message: "Unexpected expression in else")
            }
            guard let ifStmt = currentStatement as? TweeIfStatement else {
                throw TweeError(type: .MissingIf, location: location, message: "Found else without corresponding if")
            }
            if ifStmt.elseClause != nil {
                throw TweeError(type: .DuplicateElse, location: location, message: "Duplicate else clause")
            }
            let elseBlock = ifStmt.addElse(location: location)
            assert(currentCodeBlock === elseBlock)

        case "elseif":
            guard let expr = expr else {
                throw TweeError(type: .MissingExpression, location: location, message: "Missing expression for elseif")
            }
            let cond = try parse(expression: expr, location: location, for: "elseif")
            guard let ifStmt = currentStatement as? TweeIfStatement else {
                throw TweeError(type: .MissingIf, location: location, message: "Found elseif without corresponding if")
            }
            if ifStmt.elseClause != nil {
                throw TweeError(type: .DuplicateElse, location: location, message: "Found elseif after else")
            }
            let elseIfBlock = ifStmt.addElseIf(location: location, condition: cond)
            assert(currentCodeBlock === elseIfBlock)

        case "endif", "/if":
            if expr != nil {
                throw TweeError(type: .UnexpectedExpression, location: location, message: "Unexpected expression in endif")
            }
            if !(currentStatement is TweeIfStatement) {
                throw TweeError(type: .MissingIf, location: location, message: "Found endif without corresponding if")
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
                throw TweeError(type: .MissingExpression, location: location, message: "Missing expression for delay")
            }
            let delayExpr = expr.trimmingCharacters(in: "\"'")  // trim quotes around delay
            guard let delay = TweeDelay(fromString: delayExpr) else {
                throw TweeError(type: .InvalidDelay, location: location, message: "Invalid expression for delay: \(delayExpr)")
            }
            let stmt = TweeDelayStatement(location: location, delay: delay)
            endLineOfText(location: location)  // end any text before delay
            currentCodeBlock!.add(stmt)
            currentStatements.append(stmt)
            assert(currentCodeBlock === stmt.block)

        case "enddelay", "/delay":
            if expr != nil {
                throw TweeError(type: .UnexpectedExpression, location: location, message: "Unexpected expression in enddelay")
            }
            if !(currentStatement is TweeDelayStatement) {
                throw TweeError(type: .MissingDelay, location: location, message: "Found enddelay without corresponding delay")
            }
            _ = currentStatements.popLast()
            lineHasText = false  // don't need a newline, unless some text appears after enddelay

        default:
            fatalError("Unexpected macro for delay: \(name)")
        }
    }
    
    private func parseSet(expr: String?, location: TweeLocation) throws {
        guard let expr = expr else {
            throw TweeError(type: .MissingExpression, location: location, message: "No expression given for set")
        }

        let variableAndExpr = expr.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespaces) }
        if variableAndExpr.count != 2 || !variableAndExpr[0].starts(with: "$") {
            throw TweeError(type: .InvalidExpression, location: location, message: "Invalid expression for set.  Should be <<set $var = val>>")
        }
        let variable = variableAndExpr[0]
        let setExpr = try parse(expression: variableAndExpr[1], location: location, for: "set")

        let setStmt = TweeSetStatement(location: location, variable: variable, expression: setExpr)
        currentCodeBlock!.add(setStmt)
    }
    
    private func parseChoice(expr: String?, location: TweeLocation) throws {
        guard let expr = expr else {
            throw TweeError(type: .MissingExpression, location: location, message: "No expression given for choice")
        }

        // This is a weird one.  Lex the contents of a choice macro, as though the macro weren't there.
        // Pass through handling any links, ignore newline at end, and produce an error otherwise.
        var choiceError : TweeError?
        lexer.lex(string: expr) { (token, _) in
            if choiceError == nil {
                switch token {
                case .Link:
                    self.handleToken(token: token, location: location)
                case .Newline:
                    // ignore newline at end of parse
                    break
                case .Error(_, let message):
                    choiceError = TweeError(type: .InvalidChoiceSyntax, location: location, message: "Error while parsing choice: \(message)")
                default:
                    choiceError = TweeError(type: .InvalidChoiceSyntax, location: location, message: "Only links allowed inside of choice")
                }
            }
        }

        if choiceError != nil {
            throw choiceError!
        }
    }

    private func parseInclude(expr: String?, location: TweeLocation) throws {
        guard let expr = expr else {
            throw TweeError(type: .MissingExpression, location: location, message: "No passage given for include")
        }
        let stmt : TweeIncludeStatement
        if expr.starts(with: "$") {  // Good enough.  Could support more elaborate syntax if necessary
            let expression = try parse(expression: expr, location: location, for: "include")
            stmt = TweeIncludeStatement(location: location, expression: expression)
        } else {
            let passage = expr.trimmingCharacters(in: "\"'")
            stmt = TweeIncludeStatement(location: location, passage: passage)
        }
        currentCodeBlock!.add(stmt)
    }
}
