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
    
    var currentStatements = [NestableStatement]()
    var currentStatement : NestableStatement? { return currentStatements.last }
    var currentCodeBlock : TweeCodeBlock? { return currentStatement?.block }

    // MARK: Public Methods

    func parse(filename: String) throws -> TweeStory {
        try lexer.lex(filename: filename, block: handleToken)
        try closePassageAndEnsureNoOpenStatements()
        return story
    }

    func parse(string: String) throws -> TweeStory {
        try lexer.lex(string: string, block: handleToken)
        try closePassageAndEnsureNoOpenStatements()
        return story
    }
    
    // MARK: Handle Token
    
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

        case .Comment(let comment):
            // ignore comments
            _ = comment
            break

        case .Newline:
            // TODO: figure this out
            break

        case .Text(let text):
            try ensureCodeBlock()
            
            // Special case for | separating links
            if text.trimmingCharacters(in: .whitespaces) == "|" {
                if let link = currentCodeBlock?.last as? TweeLinkStatement {
                    // convert previous link to list of choices
                    currentCodeBlock!.pop()
                    let stmt = TweeChoiceStatement(location: link.location)
                    stmt.choices.append(link)
                } else if let choices = currentCodeBlock?.last as? TweeChoiceStatement {
                    // already a list of choices, simply ignore the |
                    _ = choices
                }
            } else {
                let stmt = TweeTextStatement(location: location, text: text)
                currentCodeBlock!.add(stmt)
            }

        case .Link(let name, let title):
            try ensureCodeBlock()
            let stmt = TweeLinkStatement(location: location, name: name, title: title)
            currentCodeBlock!.add(stmt)

        case .Macro(let name, let expr):
            try ensureCodeBlock()
            if name == nil {
                // raw expression used in macro
                
            } else {
                switch name! {
                case "if", "else", "elseif", "endif", "/if":
                    try parseIf(name: name!, expr: expr, location: location)

                case "set":
                    try parseSet(expr: expr, location: location)
                    break

                case "choice":
                    try parseChoice(expr: expr, location: location)

                case "silently", "endsilently", "/silently":
                    // ignore these for now
                    break

                default:
                    throw TweeErrorLocation(error: .UnrecognizedMacro, location: location, message: "Unrecognized macro: \(name!)")
                }
            }
        }
    }
    
    private func parseIf(name: String, expr: String?, location: TweeLocation) throws {
        switch name {
        case "if":
            guard let expr = expr else {
                throw TweeErrorLocation(error: .MissingExpression, location: location, message: "Missing expression for if")
            }
            let cond = try parse(expression: expr, location: location, for: "if")
            let stmt = TweeIfStatement(location: location, condition: cond)
            currentStatements.append(stmt)

        case "else":
            if expr != nil {
                throw TweeErrorLocation(error: .UnexpectedExpression, location: location, message: "Unexpected expression in else")
            }
            guard let ifStmt = currentStatement as? TweeIfStatement else {
                throw TweeErrorLocation(error: .MissingIf, location: location, message: "Found else without corresponding if")
            }
            if ifStmt.elseBlock != nil {
                throw TweeErrorLocation(error: .DuplicateElse, location: location, message: "Duplicate else clause")
            }
            ifStmt.elseBlock = TweeCodeBlock()
            assert(currentCodeBlock === ifStmt.elseBlock)

        case "elseif":
            guard let expr = expr else {
                throw TweeErrorLocation(error: .MissingExpression, location: location, message: "Missing expression for elseif")
            }
            let cond = try parse(expression: expr, location: location, for: "elseif")
            guard let ifStmt = currentStatement as? TweeIfStatement else {
                throw TweeErrorLocation(error: .MissingIf, location: location, message: "Found elseif without corresponding if")
            }
            if ifStmt.elseBlock != nil {
                throw TweeErrorLocation(error: .DuplicateElse, location: location, message: "Found elseif after else")
            }
            let elseIfBlock = ifStmt.addElseIf(condition: cond)
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
            try lexer.lex(string: expr, block: handleToken)
        } catch let error as TweeErrorLocation {
            throw TweeErrorLocation(error: .InvalidChoiceSyntax, location: location, message: "Error while parsing choice: \(error.message)")
        }
    }

    // MARK: Expression Parsing

    func parse(expression: String?, location: TweeLocation, for macro: String) throws -> TweeExpression {
        if expression == nil {
            throw TweeErrorLocation(error: .MissingExpression, location: location, message: "Missing expression for \(macro)")
        }
        // TODO: finish this
        return TweeExpression()
    }

}
