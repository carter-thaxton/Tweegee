//
//  TweeStory.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/7/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

class TweeStory {
    var passagesByName = [String : TweePassage]()
    var passagesInOrder = [TweePassage]()
    
    var passageCount : Int { return passagesInOrder.count }

    var startPassage : TweePassage? {
        // For now, don't support Twee2Settings to specify the start passage.
        // Just hardcode to use "Start" as the passage name.
        return passagesByName["Start"]
    }

    func addPassage(passage: TweePassage) throws {
        if let existing = passagesByName[passage.name] {
            throw TweeErrorLocation(error: .DuplicatePassageName, location: passage.location,
                                    message: "Passage \(passage.name) is already defined on line \(existing.location.lineNumber)")
        }
        passagesByName[passage.name] = passage
        passagesInOrder.append(passage)
    }
}

//
//  == GRAMMAR ==
//

//  passage ->
//    block

//  block ->
//    [stmt]

//  stmt ->
//    newline
//    text (string)
//    link (name, title)
//    choice ([link])
//    let (var, expr)
//    if ([ifcond], else-block)
//    expr  // when used like this, represents use of expression in template

//  ifcond ->
//    cond (expr)
//    block

class TweeStatement {
    let location : TweeLocation
    
    init(location: TweeLocation) {
        self.location = location
    }
}

class TweeCodeBlock {
    var statements = [TweeStatement]()
    
    func add(_ statement: TweeStatement) {
        statements.append(statement)
    }
    
    var last : TweeStatement? { return statements.last }
    
    @discardableResult func pop() -> TweeStatement? {
        return statements.popLast()
    }
}

protocol NestableStatement {
    var location : TweeLocation { get }
    var block : TweeCodeBlock { get }
}

class TweePassage : TweeStatement, NestableStatement {
    let name : String
    let position : CGPoint?
    let tags : [String]
    let block = TweeCodeBlock()

    init(location: TweeLocation, name: String, position: CGPoint?, tags: [String]) {
        self.name = name
        self.position = position
        self.tags = tags
        super.init(location: location)
    }
}


class TweeNewlineStatement : TweeStatement {
}

class TweeTextStatement : TweeStatement {
    let text : String
    
    init(location: TweeLocation, text: String) {
        self.text = text
        super.init(location: location)
    }
}

class TweeLinkStatement : TweeStatement {
    let name : String
    let title : String?
    
    init(location: TweeLocation, name: String, title: String?) {
        self.name = name
        self.title = title
        super.init(location: location)
    }
}

class TweeChoiceStatement : TweeStatement {
    var choices = [TweeLinkStatement]()
}

class TweeSetStatement : TweeStatement {
    let variable : String
    let expression : TweeExpression

    init(location: TweeLocation, variable: String, expression: TweeExpression) {
        self.variable = variable
        self.expression = expression
        super.init(location: location)
    }
}

class TweeExpressionStatement : TweeStatement {
    let expression : TweeExpression
    
    init(location: TweeLocation, expression: TweeExpression) {
        self.expression = expression
        super.init(location: location)
    }
}

class TweeIfStatement : TweeStatement, NestableStatement {
    struct IfClause {
        let condition : TweeExpression
        var block = TweeCodeBlock()
        
        init(condition : TweeExpression) {
            self.condition = condition
        }
    }

    var clauses = [IfClause]()
    var elseBlock : TweeCodeBlock?

    var ifCondition : TweeExpression { return clauses[0].condition }
    var ifBlock : TweeCodeBlock { return clauses[0].block }
    
    // to conform to NestableStatement
    var block : TweeCodeBlock {
        return elseBlock ?? clauses.last!.block
    }

    init(location: TweeLocation, condition: TweeExpression) {
        clauses.append(IfClause(condition: condition))  // Always initialize with at least one clause
        super.init(location: location)
    }
    
    func addElseIf(condition: TweeExpression) -> TweeCodeBlock {
        clauses.append(IfClause(condition: condition))
        return clauses.last!.block
    }
}

