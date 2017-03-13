//
//  AActor.swift
//  ActionStageSwift
//
//  Created by Hanguang on 10/03/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import Foundation

class AddCellActor: LHWActor {
    
//    override class func initialize() {
//        LHWActor.registerActorClass(AddCellActor.self)
//    }
    
    override class func genericPath() -> String? {
        return "/mg/newcell/@"
    }
    
    override func execute(options: [String: Any]?) {
        guard let options = options else {
            return
        }
        
        guard let text = options["text"] as? String else {
            return
        }
        
        ActionStageInstance.dispatchResource(path: path, resource: text, arguments: nil)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            ActionStageInstance.actionCompleted(self.path)
        }
    }
    
    override func watcherJoined(watcherHandler: LHWHandler, options: [String : Any]?, waitingInActorQueue: Bool) {
        print("joined handler: \(watcherHandler), options: \(options), path: \(path)")
    }
}
