//
//  TweeStory.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/7/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

typealias Dict = [String:Any]
typealias DictArr = [Dict]

protocol ToJSON {
    func toJSON() -> Dict
}

class TweeStory : ToJSON {
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

    func toJSON() -> Dict {
        var passages = DictArr()
        for passage in passagesInOrder {
            passages.append(passage.toJSON())
        }
        
        return ["start": "Start", "passageCount": passageCount, "passages": passages]
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

class TweeStatement : ToJSON {
    let location : TweeLocation
    
    init(location: TweeLocation) {
        self.location = location
    }

    func toJSON() -> Dict {
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

    override func toJSON() -> Dict {
        var statements = DictArr()
        for stmt in self.block.statements {
            statements.append(stmt.toJSON())
        }
        return ["name": self.name, "tags": self.tags, "statements": statements]
    }
}

class TweeNewlineStatement : TweeStatement {
    override func toJSON() -> Dict {
        return ["type": "newline"]
    }
}

class TweeTextStatement : TweeStatement {
    let text : String
    
    init(location: TweeLocation, text: String) {
        self.text = text
        super.init(location: location)
    }

    override func toJSON() -> Dict {
        return ["type": "text", "text": self.text]
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

    override func toJSON() -> Dict {
        return ["type": "link", "name": self.name, "title": self.title ?? NSNull()]
    }
}

class TweeChoiceStatement : TweeStatement {
    var choices = [TweeLinkStatement]()

    override func toJSON() -> Dict {
        return ["type": "choice"]
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

    override func toJSON() -> Dict {
        return ["type": "set"]
    }
}

class TweeExpressionStatement : TweeStatement {
    let expression : TweeExpression
    
    init(location: TweeLocation, expression: TweeExpression) {
        self.expression = expression
        super.init(location: location)
    }

    override func toJSON() -> Dict {
        return ["type": "expression"]
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

    override func toJSON() -> Dict {
        return ["type": "if"]
    }
}

