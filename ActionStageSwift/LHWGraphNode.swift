//
//  LHWGraphNode.swift
//  ActionStageSwift
//
//  Created by Hanguang on 2017/3/7.
//  Copyright © 2017年 Hanguang. All rights reserved.
//

import Foundation

@objc class LHWGraphObjectNode: LHWGraphNode {
    var items: [Any] = [Any]()
    
    init(items: [Any]) {
        self.items = items
    }
}

@objc class LHWGraphNode: NSObject {
    
}
