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
        
        DispatchQueue.global().asyncAfter(deadline: .now()+3) {
            print("I'm still here!")
        }
        
        view.backgroundColor = UIColor.white
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissVC))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(notify))
        
        actionHandler = LHWHandler(delegate: self)
        Actor.watchForPath("/mg/newcell/(11)", watcher: self)

    }

    @objc func dismissVC() {
        dismiss(animated: true, completion: nil)
    }

    @objc func notify(_ sender: UIBarButtonItem) {
        Actor.dispatchMessageToWatchers(path: "/mg/newcell/(11)")
    }
    
    func actorMessageReceived(path: String, messageType: String?, message: Any?) {
        if path == "/mg/newcell/(11)" {
            LHWDispatchOnMainThread {
                let options = ["text": "new cell (3)"]
                Actor.requestActor(path: "/mg/newcell/(13)", options: options, watcher: self)
            }
        }
    }
    
    func actorCompleted(status: LHWActionStageStatus, path: String, result: Any?) {
        print("\(path) is done")
    }
    
    deinit {
        actionHandler?.reset()
        Actor.removeWatcher(self)
    }
}
