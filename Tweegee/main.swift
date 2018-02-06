//
//  main.swift
//  Tweegee
//
//  Created by Carter Thaxton on 1/16/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation
import Commander


command(
    Argument<String>("filename", description: "Twee file to parse"),
    Flag("useThis", default: true),
    Option("count", default: 1, description: "The number of times to print.")
) { filename, useThis, count in
    print("Parsing twee file: \(filename)")
    print("useThis: \(useThis)  count: \(count)")

    let parser = TweeParser()
    do {
        var tokens = 0
        try parser.parse(filename: filename) { (token) in
            tokens += 1
//            print(token)
        }
        print("Parsed: \(tokens) tokens")
    } catch {
        print("Error while parsing \(filename): \(error)")
    }
    
}.run()
