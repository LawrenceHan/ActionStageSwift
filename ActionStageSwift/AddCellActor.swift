//
//  AActor.swift
//  ActionStageSwift
//
//  Created by Hanguang on 10/03/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import Foundation

class AddCellActor: LHWActor {
    
    override class func genericPath() -> String? {
        return "/mg/newcell/@"
    }
    
    override func prepare(options: [String : Any]?) {
        requestQueueName = "addCellQueue"
    }
    
    override func execute(options: [String: Any]?) {
        guard let options = options else {
            return
        }
        
        guard let text = options["text"] as? String else {
            return
        }
        
        Actor.dispatchResource(path: path, resource: text, arguments: nil)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let `self` = self else { return }
            Actor.actionCompleted(self.path)
        }
    }
}
