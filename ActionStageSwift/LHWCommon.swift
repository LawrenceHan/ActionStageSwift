//
//  LHWCommon.swift
//  ActionStageSwift
//
//  Created by Hanguang on 2017/3/7.
//  Copyright © 2017年 Hanguang. All rights reserved.
//

import Darwin

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
