//
//  JSONHelpers.swift
//  Tweegee
//
//  Created by Carter Thaxton on 2/20/18.
//  Copyright © 2018 Carter Thaxton. All rights reserved.
//

import Foundation

typealias Dict = [String:Any]
typealias DictArr = [Dict]

protocol AsJson {
    func asJson() -> Dict
}

func toJsonString(_ data: Any) throws -> String {
    var opts : JSONSerialization.WritingOptions = [.prettyPrinted]
    if #available(macOS 10.13, iOS 11.0, *) {
        opts.formUnion(.sortedKeys)
    }
    let serialized = try JSONSerialization.data(withJSONObject: data, options: opts)
    return String(data: serialized, encoding: .utf8)!
}

func debugJson(_ obj: AsJson) {
    print(try! toJsonString(obj.asJson()))
}
