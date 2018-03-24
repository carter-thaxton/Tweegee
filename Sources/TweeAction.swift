//
//  TweeAction.swift
//  Tweegee
//
//  Created by Carter Thaxton on 3/6/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

enum TweeAction : Equatable {
    case Passage(passage: String)
    case Message(text: String)
    case Choice(choices: [TweeChoice])
    case Delay(text: String, delay: TweeDelay)
    case Prompt(text: String)
    case Rewind(passage: String)
    case End
}

func ==(lhs: TweeAction, rhs: TweeAction) -> Bool {
    switch (lhs, rhs) {
    case (.Passage(let passage), .Passage(let passage2)):
        return passage == passage2
    case (.Message(let text), .Message(let text2)):
        return text == text2
    case (.Choice(let choices), .Choice(let choices2)):
        return choices == choices2
    case (.Delay(let text, let delay), .Delay(let text2, let delay2)):
        return text == text2 && delay == delay2
    case (.Prompt(let text), .Prompt(let text2)):
        return text == text2
    case (.Rewind(let passage), .Rewind(let passage2)):
        return passage == passage2
    case (.End, .End):
        return true
    default:
        return false
    }
}

struct TweeChoice : Equatable {
    let passage: String
    let text: String
}

func ==(lhs: TweeChoice, rhs: TweeChoice) -> Bool {
    return lhs.passage == rhs.passage && lhs.text == rhs.text
}
