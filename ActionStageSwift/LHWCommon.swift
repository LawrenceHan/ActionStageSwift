//
//  LHWCommon.swift
//  ActionStageSwift
//
//  Created by Hanguang on 2017/3/7.
//  Copyright © 2017年 Hanguang. All rights reserved.
//

import Foundation

// MRAK: -
func LHW_MUTEXLOCKER_INIT() -> pthread_mutex_t {
    var mutex: pthread_mutex_t = pthread_mutex_t()
    pthread_mutex_init(&mutex, nil)
    return mutex
}

func LHW_MUTEXLOCKER_LOCK(_ lock: inout pthread_mutex_t) {
    pthread_mutex_lock(&lock)
}

func LHW_MUTEXLOCKER_UNLOCK(_ lock: inout pthread_mutex_t) {
    pthread_mutex_unlock(&lock)
}

func LHW_SPINLOCKER_INIT() -> OSSpinLock {
    let spinLock = OS_SPINLOCK_INIT
    return spinLock
}

func LHW_SPINLOCKER_LOCK(_ lock: inout OSSpinLock) {
    OSSpinLockLock(&lock)
}

func LHW_SPINLOCKER_UNLOCK(_ lock: inout OSSpinLock) {
    OSSpinLockUnlock(&lock)
}

func LHWDispatchOnMainThread(_ closure: @escaping () -> Void) {
    if Thread.isMainThread {
        closure()
    } else {
        DispatchQueue.main.async {
            closure()
        }
    }
}

// MRAK: -
extension Array where Element: AnyObject {
    mutating func remove(object: Element) {
        if let index = index(where: { $0 === object }) {
            remove(at: index)
        }
    }
}
