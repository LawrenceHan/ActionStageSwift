//
//  LHWWatcher.swift
//  ActionStageSwift
//
//  Created by Hanguang on 2017/3/7.
//  Copyright © 2017年 Hanguang. All rights reserved.
//

import Foundation

@objc protocol LHWWatcher {
    var actionHandler: LHWHandler { get }
    
    @objc optional func actorCompleted(status: Int, path: String, result: Any?)
    @objc optional func actorReportedProgress(path: String, progress: Float)
    @objc optional func actionStageResourceDispatched(path: String, resource: Any?, arguments: Any?)
    @objc optional func actionStageActionRequested(_ action: String, options: Dictionary<String, Any>?)
    @objc optional func actorMessageReceived(path: String, messageType: String?, message: Any?)
}
