//
//  LHWHandler.swift
//  ActionStageSwift
//
//  Created by Hanguang on 2017/3/7.
//  Copyright © 2017年 Hanguang. All rights reserved.
//

import Foundation

class LHWHandler: NSObject {
    // MARK: -
    var delegate: LHWWatcher? {
        get {
            var result: LHWWatcher? = nil
            
            LHW_MUTEXLOCKER_LOCK(&_delegateLock)
            result = self.delegate
            LHW_MUTEXLOCKER_UNLOCK(&_delegateLock)
            
            return result
        }
        
        set {
            LHW_MUTEXLOCKER_LOCK(&_delegateLock)
            self.delegate = newValue
            LHW_MUTEXLOCKER_UNLOCK(&_delegateLock)
        }
    }
    var releaseOnMainThread: Bool
    
    private var _delegateLock: pthread_mutex_t
    // MARK: -
    init(delegate: LHWWatcher, releaseOnMainThread: Bool = false) {
        self.releaseOnMainThread = releaseOnMainThread
        _delegateLock = LHW_MUTEXLOCKER_INIT()
        super.init()
        self.delegate = delegate
    }
    
    // MARK: -
    func reset() {
        LHW_MUTEXLOCKER_LOCK(&_delegateLock)
        delegate = nil
        LHW_MUTEXLOCKER_UNLOCK(&_delegateLock)
    }
    
    func hasDelegate() -> Bool {
        var result = false
        
        LHW_MUTEXLOCKER_LOCK(&_delegateLock)
        result = delegate != nil
        LHW_MUTEXLOCKER_UNLOCK(&_delegateLock)
        
        return result
    }
    
    func requestAction(_ action: String, options: Dictionary<String, Any>) {
        guard let delegate = delegate else { return }
        
        delegate.actionStageActionRequested?(action, options: options)
        
        if releaseOnMainThread && !Thread.isMainThread {
            DispatchQueue.main.async {
                _ = self.delegate.self
            }
        }
    }
    
    func receiveActorMessage(path: String, messageType: String? = nil, message: Any? = nil) {        
        delegate?.actorMessageReceived?(path: path, messageType: messageType, message: message)
        
        if releaseOnMainThread && !Thread.isMainThread {
            DispatchQueue.main.async {
                _ = self.delegate.self
            }
        }
    }
    
    func notifyResourceDispatched(path: String, resource: Any, arguments: Any? = nil) {
        guard let delegate = delegate else { return }
        
        delegate.actionStageResourceDispatched?(path: path, resource: resource, arguments: arguments)
        
        if releaseOnMainThread && !Thread.isMainThread {
            DispatchQueue.main.async {
                _ = self.delegate.self
            }
        }
    }
}
