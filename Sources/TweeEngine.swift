//
//  TweeEngine.swift
//  Tweegee
//
//  Created by Carter Thaxton on 3/6/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

class TweeEngine {
    // MARK: Nested block structure
    typealias BlockCallback = () -> TweeAction?
    struct NestedBlock {
        let block: TweeCodeBlock
        let statementIndex: Int
        let callback: BlockCallback?
    }
    
    // MARK: Properties
    let story : TweeStory

    var currentPassage : TweePassage? = nil
    var currentBlock : TweeCodeBlock? = nil
    var currentStatementIndex : Int = -1
    var currentLine : String = ""
    
    var nestedBlocks = [NestedBlock]()
    var isNested : Bool { return !nestedBlocks.isEmpty }

    var variables = [String:Any]()

    var currentStatement : TweeStatement? {
        guard let stmts = currentBlock?.statements else { return nil }
        guard currentStatementIndex >= 0 && currentStatementIndex < stmts.count else { return nil }
        return stmts[currentStatementIndex]
    }

    // MARK: Public Interface

    init(story: TweeStory) {
        self.story = story
        resetStory()
    }
    
    func resetStory() {
        // reset all state
        currentPassage = nil
        currentBlock = nil
        currentStatementIndex = -1
        currentLine = ""
        variables = [:]
        nestedBlocks = []

        if let start = story.startPassage {
            gotoPassage(start)
        }
    }

    func getNextAction() -> TweeAction {
        let maxStatementsPerAction = 100  // prevent runaway interpreter
        do {
            var count = 0
            repeat {
                let result = try interpretNextStatement()
                if result != nil {
                    return result!
                }
                count += 1
            } while count < maxStatementsPerAction
            // runaway interpreter, should never reach here
            return .Error(error: TweeError(type: .UnknownError, location: nil, message: "Interpreter reached \(count) statements without an action"))
        } catch let error as TweeError {
            return .Error(error: error)
        } catch {
            // should never reach here, but handle it with a catch-all nonetheless
            return .Error(error: TweeError(type: .UnknownError, location: nil, message: "\(error)"))
        }
    }
    
    func makeChoice(_ choice: TweeChoice) {
        
    }

    // MARK: Private Implementation
    
    private func gotoPassage(_ passage: TweePassage) {
        currentPassage = passage
        currentBlock = passage.block
        currentStatementIndex = 0
        currentLine = ""
    }
    
    private func includePassage(_ passage: TweePassage) {
        let returnToPassage = currentPassage
        pushBlock(passage.block) {
            self.currentPassage = returnToPassage
            return nil
        }
    }
    
    private func pushBlock(_ block: TweeCodeBlock, callback: BlockCallback? = nil) {
        nestedBlocks.append(NestedBlock(block: currentBlock!, statementIndex: currentStatementIndex, callback: callback))
        currentBlock = block
        currentStatementIndex = 0
    }
    
    private func popBlock() -> BlockCallback? {
        guard isNested else { fatalError("Cannot call popBlock unless nested") }
        let nestedBlock = nestedBlocks.popLast()!
        currentBlock = nestedBlock.block
        currentStatementIndex = nestedBlock.statementIndex
        return nestedBlock.callback
    }

    // return an action, or nil if we should continue
    private func interpretNextStatement() throws -> TweeAction? {
        // TODO: check not awaiting choice
        
        if let stmt = currentStatement {
            currentStatementIndex += 1
            return try interpretStatement(stmt)
        } else if isNested {
            let callback = popBlock()
            return callback?()
        } else {
            return .End
        }
    }
    
    private func interpretStatement(_ stmt: TweeStatement) throws -> TweeAction? {
        var result : TweeAction? = nil
        switch stmt {
        case let textStmt as TweeTextStatement:
            currentLine += textStmt.text
            
        case is TweeNewlineStatement:
            currentLine = currentLine.trimmingWhitespace()
            if !currentLine.isEmpty {
                result = .Message(text: currentLine)
            }
            currentLine = ""
            
        case let setStmt as TweeSetStatement:
            let value = try eval(setStmt.expression) as Any
            variables[setStmt.variable] = value
            
        case let exprStmt as TweeExpressionStatement:
            let value = try eval(exprStmt.expression) as String
            currentLine += value
            
        case let includeStmt as TweeIncludeStatement:
            let passageName = includeStmt.isDynamic ? try eval(includeStmt.expression!) as String : includeStmt.passage!
            if let passage = story.passagesByName[passageName] {
                includePassage(passage)
            } else {
                throw TweeError(type: .MissingPassage, location: stmt.location,
                                message: "Include refers to passage named '\(passageName)' but no passage exists with that name")
            }
            
        case let linkStmt as TweeLinkStatement:
            let passageName = linkStmt.isDynamic ? try eval(linkStmt.expression!) as String : linkStmt.passage!
            if let passage = story.passagesByName[passageName] {
                gotoPassage(passage)
            } else {
                throw TweeError(type: .MissingPassage, location: stmt.location,
                                message: "Link refers to passage named '\(passageName)' but no passage exists with that name")
            }

        case let ifStmt as TweeIfStatement:
            // pick first clause that has either no condition (else) or evaluates to true
            let clause = try ifStmt.clauses.first { c in
                if c.condition == nil { return true }
                return try eval(c.condition!) as Bool
            }
            if clause != nil {
                pushBlock(clause!.block)
            }
            
        default:
            throw TweeError(type: .UnknownError, location: stmt.location, message: "Unrecognized statement type: \(stmt)")
        }
        
        return result
    }
    
    private func eval<T>(_ expression: TweeExpression) throws -> T {
        return try expression.eval(variables: variables)
    }
    
}
