//
//  LHWCommon.swift
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

// MRAK: - Threading
public func LHW_MUTEXLOCKER_INIT() -> pthread_mutex_t {
    var mutex: pthread_mutex_t = pthread_mutex_t()
    pthread_mutex_init(&mutex, nil)
    return mutex
}

public func LHW_MUTEXLOCKER_LOCK(_ lock: inout pthread_mutex_t) {
    pthread_mutex_lock(&lock)
}

public func LHW_MUTEXLOCKER_UNLOCK(_ lock: inout pthread_mutex_t) {
    pthread_mutex_unlock(&lock)
}

public func LHW_SPINLOCKER_INIT() -> OSSpinLock {
    let spinLock = OS_SPINLOCK_INIT
    return spinLock
}

public func LHW_SPINLOCKER_LOCK(_ lock: inout OSSpinLock) {
    OSSpinLockLock(&lock)
}

public func LHW_SPINLOCKER_UNLOCK(_ lock: inout OSSpinLock) {
    OSSpinLockUnlock(&lock)
}

@inline(__always) public func LHWDispatchOnMainThread(_ closure: @escaping () -> Void) {
    if Thread.isMainThread {
        closure()
    } else {
        DispatchQueue.main.async {
            closure()
        }
    }
}

@inline(__always) public func LHWDispatchAfter(_ delay: Double, queue: DispatchQueue, closure: @escaping () -> Void) {
    queue.asyncAfter(deadline: .now()+delay, execute: closure)
}

// MRAK: - Extensions
extension Array where Element: AnyObject {
    public mutating func remove(object: Element) {
        if let index = index(where: { $0 === object }) {
            remove(at: index)
        }
    }
}

// MARK: - Commons
public let LHWDocumentsPath: String = {
    var path: String? = nil
    let groupName = "group."+Bundle.main.bundleIdentifier!
    if let groupURL = LHWActionStage.GlobalFileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName) {
        let documentsPathURL = groupURL.appendingPathComponent("Documents")
        do {
            try LHWActionStage.GlobalFileManager.createDirectory(at: documentsPathURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
        }
        path = documentsPathURL.path
    } else {
        path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    }
    
    return path!
}()

public let LHWCachesPath: String = {
    var path: String? = nil
    let groupName = "group."+Bundle.main.bundleIdentifier!
    if let groupURL = LHWActionStage.GlobalFileManager.containerURL(forSecurityApplicationGroupIdentifier: groupName) {
        let documentsPathURL = groupURL.appendingPathComponent("Caches")
        do {
            try LHWActionStage.GlobalFileManager.createDirectory(at: documentsPathURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
        }
        path = documentsPathURL.path
    } else {
        path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    }
    
    return path!
}()













