//
//  LHWQueue.swift
//  ActionStageSwift
//
//  Created by Hanguang on 2017/3/7.
//  Copyright © 2017年 Hanguang. All rights reserved.
//

import Foundation

final class LHWQueue: NSObject {
    // MARK: -
    private var _isMainQueue = false
    private var queue: DispatchQueue?
    private var name: String
    private let queueSpecificKey = DispatchSpecificKey<String>()
    private static let _mainQueue: LHWQueue = LHWQueue()
    
    private override init() {
        self.name = "com.hanguang.LHWQueue.MainQueue"
        self.queue = DispatchQueue.main
        self._isMainQueue = true
    }
    
    init(name: String) {
        self.name = name
        self.queue = DispatchQueue(label: name)
        self.queue?.setSpecific(key: queueSpecificKey, value: name)
    }
    
    deinit {
        queue = nil
    }
    
    // MARK: -
    func mainQueue() -> LHWQueue {
        return ._mainQueue
    }
    
    func nativeQueue() -> DispatchQueue? {
        return queue
    }
    
    func isCurrentQueue() -> Bool {
        if queue == nil {
            return false
        }
        
        if _isMainQueue {
            return Thread.isMainThread
        } else {
            return DispatchQueue.getSpecific(key: queueSpecificKey) == name
        }
    }
    
    func dispatchOnQueue(_ closure: @escaping () -> Void, synchronous: Bool) {
        if let queue = queue {
            if _isMainQueue {
                if Thread.isMainThread {
                    closure()
                } else if synchronous {
                    queue.sync { closure() }
                } else {
                    queue.async { closure() }
                }
            } else {
                if DispatchQueue.getSpecific(key: queueSpecificKey) == name {
                    closure()
                } else if synchronous {
                    queue.sync { closure() }
                } else {
                    queue.async { closure() }
                }
            }
        }
    }
}
