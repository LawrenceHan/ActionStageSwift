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
        
        LHWActionStage.instance.dispatchResource(path: path, resource: text, arguments: nil)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            LHWActionStage.instance.actionCompleted(self.path)
        }
    }
}
