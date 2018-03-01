//
//  TweeExpression.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/19/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

//  expr ->
//    literal (type {number, boolean, string}, value)
//    var (name)
//    binop (op, expr1, expr2)  {+ - * / == != < > <= >=}
//    unop (op, expr1)  {+ - !}

//  synonyms:
//    !     not
//    &&    and
//    ||    or
//    ==    is, eq
//    !=    isnt, ne, neq
//    <     lt
//    <=    le, lte
//    >     gt
//    >=    ge, gte

// TODO: finish this.  for now, just store a string
class TweeExpression {
    let string : String

    init(from string: String) {
        self.string = TweeExpression.normalize(string)
    }

    static func normalize(_ string: String) -> String {
        return string
            .replacing(pattern: "\\b(not)\\b", with: "!")
            .replacing(pattern: "\\b(and)\\b", with: "&&")
            .replacing(pattern: "\\b(or)\\b", with: "||")
            .replacing(pattern: "\\b(is|eq)\\b", with: "==")
            .replacing(pattern: "\\b(isnt|ne|neq)\\b", with: "!=")
            .replacing(pattern: "\\b(lt)\\b", with: "<")
            .replacing(pattern: "\\b(le|lte)\\b", with: "<=")
            .replacing(pattern: "\\b(gt)\\b", with: ">")
            .replacing(pattern: "\\b(ge|gte)\\b", with: ">=")
    }
}
