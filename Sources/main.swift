//
//  main.swift
//  Tweegee
//
//  Created by Carter Thaxton on 1/16/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation


func runLexOnly(filename: String) {
    let lexer = TweeLexer()
    do {
        var tokens = 0
        try lexer.lex(filename: filename) { (token, location) in
            tokens += 1
        }
        print("Lexed \(tokens) tokens")
    } catch {
        print("Error while lexing \(filename): \(error)")
    }
}


func runParse(filename: String) {
    let parser = TweeParser()
    do {
        let story = try parser.parse(filename: filename)
        let jsonData = story.asJson()
        let jsonString = try toJsonString(jsonData)
        print(jsonString)

    } catch let error as TweeErrorLocation {
        print("Error on line: \(error.location.lineNumber) - \(error.message)")
        if let line = error.location.line {
            print(line)
        }
    } catch {
        print("Unexpected error while parsing \(filename): \(error)")
    }
}

func toJsonString(_ data: Any) throws -> String {
    var opts : JSONSerialization.WritingOptions = [.prettyPrinted]
    if #available(macOS 10.13, *) {
        opts.formUnion(.sortedKeys)
    }
    let serialized = try JSONSerialization.data(withJSONObject: data, options: opts)
    return String(data: serialized, encoding: .utf8)!
}

func showHelp() -> Never {
    print("""
    Usage: tweegee [--lexOnly] <filename>
    """)
    exit(1)
}


// MARK: Parse command-line arguments
var lexOnly = false
var filename : String?

for arg in CommandLine.arguments.dropFirst() {
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


// MARK: Run command-line tool
guard let filename = filename else {
    showHelp()
}

if lexOnly {
    runLexOnly(filename: filename)
} else {
    runParse(filename: filename)
}

