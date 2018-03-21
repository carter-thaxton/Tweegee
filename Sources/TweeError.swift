//
//  TweeError.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/7/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

struct TweeError : Error, Equatable, CustomStringConvertible, AsJson {
    let type : TweeErrorType
    let location : TweeLocation?
    let message : String

    func asJson() -> Dict {
        return self.asJson(story: nil)
    }

    func asJson(story: TweeStory?) -> Dict {
        if let location = location {
            let line = location.getLine(story: story)
            return ["type": String(describing: type), "passage": location.passage ?? NSNull(), "passageLineNumber": location.passageLineNumber,
                    "fileLineNumber": location.fileLineNumber, "line": line ?? NSNull(), "message": message]
        } else {
            return ["type": String(describing: type), "message": message]
        }
    }

    var description: String {
        if location?.passage != nil && location?.passageLineNumber != 0 {
            return "Error on line \(location!.fileLineNumber) (line \(location!.passageLineNumber) of passage '\(location!.passage!)'): \(message)"
        } else if location != nil {
            return "Error on line \(location!.fileLineNumber): \(message)"
        } else {
            return "Error: \(message)"
        }
    }
}

func ==(lhs: TweeError, rhs: TweeError) -> Bool {
    return lhs.type == rhs.type &&
        lhs.location == rhs.location &&
        lhs.message == rhs.message
}


enum TweeErrorType : Equatable {
    case UnknownError
    case UnexpectedText
    case InvalidLinkSyntax
    case InvalidMacroSyntax
    case InvalidChoiceSyntax
    case InvalidDelaySyntax
    case InvalidPromptSyntax
    case UnmatchedIf
    case UnmatchedSilently
    case UnmatchedDelay
    case UnmatchedChoice
    case UnmatchedPrompt
    case DuplicateElse
    case DuplicatePassageName
    case UnexpectedExpression
    case MissingExpression
    case InvalidExpression
    case UndefinedVariable
    case UnrecognizedMacro
    case InvalidTwee2Settings
    case MissingPassage
    case UnreferencedPassage
    case RuntimeError
}

