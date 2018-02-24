//
//  TweeError.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/7/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

struct TweeError : Error {
    let type : TweeErrorType
    let location : TweeLocation
    let message : String
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
}

struct TweeLocation {
    var filename : String?
    var line : String?
    var lineNumber : Int
}
