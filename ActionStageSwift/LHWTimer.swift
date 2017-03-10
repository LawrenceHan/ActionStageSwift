//
//  LHWTimer.swift
//  ActionStageSwift
//
//  Created by Hanguang on 2017/3/7.
//  Copyright © 2017年 Hanguang. All rights reserved.
//

import Foundation

final class LHWTImer: NSObject {
    // MARK: -
    var timeoutDate: TimeInterval = Double(INTMAX_MAX)
    
    private var timer: DispatchSourceTimer? = nil
    private var timeout: TimeInterval
    private var shouldRepeat: Bool = false
    private var completion: (() -> Void)?
    private var queue: DispatchQueue
    
    init(timeout: TimeInterval, shouldRepeat: Bool, completion: @escaping () -> Void, queue: DispatchQueue) {
        self.timeout = timeout
        self.shouldRepeat = shouldRepeat
        self.completion = completion
        self.queue = queue
    }
    
    deinit {
        if timer != nil {
            timer?.cancel()
            timer = nil
        }
    }
    
    // MARK: -
    func start() {
        timeoutDate = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970 + timeout
        
        timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: 0), queue: queue)
        if shouldRepeat {
            timer?.scheduleRepeating(deadline: .now() + timeout, interval: timeout)
        } else {
            timer?.scheduleOneshot(deadline: .now() + timeout)
        }
        
        timer?.setEventHandler(handler: {
            if let completion = self.completion {
                completion()
            }
            
            if !self.shouldRepeat {
                self.invalidate()
            }
        })
        
        timer?.resume()
    }
    
    func fireAndInvalidate() {
        if let completion = self.completion {
            completion()
        }
        self.invalidate()
    }
    
    func invalidate() {
        timeoutDate = 0
        if timer != nil {
            timer?.cancel()
            timer = nil
        }
    }
    
    func isScheduled() -> Bool {
        return timer != nil
    }
    
    func resetTimeout(timeout: TimeInterval) {
        invalidate()
        
        self.timeout = timeout
        start()
    }
    
    func remainingTime() -> TimeInterval {
        if timeoutDate < Double(FLT_EPSILON) {
            return DBL_MAX
        } else {
            return timeoutDate - (CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        }
    }
}
