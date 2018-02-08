//
//  main.swift
//  Tweegee
//
//  Created by Carter Thaxton on 1/16/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation


func runLexOnly(filename: String) {
    print("Lexing twee file: \(filename)")
    
    let lexer = TweeLexer()
    do {
        var tokens = 0
        try lexer.lex(filename: filename) { (token, location) in
            tokens += 1
            //            print(token, location)
        }
        print("Lexed \(tokens) tokens")
    } catch {
        print("Error while lexing \(filename): \(error)")
    }
}


func runParse(filename: String) {
    print("Parsing twee file: \(filename)")
    
    let parser = TweeParser()
    do {
        let story = try parser.parse(filename: filename)
        print("Parsed \(story.passages.count) passages")
    } catch {
        print("Error while parsing \(filename): \(error)")
    }
}

func showHelp() -> Never {
    print("""
        Usage: tweegee [--lexOnly] <filename>
    """)
    exit(1)
}

var lexOnly = false
var filename : String?

for arg in CommandLine.arguments {
    if arg.starts(with: "-") {
        switch arg {
        case "--lexOnly":
            lexOnly = true
        default:
            showHelp()
        }
    } else {
        filename = arg
    }
}

guard let filename = filename else {
    showHelp()
}

if lexOnly {
    runLexOnly(filename: filename)
} else {
    runParse(filename: filename)
}

