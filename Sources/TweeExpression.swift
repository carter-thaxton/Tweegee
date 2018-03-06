//
//  TweeExpression.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/19/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

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

class TweeExpression {
    let string : String
    let location : TweeLocation?
    let parsed : ParsedExpression
    
    let error : TweeError?
    let variables : [String]

    init(_ string: String, location: TweeLocation? = nil) {
        self.string = TweeExpression.fromTwee(string)
        self.location = location
        self.parsed = Expression.parse(self.string)
        
        var variables = [String]()
        var syntaxError : String?

        if parsed.error != nil {
            syntaxError = parsed.error!.description
        } else {
            for symbol in parsed.symbols {
                switch symbol {
                case .function(let name, arity: .exactly(let arity)):
                    switch name {
                    case "visited":
                        if arity > 1 {
                            syntaxError = "visited() function takes 0 or 1 arguments"
                        }
                    case "either":
                        if arity < 1 {
                            syntaxError = "either() function requires at least 1 argument"
                        }
                    case "[]":
                        // allow this
                        break
                    default:
                        syntaxError = "Invalid function: \(name)"
                    }

                case .variable(let name):
                    if name.first == "'" || name.first == "\"" {
                        // allow literal strings in quotes
                    } else if name == "true" || name == "false" || name == "null" {
                        // these keywords are fine
                    } else if name.first == "$" {
                        variables.append(name)
                    } else {
                        syntaxError = "Invalid variable: \(name).  Variables must begin with a $ symbol"
                    }

                default:
                    // for now allow everything else
                    // syntaxError = "Invalid symbol in expression: \(symbol)"
                    break
                }
            }
        }
        if syntaxError != nil {
            self.error = TweeError(type: .InvalidExpression, location: location, message: syntaxError!)
        } else {
            self.error = nil
        }
        self.variables = variables
    }
    
    func eval<T>(variables: [String:Any] = [:]) throws -> T {
        if error != nil { throw error! }
        let expr = AnyExpression(parsed, impureSymbols: { symbol in
            switch symbol {
            case .variable("null"):
                return { _ in NSNull() }  // have to implement this explicitly
            case .variable(let name):
                if name.first == "$" {
                    if let value = variables[name] {
                        return { _ in value }
                    }
                }
            case .function("visited", 0):
                return { _ in false }
            case .function("visited", 1):
                return { _ in false }
            case .function("either", .any):
                return { args in TweeExpression.either(args) }
            default:
                break
            }
            return nil
        })
        do {
            return try expr.evaluate()
        } catch {
            // wrap in a TweeError
            throw TweeError(type: .InvalidExpression, location: location, message: "\(error)")
        }
    }
    
    // Implement the 'either' function, which chooses a random value from the given values
    static func either(_ vals: [Any]) -> Any {
        // WTF swift!
        return vals[Int(arc4random_uniform(UInt32(vals.endIndex)))]
    }

    static func fromTwee(_ string: String) -> String {
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
