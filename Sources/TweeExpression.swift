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

class TweeExpression : CustomStringConvertible {
    let string : String
    let location : TweeLocation?
    let parsed : ParsedExpression
    
    let error : TweeError?
    let variables : Set<String>
    
    var description: String { return string }

    init(_ string: String, location: TweeLocation? = nil) {
        self.string = TweeExpression.fromTwee(string)
        self.location = location
        self.parsed = Expression.parse(self.string, usingCache: false)
        
        var variables = [String]()
        var syntaxError : String?

        // Examine the parsed expression, and look for any errors
        // Also collect variable references by name
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
                    break
                }
            }
        }
        if syntaxError != nil {
            self.error = TweeError(type: .InvalidExpression, location: location, message: syntaxError!)
        } else {
            self.error = nil
        }
        self.variables = Set(variables)
    }
    
    func eval<T>(variables: [String:Any] = [:]) throws -> T {
        if error != nil { throw error! }
        let expr = AnyExpression(parsed, impureSymbols: { symbol in
            switch symbol {
            case .variable("null"):
                return { _ in NSNull() }  // AnyExpression doesn't handle this, so we have to implement it explicitly
            case .variable(let name):
                if name.first == "$" {
                    if let value = variables[name] {
                        return { _ in value }
                    }
                }
            case .function("visited", 0):
                return { _ in TweeExpression.visited() }
            case .function("visited", 1):
                return { args in TweeExpression.visited(args[0] as? String) }
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
        return vals[Random.getRandomNum(vals.endIndex)]
    }

    // For now, implement visited by simply returning false.  Need to handle game history.
    static func visited(_ passage: String? = nil) -> Bool {
        return false
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


// WTF swift, you don't provide a cross-platform random function!
// And worse, the Linux version requires initialization, which requires a singleton.
class Random {
    static let instance = Random()
    private init() {
        #if os(Linux)
            srandom(UInt32(time(nil)))
        #endif
    }

    private func getRandomNum(_ max: Int) -> Int {
        #if os(Linux)
            return Int(random() % max)
        #else
            return Int(arc4random_uniform(UInt32(max)))
        #endif
    }
    
    static func getRandomNum(_ max: Int) -> Int {
        return instance.getRandomNum(max)
    }
}

