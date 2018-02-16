//
//  TweeStory.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/7/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

class TweeStory {
    var passages = [String : TweePassage]()

    var startPassage : TweePassage? {
        // For now, don't support Twee2Settings to specify the start passage.
        // Just hardcode to use "Start" as the passage name.
        return passages["Start"]
    }

    func addPassage(passage: TweePassage) throws {
        if let _ = passages[passage.name] {
            // TODO: include reference to existing passage in error
            throw TweeErrorLocation(error: TweeError.DuplicatePassageName, location: passage.location)
        }
        passages[passage.name] = passage
    }
}

class TweePassage {
    let location : TweeLocation
    let name : String
    let position : CGPoint?
    let tags : [String]
    let block = TweeCodeBlock()

    init(location: TweeLocation, name: String, position: CGPoint?, tags: [String]) {
        self.location = location
        self.name = name
        self.position = position
        self.tags = tags
    }
}


class TweeCodeBlock {
    var statements = [TweeStatement]()
}

class TweeStatement {
    let location : TweeLocation
    
    init(location: TweeLocation) {
        self.location = location
    }
}

class TweeNewlineStatement : TweeStatement {
}

class TweeSilentlyStatement : TweeStatement {
    let block = TweeCodeBlock()
}

class TweeTextStatement : TweeStatement {
    let text : String
    
    init(location: TweeLocation, text: String) {
        self.text = text
        super.init(location: location)
    }
}

class TweeLetStatement : TweeStatement {
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

class TweeIfStatement : TweeStatement {
    enum ElseClause {
        case Else(block: TweeCodeBlock)
        case ElseIf(ifStatement: TweeIfStatement)
    }

    let condition : TweeExpression
    let block = TweeCodeBlock()
    var elseClause : ElseClause?

    init(location: TweeLocation, condition: TweeExpression) {
        self.condition = condition
        super.init(location: location)
    }
}


//  stmt ->
//    newline
//    silently (stmts)
//    text (string)
//    let (var, expr)
//    expr  (see below)  // when used like this, represents conversion of expression to string
//    if (expr, stmts, else)

//  else ->
//    stmts
//    elseif -> if (expr, stmts, else)

//  stmts ->
//    [stmt]

//  expr ->
//    literal (type {number, boolean, string}, value)
//    var (name)
//    binop (op, expr1, expr2)  {+ - * / == != < > <= >=}
//    unop (op, expr1)  {+ - !}

//  synonyms:
//    ==    is, eq
//    !=    isnt, ne, ne
//    <     lt
//    <=    le, lte
//    >     gt
//    >=    ge, gte

class TweeExpression {
    
}

