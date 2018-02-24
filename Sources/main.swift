//
//  main.swift
//  Tweegee
//
//  Created by Carter Thaxton on 1/16/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation


// MARK: Parse command-line arguments
var noPassages = false
var filename : String?

func showHelp() -> Never {
    print("""
    Usage: tweegee [options] <filename>

    Options:
           --no-passages    Do not include passage contents in output, only errors and statistics
    """)
    exit(1)
}

func parseCommandLine() {
    for arg in CommandLine.arguments.dropFirst() {
        if arg.starts(with: "-") {
            switch arg {
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
    do {
        let story = try parser.parse(filename: filename)

        let jsonData = story.asJson(includePassages: !noPassages)
        let jsonString = try toJsonString(jsonData)
        print(jsonString)

        if !story.errors.isEmpty {
            exit(1)
        } else {
            exit(0)
        }
    } catch {
        print("Unexpected error while parsing \(filename): \(error)")
        exit(2)
    }
}

// MARK: Run program
run()
