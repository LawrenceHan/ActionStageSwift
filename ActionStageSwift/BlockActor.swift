//
//  BlockActor.swift
//  ActionStageSwift
//
//  Created by Hanguang on 22/08/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import Foundation

final class BlockActor: LHWActor {
    override class func genericPath() -> String? {
        return "/mg/block"
    }
    
    override func execute(options: [String : Any]?, completion: ((String, Any?, Any?) -> Void)?) {
        if let completion = completion {
            completion(path, "Hello World", "block")
        } else {
            Actor.dispatchResource(path: path, resource: "Hello World", arguments: "delegate")
        }
        Actor.actionCompleted(path)
    }
}
