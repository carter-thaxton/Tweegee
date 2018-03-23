//
//  TweeStatements.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/21/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

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
//    delay (expr, block)
//    expr  // when used like this, represents use of expression in template

//  ifcond ->
//    cond (expr)
//    block

class TweeStatement : AsJson {
    let location : TweeLocation
    
    init(location: TweeLocation) {
        self.location = location
    }
    
    func asJson() -> Dict {
        fatalError("Cannot call toJSON() on top-level twee statement")
    }
    
    func visit(fn: (TweeStatement) -> Void) {
        fn(self)
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
    
    func asJson() -> DictArr {
        var result = DictArr()
        for stmt in statements {
            result.append(stmt.asJson())
        }
        return result
    }
    
    func visit(fn: (TweeStatement) -> Void) {
        for stmt in statements {
            stmt.visit(fn: fn)
        }
    }
}

// Used for statements that can contain its own code block, like If, Delay, and Passage
protocol NestableStatement {
    var location : TweeLocation { get }
    var block : TweeCodeBlock { get }
}

class TweePassage : TweeStatement, NestableStatement {
    let name : String
    let posX : Int?
    let posY : Int?
    let tags : [String]
    let block = TweeCodeBlock()
    var rawTwee = [String]()

    init(location: TweeLocation, name: String, posX: Int?, posY: Int?, tags: [String]) {
        self.name = name
        self.posX = posX
        self.posY = posY
        self.tags = tags
        super.init(location: location)
    }
    
    // For convenience, if this passages contains a single TextPassage, return it
    func getSingleTextStatement() -> TweeTextStatement? {
        if block.statements.count >= 1 {
            if let stmt = block.statements[0] as? TweeTextStatement {
                return stmt
            }
        }
        return nil
    }
    
    override func asJson() -> Dict {
        return ["name": name, "tags": tags, "statements": block.asJson(), "code": rawTwee]
    }
    
    override func visit(fn: (TweeStatement) -> Void) {
        super.visit(fn: fn)
        block.visit(fn: fn)
    }
}

class TweeNewlineStatement : TweeStatement {
    override func asJson() -> Dict {
        return ["_type": "newline", "line": location.passageLineNumber]
    }
}

class TweeTextStatement : TweeStatement {
    let text : String
    
    init(location: TweeLocation, text: String) {
        self.text = text
        super.init(location: location)
    }
    
    override func asJson() -> Dict {
        return ["_type": "text", "line": location.passageLineNumber, "text": text]
    }
}

class TweeLinkStatement : TweeStatement {
    let passage : String?
    let expression : TweeExpression?
    var text : String?

    var isDynamic : Bool { return expression != nil }

    init(location: TweeLocation, passage: String, text: String?) {
        self.passage = passage
        self.expression = nil
        self.text = text
        super.init(location: location)
    }
    
    init(location: TweeLocation, expression: TweeExpression, text: String? = nil) {
        self.passage = nil
        self.expression = expression
        self.text = text
        super.init(location: location)
    }
    
    override func asJson() -> Dict {
        if isDynamic {
            return ["_type": "link", "line": location.passageLineNumber, "expression": expression!.string, "text": text ?? NSNull()]
        } else {
            return ["_type": "link", "line": location.passageLineNumber, "passage": passage!, "text": text ?? NSNull()]
        }
    }
}

// Treat includes as a type of link statement
class TweeIncludeStatement : TweeLinkStatement {
    init(location: TweeLocation, passage: String) {
        super.init(location: location, passage: passage, text: nil)
    }
    
    init(location: TweeLocation, expression: TweeExpression) {
        super.init(location: location, expression: expression, text: nil)
    }

    override func asJson() -> Dict {
        if isDynamic {
            return ["_type": "include", "line": location.passageLineNumber, "expression": expression!.string]
        } else {
            return ["_type": "include", "line": location.passageLineNumber, "passage": passage!]
        }
    }
}

// Treat rewind as a type of link statement
class TweeRewindStatement : TweeLinkStatement {
    init(location: TweeLocation, passage: String) {
        super.init(location: location, passage: passage, text: nil)
    }
    
    init(location: TweeLocation, expression: TweeExpression) {
        super.init(location: location, expression: expression, text: nil)
    }

