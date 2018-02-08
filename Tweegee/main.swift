//
//  main.swift
//  Tweegee
//
//  Created by Carter Thaxton on 1/16/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation
import Commander


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


command(
    Argument<String>("filename", description: "Twee file to parse"),
    Flag("lexOnly", default: false, description: "Only lex and do not parse the file")
//    Option("count", default: 1, description: "The number of times to print.")
) { filename, lexOnly in

    if lexOnly {
        runLexOnly(filename: filename)
    } else {
        runParse(filename: filename)
    }
    
}.run()

