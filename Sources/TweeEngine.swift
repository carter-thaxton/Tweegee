//
//  TweeEngine.swift
//  Tweegee
//
//  Created by Carter Thaxton on 3/6/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

class TweeEngine {
    let story : TweeStory

    var currentPassage : TweePassage? = nil
    var currentBlock : TweeCodeBlock? = nil
    var currentStatementIndex : Int = -1

    var currentStatement : TweeStatement? {
        return currentBlock?.statements[currentStatementIndex]
    }

    init(story: TweeStory) {
        self.story = story
        
        guard let startPassage = story.startPassage else { return }
        gotoPassage(startPassage)
    }

    func gotoPassage(_ passage: TweePassage) {
        currentPassage = passage
        currentBlock = passage.block
        currentStatementIndex = 0
    }
    
    func getNextAction() -> TweeAction {
        return .End
    }
    
}