    override func asJson() -> Dict {
        if isDynamic {
            return ["_type": "rewind", "line": location.passageLineNumber, "expression": expression!.string]
        } else {
            return ["_type": "rewind", "line": location.passageLineNumber, "passage": passage!]
        }
    }
}

class TweeChoiceStatement : TweeStatement, NestableStatement {
    let block = TweeCodeBlock()
    
    override func asJson() -> Dict {
        return ["_type": "choice", "line": location.passageLineNumber, "statements": block.asJson()]
    }

    override func visit(fn: (TweeStatement) -> Void) {
        super.visit(fn: fn)
        block.visit(fn: fn)
    }
}

class TweePromptStatement : TweeStatement, NestableStatement {
    let block = TweeCodeBlock()

    override func asJson() -> Dict {
        return ["_type": "prompt", "line": location.passageLineNumber, "statements": block.asJson()]
    }
    
    override func visit(fn: (TweeStatement) -> Void) {
        super.visit(fn: fn)
        block.visit(fn: fn)
    }
}

class TweeSetStatement : TweeStatement {
    let variable : String
    let expression : TweeExpression
    
    init(location: TweeLocation, variable: String, expression: TweeExpression) {
        self.variable = variable
        self.expression = expression
        super.init(location: location)
    }
    
    override func asJson() -> Dict {
        return ["_type": "set", "line": location.passageLineNumber, "variable": variable, "expression": expression.string]
    }
}

class TweeExpressionStatement : TweeStatement {
    let expression : TweeExpression
    
    init(location: TweeLocation, expression: TweeExpression) {
        self.expression = expression
        super.init(location: location)
    }
    
    override func asJson() -> Dict {
        return ["_type": "expression", "line": location.passageLineNumber, "expression": expression.string]
    }
}

class TweeDelayStatement : TweeStatement, NestableStatement {
    let delay  : TweeDelay
    let block = TweeCodeBlock()
    
    init(location: TweeLocation, delay: TweeDelay) {
        self.delay = delay
        super.init(location: location)
    }
    
    override func asJson() -> Dict {
        return ["_type": "delay", "line": location.passageLineNumber, "delay": delay.string, "seconds": delay.seconds, "statements": block.asJson()]
    }

    override func visit(fn: (TweeStatement) -> Void) {
        super.visit(fn: fn)
        block.visit(fn: fn)
    }
}

class TweeIfStatement : TweeStatement, NestableStatement {
    struct IfClause {
        let location : TweeLocation
        let condition : TweeExpression?
        let block = TweeCodeBlock()
        
        init(location: TweeLocation, condition: TweeExpression?) {
            self.location = location
            self.condition = condition
        }
    }

    // each condition / block is a clause
    // else clause is just a final clause without a condition
    var clauses = [IfClause]()

    var ifCondition : TweeExpression? { return clauses[0].condition }
    var ifBlock : TweeCodeBlock { return clauses[0].block }
    var elseClause : IfClause? { return clauses.last!.condition == nil ? clauses.last! : nil }

    // to conform to NestableStatement
    var block : TweeCodeBlock {
        return clauses.last!.block
    }
    
    init(location: TweeLocation, condition: TweeExpression) {
        clauses.append(IfClause(location: location, condition: condition))  // Always initialize with at least one clause
        super.init(location: location)
    }

    func addElseIf(location: TweeLocation, condition: TweeExpression) -> TweeCodeBlock {
        assert(elseClause == nil, "Cannot add elseIf after else clause")
        clauses.append(IfClause(location: location, condition: condition))
        return block
    }
    
    func addElse(location: TweeLocation) -> TweeCodeBlock {
        assert(elseClause == nil, "Cannot add else after else clause")
        clauses.append(IfClause(location: location, condition: nil))
        return block
    }
    
    override func asJson() -> Dict {
        var clauseData = DictArr()
        for clause in clauses {
            clauseData.append(["condition": clause.condition?.string ?? NSNull(), "statements": clause.block.asJson()])
        }
        return ["_type": "if", "line": location.passageLineNumber, "clauses": clauseData]
    }

    override func visit(fn: (TweeStatement) -> Void) {
        super.visit(fn: fn)
        for clause in clauses {
            clause.block.visit(fn: fn)
        }
    }
}
