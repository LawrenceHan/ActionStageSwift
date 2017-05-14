//
//  LHWHandler.swift
//  ActionStageSwift
//
//  Created by Hanguang on 2017/3/7.
//  Copyright © 2017年 Hanguang. All rights reserved.
//
// Copyright (c) 2017年 Hanguang
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

public final class LHWHandler {
    
    // MARK: -
    
    fileprivate weak var _delegate: LHWWatcher?
    public weak var delegate: LHWWatcher? {
        get {
            var result: LHWWatcher?
            
            LHW_MUTEXLOCKER_LOCK(&_delegateLock)
            result = _delegate
            LHW_MUTEXLOCKER_UNLOCK(&_delegateLock)
            
            return result
        }
        
        set {
            LHW_MUTEXLOCKER_LOCK(&_delegateLock)
            _delegate = newValue
            LHW_MUTEXLOCKER_UNLOCK(&_delegateLock)
        }
    }
    public var releaseOnMainThread: Bool
    fileprivate var _delegateLock: pthread_mutex_t
    
    // MARK: -
    
    public init(delegate: LHWWatcher, releaseOnMainThread: Bool = false) {
        self.releaseOnMainThread = releaseOnMainThread
        _delegateLock = LHW_MUTEXLOCKER_INIT()
        self._delegate = delegate
    }
    
    // MARK: -
    
    public func reset() {
        LHW_MUTEXLOCKER_LOCK(&_delegateLock)
        _delegate = nil
        LHW_MUTEXLOCKER_UNLOCK(&_delegateLock)
    }
    
    public func hasDelegate() -> Bool {
        var result = false
        
        LHW_MUTEXLOCKER_LOCK(&_delegateLock)
        result = _delegate != nil
        LHW_MUTEXLOCKER_UNLOCK(&_delegateLock)
        
        return result
    }
    
    public func requestAction(_ action: String, options: [String: Any]?) {
        delegate?.actionStageActionRequested(action, options: options)
        if releaseOnMainThread && !Thread.isMainThread {
            DispatchQueue.main.async {
                _ = self._delegate.self
            }
        }
    }
    
    public func receiveActorMessage(path: String, messageType: String? = nil, message: Any? = nil) {
        delegate?.actorMessageReceived(path: path, messageType: messageType, message: message)
        if releaseOnMainThread && !Thread.isMainThread {
            DispatchQueue.main.async {
                _ = self._delegate.self
            }
        }
    }
    
    public func notifyResourceDispatched(path: String, resource: Any, arguments: Any? = nil) {
        delegate?.actionStageResourceDispatched(path: path, resource: resource, arguments: arguments)
        if releaseOnMainThread && !Thread.isMainThread {
            DispatchQueue.main.async {
                _ = self._delegate.self
            }
        }
    }
}

/*
extension LHWHandler: Equatable {
    open static func ==(lhs: LHWHandler, rhs: LHWHandler) -> Bool {
        if lhs.delegate === rhs.delegate {
            return true
        } else {
            return false
        }
    }
}
*/
