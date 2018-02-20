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
//    ==    is, eq
//    !=    isnt, ne, ne
//    <     lt
//    <=    le, lte
//    >     gt
//    >=    ge, gte

// TODO: finish this.  for now, just store a string
class TweeExpression {
    let string : String

    init(from string: String) {
        self.string = string
    }
}
