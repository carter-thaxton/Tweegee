//
//  TweeAction.swift
//  Tweegee
//
//  Created by Carter Thaxton on 3/6/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

enum TweeAction : Equatable {
    case Message(text: String)
    case Choice(choices: [TweeChoice])
    case Delay(text: String?, delay: TweeDelay)
    case Error(error: TweeError)
    case End
}

func ==(lhs: TweeAction, rhs: TweeAction) -> Bool {
    switch (lhs, rhs) {
    case (.Message(let text), .Message(let text2)):
        return text == text2
    case (.Choice(let choices), .Choice(let choices2)):
        return choices == choices2
    case (.Delay(let text, let delay), .Delay(let text2, let delay2)):
        return text == text2 && delay == delay2
    case (.Error(let error), .Error(let error2)):
        return error == error2
    case (.End, .End):
        return true
    default:
        return false
    }
}

struct TweeChoice : Equatable {
    let name: String
    let title: String?
}

func ==(lhs: TweeChoice, rhs: TweeChoice) -> Bool {
    return lhs.name == rhs.name &&
        lhs.title == rhs.title
}
