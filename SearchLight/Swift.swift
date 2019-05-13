//
//  Swift.swift
//  SearchLight
//
//  Created by John Holdsworth on 07/03/2018.
//  Copyright © 2018 John Holdsworth. All rights reserved.
//

import Foundation

@objc
class Highlight: NSObject {

    @objc
    static func html(for string: String) -> String {
        let classes = ["\"": "string", "//": "comment",
                       "/*": "comment", "*/": "comment"]
        return tokenize(string).map { switch $0 {
        case .keyword(let word):
            return "<span class=keyword>\(word)</span>"
        case .identifier(let word):
            return "<span class=identifier>\(word)</span>"
        case .startOfScope(let delimiter):
            let type = classes[delimiter, default: ""]
            return type == "" ? delimiter : "<span class=\(type)>\(delimiter)</span>"
        case .stringBody(let body):
            return "<span class=string>\(body)</span>"
        case .commentBody(let body):
            return "<span class=comment>\(body)</span>"
        case .endOfScope(let delimiter):
            let type = classes[delimiter, default: ""]
            return type == "" ? delimiter :  "<span class=\(type)>\(delimiter)</span>"
        case .number(let (number, _)):
            return "<span class=number>\(number)</span>"
        default:
            return $0.string
            }
        }.joined()
    }
}
