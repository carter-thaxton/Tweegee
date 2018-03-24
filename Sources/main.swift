//
//  main.swift
//  Tweegee
//
//  Created by Carter Thaxton on 1/16/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation


// MARK: Parse command-line arguments
var play = false
var json = false
var noPassages = false
var filename : String?

func showHelp() -> Never {
    print("""
    Usage: tweegee [options] <filename>

    Options:
           --play           Play the game at the command-line
           --json           Produce JSON as a result
           --no-passages    No passage contents in output, only errors and statistics (only with --json)
    """)
    exit(1)
}

func parseCommandLine() {
    for arg in CommandLine.arguments.dropFirst() {
        if arg.starts(with: "-") {
            switch arg {
            case "--play":
                play = true
            case "--json":
                json = true
            case "--no-passages":
                noPassages = true
            default:
                showHelp()
            }
        } else {
            filename = arg
        }
    }
}

func run() {
    parseCommandLine()

    guard let filename = filename else {
        showHelp()
    }

    let parser = TweeParser()
    let story : TweeStory
    do {
        story = try parser.parse(filename: filename)
    } catch {
        print("Unexpected error while parsing \(filename): \(error)")
        exit(2)
    }
    
    if json {
        do {
            let jsonData = story.asJson(includePassages: !noPassages)
            let jsonString = try toJsonString(jsonData)
            print(jsonString)
        } catch {
            print("Unexpected error while producing JSON: \(error)")
            exit(2)
        }
    } else {
        for error in story.errors {
            print(error)
        }
        print("Parsed \(story.passageCount) passages, \(story.wordCount) words, \(story.errors.count) errors")
    
        if !story.errors.isEmpty {
            exit(1)
        }

        if play {
            do {
                try playGame(story: story)
            } catch {
                print("Error while playing game: \(error)")
                exit(2)
            }
        }
    }
}

func playGame(story: TweeStory) throws {
    let engine = TweeEngine(story: story)

    while true {
        let action = try engine.getNextAction()
        switch action {
        case .Passage:
            // ignore passage boundaries
            break

        case .Message(let text):
            print(text)

        case .Delay(let text, let delay):
            print("\(text) - (\(delay))")

        case .Choice(let choices):
            if let passage = promptForChoice(choices) {
                try engine.makeChoice(passage: passage)
            } else {
                // EOF while waiting for choice
                return
            }
        
        case .Prompt(let text):
            print(text)
            if !prompt() {
                // EOF while waiting for prompt
                return
            }
            
        case .Rewind(let passage):
            print("<<< Rewind to: \(passage) <<<")

        case .End:
            return
        }
    }
}

func promptForChoice(_ choices: [TweeChoice]) -> String? {
    while true {
        let choiceString = choices.enumerated().map({ i,c in return "[\(i+1): \(c.text)]" }).joined(separator: " ")
        print("Choose: \(choiceString)")

        guard let response = readLine() else { return nil }
        if let index = Int(response) {
            if index > 0 && index <= choices.count {
                return choices[index-1].passage
            }
        }
        print("Bad choice.")
    }
}

func prompt() -> Bool {
    print("Press enter to continue:")
    let result = readLine()
    return result != nil
}

// MARK: Run program
run()
