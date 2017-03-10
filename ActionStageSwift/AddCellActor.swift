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
        return "/mg/newcell"
    }
    
    override func execute(options: [String: Any]?) {
        let text = "new cell"
        LHWActionStage.instance.dispatchResource(path: "/mg/newcell", resource: text, arguments: nil)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            LHWActionStage.instance.actionCompleted("/mg/newcell")
        }
    }
}
