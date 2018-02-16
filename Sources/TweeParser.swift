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
                throw TweeErrorLocation(error: .MissingEndIf, location: stmt.location)
            } else {
                fatalError("Unexpected type of open statement: \(stmt)")
            }
        }
    }

    private func handleToken(token: TweeToken, location: TweeLocation) throws {
        numTokensParsed += 1
        
        func ensureCodeBlock() throws {
            if currentPassage == nil || currentCodeBlock == nil {
                throw TweeErrorLocation(error: .TextOutsidePassage, location: location)
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

                case "let":
                    try parseLet(expr: expr, location: location)
                    break

                case "silently", "endsilently", "/silently":
                    // ignore these for now
                    break

                default:
                    throw TweeErrorLocation(error: .UnrecognizedMacro, location: location)
                }
            }
        }
    }
    
    private func parseIf(name: String, expr: String?, location: TweeLocation) throws {
        switch name {
        case "if":
            guard let expr = expr else {
                throw TweeErrorLocation(error: .MissingExpression, location: location)
            }
            let cond = try parse(expression: expr, location: location)
            let stmt = TweeIfStatement(location: location, condition: cond)
            currentStatements.append(stmt)

        case "else":
            if expr != nil {
                throw TweeErrorLocation(error: .InvalidExpression, location: location)
            }
            guard let ifStmt = currentStatement as? TweeIfStatement else {
                throw TweeErrorLocation(error: .MissingIf, location: location)
            }
            if ifStmt.elseBlock != nil {
                throw TweeErrorLocation(error: .DuplicateElse, location: location)
            }
            ifStmt.elseBlock = TweeCodeBlock()
            assert(currentCodeBlock === ifStmt.elseBlock)

        case "elseif":
            guard let expr = expr else {
                throw TweeErrorLocation(error: .MissingExpression, location: location)
            }
            let cond = try parse(expression: expr, location: location)
            guard let ifStmt = currentStatement as? TweeIfStatement else {
                throw TweeErrorLocation(error: .MissingIf, location: location)
            }
            if ifStmt.elseBlock != nil {
                // elseif after else
                throw TweeErrorLocation(error: .DuplicateElse, location: location)
            }
            let elseIfBlock = ifStmt.addElseIf(condition: cond)
            assert(currentCodeBlock === elseIfBlock)

        case "endif", "/if":
            if expr != nil {
                throw TweeErrorLocation(error: .UnexpectedExpression, location: location)
            }
            if !(currentStatement is TweeIfStatement) {
                throw TweeErrorLocation(error: .MissingIf, location: location)
            }
            _ = currentStatements.popLast()
            
        default:
            fatalError("Unexpected macro for if: \(name)")
        }
    }

    private func parseLet(expr: String?, location: TweeLocation) throws {
        guard let expr = expr else {
            throw TweeErrorLocation(error: .MissingExpression, location: location)
        }

        let variableAndExpr = expr.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespaces) }
        if variableAndExpr.count != 2 {
            throw TweeErrorLocation(error: .InvalidExpression, location: location)
        }
        let variable = variableAndExpr[0]
        let letExpr = try parse(expression: variableAndExpr[1], location: location)

        let letStmt = TweeLetStatement(location: location, variable: variable, expression: letExpr)
        currentCodeBlock!.add(letStmt)
    }

    // MARK: Expression Parsing

    func parse(expression: String?, location: TweeLocation = TweeLocation()) throws -> TweeExpression {
        if expression == nil {
            throw TweeErrorLocation(error: .InvalidExpression, location: location)
        }
        // TODO: finish this
        return TweeExpression()
    }

}
