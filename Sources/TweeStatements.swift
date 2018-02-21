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
        return ["name": self.name, "tags": self.tags, "statements": block.asJson()]
    }
}

class TweeNewlineStatement : TweeStatement {
    override func asJson() -> Dict {
        return ["_type": "newline"]
    }
}

class TweeTextStatement : TweeStatement {
    let text : String
    
    init(location: TweeLocation, text: String) {
        self.text = text
        super.init(location: location)
    }
    
    override func asJson() -> Dict {
        return ["_type": "text", "text": self.text]
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
    
    override func asJson() -> Dict {
        return ["_type": "link", "name": self.name, "title": self.title ?? NSNull()]
    }
}

class TweeChoiceStatement : TweeStatement {
    var choices = [TweeLinkStatement]()
    
    override func asJson() -> Dict {
        var links = DictArr()
        for choice in choices {
            links.append(choice.asJson())
        }
        return ["_type": "choice", "choices": links]
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
        return ["_type": "set", "variable": variable, "expression": expression.string]
    }
}

class TweeExpressionStatement : TweeStatement {
    let expression : TweeExpression
    
    init(location: TweeLocation, expression: TweeExpression) {
        self.expression = expression
        super.init(location: location)
    }
    
    override func asJson() -> Dict {
        return ["_type": "expression", "expression": expression.string]
    }
}

class TweeDelayStatement : TweeStatement, NestableStatement {
    let expression  : TweeExpression
    let block = TweeCodeBlock()
    
    init(location: TweeLocation, expression: TweeExpression) {
        self.expression = expression
        super.init(location: location)
    }
    
    override func asJson() -> Dict {
        return ["_type": "delay", "expression": expression.string, "statements": block.asJson()]
    }
}

class TweeIfStatement : TweeStatement, NestableStatement {
    struct IfClause {
        let location : TweeLocation
        let condition : TweeExpression
        let block = TweeCodeBlock()
        
        init(location: TweeLocation, condition: TweeExpression) {
            self.location = location
            self.condition = condition
        }
    }
    
    struct ElseClause {
        let location : TweeLocation
        let block = TweeCodeBlock()
        
        init(location: TweeLocation) {
            self.location = location
        }
    }
    
    var clauses = [IfClause]()
    var elseClause : ElseClause?
    
    var ifCondition : TweeExpression { return clauses[0].condition }
    var ifBlock : TweeCodeBlock { return clauses[0].block }
    
    // to conform to NestableStatement
    var block : TweeCodeBlock {
        return elseClause?.block ?? clauses.last!.block
    }
    
    init(location: TweeLocation, condition: TweeExpression) {
        clauses.append(IfClause(location: location, condition: condition))  // Always initialize with at least one clause
        super.init(location: location)
    }
    
    func addElseIf(location: TweeLocation, condition: TweeExpression) -> TweeCodeBlock {
        clauses.append(IfClause(location: location, condition: condition))
        return clauses.last!.block
    }
    
    func addElse(location: TweeLocation) -> TweeCodeBlock {
        elseClause = ElseClause(location: location)
        return elseClause!.block
    }
    
    override func asJson() -> Dict {
        var clauseData = DictArr()
        for clause in clauses {
            clauseData.append(["cond": clause.condition.string, "statements": clause.block.asJson()])
        }
        var elseData : Any = NSNull()
        if elseClause != nil {
            elseData = elseClause!.block.asJson()
        }
        return ["_type": "if", "clauses": clauseData, "else": elseData]
    }
}
