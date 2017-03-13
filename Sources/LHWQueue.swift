//
//  LHWQueue.swift
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

open class LHWQueue: NSObject {
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
    
    public init(name: String) {
        self.name = name
        self.queue = DispatchQueue(label: name)
        self.queue?.setSpecific(key: queueSpecificKey, value: name)
    }
    
    deinit {
        queue = nil
    }
    
    // MARK: -
    open func mainQueue() -> LHWQueue {
        return ._mainQueue
    }
    
    open func nativeQueue() -> DispatchQueue? {
        return queue
    }
    
    open func isCurrentQueue() -> Bool {
        if queue == nil {
            return false
        }
        
        if _isMainQueue {
            return Thread.isMainThread
        } else {
            return DispatchQueue.getSpecific(key: queueSpecificKey) == name
        }
    }
    
    open func dispatchOnQueue(_ closure: @escaping () -> Void, synchronous: Bool) {
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
