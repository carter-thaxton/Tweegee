//
//  StoryToJSON.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/19/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

typealias Dict = [String: Any]
typealias DictArr = [Dict]

func toJSON(story: TweeStory) -> Dict {
    var result = Dict()
    result["start"] = "Start"
    result["passageCount"] = story.passageCount

    var passages = DictArr()
    for passage in story.passagesInOrder {
        passages.append(passage.toJSON())
    }
    result["passages"] = passages

    return result
}

protocol ToJSON {
    func toJSON() -> Dict
}

extension TweeStatement : ToJSON {
    @objc func toJSON() -> Dict {
        fatalError("Cannot call toJSON() on top-level twee statement")
    }
}

extension TweePassage {
    override func toJSON() -> Dict {
        var statements = DictArr()
        for stmt in self.block.statements {
            statements.append(stmt.toJSON())
        }
        return ["name": self.name, "tags": self.tags, "statements": statements]
    }
}

extension TweeTextStatement {
    override func toJSON() -> Dict {
        return ["type": "text", "text": self.text]
    }
}

extension TweeNewlineStatement {
    override func toJSON() -> Dict {
        return ["type": "newline"]
    }
}

extension TweeLinkStatement {
    override func toJSON() -> Dict {
        return ["type": "link", "name": self.name, "title": self.title ?? NSNull()]
    }
}

extension TweeChoiceStatement {
    override func toJSON() -> Dict {
        return ["type": "choice"]
    }
}

extension TweeExpressionStatement {
    override func toJSON() -> Dict {
        return ["type": "expression"]
    }
}

extension TweeSetStatement {
    override func toJSON() -> Dict {
        return ["type": "set"]
    }
}

