//
//  TweeError.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/7/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

enum TweeError : Error, Equatable {
    case InvalidLinkSyntax
    case InvalidMacroSyntax
    case DuplicatePassageName
    case TextOutsidePassage
}

struct TweeErrorLocation : Error {
    let error : Error
    let location : TweeLocation
}

struct TweeLocation {
    var filename : String?
    var line : String?
    var lineNumber : Int?
}
