//
//  TweeError.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/7/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

struct TweeError : Error, AsJson {
    let type : TweeErrorType
    let location : TweeLocation?
    let message : String
    
    func asJson() -> Dict {
        if let location = location {
            return ["type": String(describing: type), "passage": location.passage ?? NSNull(), "passageLineNumber": location.passageLineNumber,
                    "lineNumber": location.lineNumber, "line": location.line ?? NSNull(), "message": message]
        } else {
            return ["type": String(describing: type), "message": message]
        }
    }
}

enum TweeErrorType : Equatable {
    case InvalidLinkSyntax
    case InvalidMacroSyntax
    case InvalidChoiceSyntax
    case DuplicatePassageName
    case TextOutsidePassage
    case MissingIf
    case MissingEndIf
    case DuplicateElse
    case MissingEndSilently
    case MissingDelay
    case MissingExpression
    case UnexpectedExpression
    case InvalidExpression
    case UnrecognizedMacro
    case InvalidTwee2Settings
    case MissingPassage
    case UnreferencedPassage
}
