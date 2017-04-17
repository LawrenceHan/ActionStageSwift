//
//  TestViewController.swift
//  ActionStageSwift
//
//  Created by Hanguang on 17/04/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import UIKit

class TestViewController: UIViewController, LHWWatcher {

    var actionHandler: LHWHandler?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissVC))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addCell))
        
        actionHandler = LHWHandler(delegate: self)
        ActionStageInstance.watchForPath("/mg/newcell/(11)", watcher: self)

    }

    func dismissVC() {
        dismiss(animated: true, completion: nil)
    }

    func addCell(_ sender: UIBarButtonItem) {
        let options = ["text": "new cell"]
        ActionStageInstance.requestActor(path: "/mg/newcell/(11)", options: options, watcher: self)
    }
    
    func actorCompleted(status: LHWActionStageStatus, path: String, result: Any?) {
        Logger.debug("\(path) is done")
    }
    
    func actionStageResourceDispatched(path: String, resource: Any?, arguments: Any?) {
        if path == "/mg/newcell/(11)" {
            let text = resource as! String
            
            LHWDispatchOnMainThread {
                Logger.debug(text)
            }
        }
    }
    
    deinit {
        actionHandler?.reset()
        ActionStageInstance.removeWatcher(self)
    }
}
