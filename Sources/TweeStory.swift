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

protocol AsJson {
    func asJson() -> Dict
}

class TweeStory : AsJson {
    var passagesByName = [String : TweePassage]()
    var passagesInOrder = [TweePassage]()
    
    var passageCount : Int { return passagesInOrder.count }
    
    var startPassageName : String = "Start"
    var title : String?
    var author : String?

    var startPassage : TweePassage? {
        // For now, don't support Twee2Settings to specify the start passage.
        // Just hardcode to use "Start" as the passage name.
        return passagesByName[startPassageName]
    }

    func addPassage(passage: TweePassage) throws {
        if let existing = passagesByName[passage.name] {
            throw TweeErrorLocation(error: .DuplicatePassageName, location: passage.location,
                                    message: "Passage \(passage.name) is already defined on line \(existing.location.lineNumber)")
        }
        passagesByName[passage.name] = passage
        passagesInOrder.append(passage)
    }
    
    func removePassage(name: String) -> TweePassage? {
        if let passage = passagesByName.removeValue(forKey: name) {
            if let index = passagesInOrder.index(where: { $0 === passage }) {
                passagesInOrder.remove(at: index)
            } else {
                fatalError("Passage found by name, but not in passagesInOrder: \(name)")
            }
            return passage
        }
        return nil
    }

    func asJson() -> Dict {
        var passages = DictArr()
        for passage in passagesInOrder {
            passages.append(passage.asJson())
        }
        
        return ["title": title ?? NSNull(), "author": author ?? NSNull(), "start": startPassageName, "passageCount": passageCount, "passages": passages]
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
        return ["type": "newline"]
    }
}

class TweeTextStatement : TweeStatement {
    let text : String
    
    init(location: TweeLocation, text: String) {
        self.text = text
        super.init(location: location)
    }

    override func asJson() -> Dict {
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

    override func asJson() -> Dict {
        return ["type": "link", "name": self.name, "title": self.title ?? NSNull()]
    }
}

class TweeChoiceStatement : TweeStatement {
    var choices = [TweeLinkStatement]()

    override func asJson() -> Dict {
        var links = DictArr()
        for choice in choices {
            links.append(choice.asJson())
        }
        return ["type": "choice", "choices": links]
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
        return ["type": "set", "variable": variable, "expression": expression.string]
    }
}

class TweeExpressionStatement : TweeStatement {
    let expression : TweeExpression
    
    init(location: TweeLocation, expression: TweeExpression) {
        self.expression = expression
        super.init(location: location)
    }

    override func asJson() -> Dict {
        return ["type": "expression", "expression": expression.string]
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

    override func asJson() -> Dict {
        var clauseData = DictArr()
        for clause in clauses {
            clauseData.append(["cond": clause.condition.string, "statements": clause.block.asJson()])
        }
        var elseClause : Any = NSNull()
        if elseBlock != nil {
            elseClause = elseBlock!.asJson()
        }
        return ["type": "if", "clauses": clauseData, "else": elseClause]
    }
}

