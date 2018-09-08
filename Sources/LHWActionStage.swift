//
//  LHWActionStage.swift
//  ActionStageSwift
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
import CoreGraphics

public enum LHWActionStageStatus: Int {
    case success = 0
    case failed = -1
}

public enum LHWActorRequestFlags: Int {
    case ChangePriority = 1
}

public let GlobalFileManager = FileManager.default

public final class LHWActionStage {
    
    // MARK: -
    
    public static let `default` = LHWActionStage()
    
    // MARK: -
    
    fileprivate let stageQueueSpecific = "com.hanguang.app.ActionStageSwift.graphdispatchqueue"
    fileprivate let stageQueueSpecificKey = DispatchSpecificKey<String>()
    fileprivate let mainStageQueue: DispatchQueue
    fileprivate let globalStageQueue: DispatchQueue
    fileprivate let highPriorityStageQueue: DispatchQueue
    
    fileprivate var removeWatcherRequestsLock = LHW_SPINLOCKER_INIT()
    fileprivate var removeWatcherFromPathRequestsLock = LHW_SPINLOCKER_INIT()
    
    private var _removeWatcherFromPathRequests: [(LHWHandler, String)]
    private var _removeWatcherRequests: [LHWHandler]
    
    fileprivate var requestQueues: [String: [LHWActor]]
    fileprivate var activeRequests: [String: [String: Any]]
//    private var cancelRequestTimers: Dictionary<String, Any>
    fileprivate var livePathWatchers: [String: [LHWHandler]]
    
    private init() {
        requestQueues = [:]
        activeRequests = [:]
//        cancelRequestTimers = [:]
        livePathWatchers = [:]
        
        mainStageQueue = DispatchQueue(label: stageQueueSpecific)
        globalStageQueue = DispatchQueue(label: stageQueueSpecific+"-global", target: mainStageQueue)
        highPriorityStageQueue = DispatchQueue(label: stageQueueSpecific+"-high", target: mainStageQueue)
        
        mainStageQueue.setSpecific(key: stageQueueSpecificKey, value: stageQueueSpecific)
        globalStageQueue.setSpecific(key: stageQueueSpecificKey, value: stageQueueSpecific)
        highPriorityStageQueue.setSpecific(key: stageQueueSpecificKey, value: stageQueueSpecific)
        
        _removeWatcherFromPathRequests = []
        _removeWatcherRequests = []
    }
    
    // MARK: -
    
    public func globalStageDispatchQueue() -> DispatchQueue {
        return globalStageQueue
    }
    
    public func isCurrentQueueStageQueue() -> Bool {
        return DispatchQueue.getSpecific(key: stageQueueSpecificKey) != nil
    }
    
    public func dispatchOnStageQueue(_ closure: @escaping () -> Void) {
        var isGraphQueue = false
        isGraphQueue = DispatchQueue.getSpecific(key: stageQueueSpecificKey) != nil
        
        if isGraphQueue {
            #if DEBUG
                let startTime = CFAbsoluteTimeGetCurrent()
            #endif
            
            closure()
            
            #if DEBUG
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                if executionTime > 0.1 {
                    print("===== Actor dispatch took \(executionTime) s" )
                }
            #endif
        } else {
            #if DEBUG
                globalStageQueue.async {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    closure()
                    let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                    if executionTime > 0.1 {
                        print("===== Actor dispatch took \(executionTime) s" )
                    }
                }
            #else
                globalStageQueue.async {
                    closure()
                }
            #endif
        }
    }
    
    public func genericStringForParametrizedPath(_ path: String) -> String {
        if path.isEmpty {
            return ""
        }
        
        var newPath: String = String()
        var skipCharacters: Bool = false;
        var skippedCharacters: Bool = false;
        
        for c in path {
            if c == "(" {
                skipCharacters = true
                skippedCharacters = true
                newPath.append("@")
            } else if c == ")" {
                skipCharacters = false
            } else if !skipCharacters {
                newPath.append(c)
            }
        }
        
        if !skippedCharacters {
            return path
        }
        
        let genericPath = String(newPath)
        return genericPath
    }
    
    public func requestActor(
        path: String,
        options: [String: Any]? = nil,
        flags: Int = 0,
        watcher: LHWWatcher,
        completion: ((String, Any?, Any?) -> Void)? = nil) {
        _requestGeneric(
            joinOnly: false,
            inCurrentQueue: false,
            path: path, options:
            options,
            flags: flags,
            watcher: watcher,
            completion: completion
        )
    }
    
    public func changeActorPriority(path: String) {
        dispatchOnStageQueue { 
            guard let requestInfo = self.activeRequests[path] else {
                return
            }
            
            guard let actor = requestInfo["requestActor"] as? LHWActor else {
                return
            }
            
            guard let requestQueueName = actor.requestQueueName else {
                return
            }
            
            guard var reuqestQueue = self.requestQueues[requestQueueName] else {
                return
            }
            
            if reuqestQueue.count != 0 {
                guard let index = reuqestQueue.index(where: { $0 === actor }) else {
                    return
                }
                
                if index != 0 && index != 1 {
                    reuqestQueue.remove(at: index)
                    reuqestQueue.insert(actor, at: 1)
                    self.requestQueues[requestQueueName] = reuqestQueue
                    
                    print("===== changed actor \(path) priority (next in \(requestQueueName)")
                }
            }
        }
    }
    
    public func rejoinActionsWithGenericPathNow(genericPath: String, prefix: String, watcher: LHWWatcher) -> [String] {
        let activeRequests = self.activeRequests
        var rejoinPaths = [String]()
        
        for path in activeRequests.keys {
            if (path == genericPath) ||
                (genericStringForParametrizedPath(path) == genericPath &&
                    (prefix.isEmpty || path.hasPrefix(prefix))) {
                rejoinPaths.append(path)
            }
        }
        
        for path in rejoinPaths {
            _requestGeneric(joinOnly: true, inCurrentQueue: true, path: path, options: [:], flags: 0, watcher: watcher, completion: nil)
        }
        
        return rejoinPaths
    }
    
    public func isExecutingActorsWithGenericPath(genericPath: String) -> Bool {
        if !isCurrentQueueStageQueue() {
            print("===== warning: should be called from stage queue")
            return false
        }
        
        var result: Bool = false
        
        for (_, requestInfo) in activeRequests {
            guard let requestActor = requestInfo["requestActor"] as? LHWActor else {
                continue
            }
            
            if genericPath == type(of: requestActor).genericPath() {
                result = true
                break
            }
        }
        
        return result
    }
    
    public func isExecutingActorsWithPathPrefix(pathPrefix: String) -> Bool {
        if !isCurrentQueueStageQueue() {
            print("===== warning: should be called from stage queue")
            return false
        }
        
        var result = false
        for (path, _) in activeRequests {
            if path.hasPrefix(pathPrefix) {
                result = true
                break
            }
        }
        
        return result
    }
    
    public func executingActorsWithPathPrefix(_ pathPrefix: String) -> [LHWActor]? {
        if !isCurrentQueueStageQueue() {
            print("===== warning: should be called from stage queue")
            return nil
        }
        
        var array = [LHWActor]()
        for (path, requestInfo) in activeRequests {
            if path.hasPrefix(pathPrefix) {
                guard let actor = requestInfo["requestActor"] as? LHWActor else {
                    continue
                }
                
                array.append(actor)
            }
        }
        
        return array
    }
    
    public func executingActorWithPath(_ path: String) -> LHWActor? {
        if !isCurrentQueueStageQueue() {
            print("===== warning: should be called from stage queue")
            return nil
        }
        
        guard let requestInfo = activeRequests[path] else {
            return nil
        }
        
        guard let requestActor = requestInfo["requestActor"] as? LHWActor else {
            return nil
        }
        
        return requestActor
    }
    
    public func watchForPath(_ path:String, watcher: LHWWatcher) {
        guard let actionHandler = watcher.actionHandler else {
            print("===== warning: actionHandler is nil")
            return
        }
        
        dispatchOnStageQueue {
            var pathWatchers = self.livePathWatchers[path]
            if pathWatchers == nil {
                pathWatchers = [LHWHandler]()
                self.livePathWatchers[path] = pathWatchers
            }
            
            if !self.livePathWatchers[path]!.contains(where: { $0 === actionHandler }) {
                self.livePathWatchers[path]!.append(actionHandler)
            }
        }
    }
    
    public func watchForPaths(_ paths: [String], watcher: LHWWatcher) {
        guard let actionHandler = watcher.actionHandler else {
            print("===== warning: actionHandler is nil")
            return
        }
        
        dispatchOnStageQueue { 
            for path in paths {
                var pathWatchers = self.livePathWatchers[path]
                if pathWatchers == nil {
                    pathWatchers = [LHWHandler]()
                    self.livePathWatchers[path] = pathWatchers
                }
                
                if !self.livePathWatchers[path]!.contains(where: { $0 === actionHandler }) {
                    self.livePathWatchers[path]!.append(actionHandler)
                }
            }
        }
    }
    
    public func watchForGenericPath(_ path: String, watcher: LHWWatcher) {
        guard let actionHandler = watcher.actionHandler else {
            print("===== warning: actionHandler is nil")
            return
        }
        
        dispatchOnStageQueue { 
            let genericPath = self.genericStringForParametrizedPath(path)
            var pathWatchers = self.livePathWatchers[genericPath]
            if pathWatchers == nil {
                pathWatchers = [LHWHandler]()
                self.livePathWatchers[genericPath] = pathWatchers
            }
            
            self.livePathWatchers[genericPath]!.append(actionHandler)
        }
    }
    
    public func removeWatcherByHandler(_ actionHandler: LHWHandler) {
        var alreadyExecuting = false
        LHW_SPINLOCKER_LOCK(&removeWatcherRequestsLock)
        if !_removeWatcherRequests.isEmpty {
            alreadyExecuting = true
        }
        _removeWatcherRequests.append(actionHandler)
        LHW_SPINLOCKER_UNLOCK(&removeWatcherRequestsLock)
        
        if alreadyExecuting && !isCurrentQueueStageQueue() {
            return
        }
        
        dispatchOnHighPriorityQueue {
            LHW_SPINLOCKER_LOCK(&self.removeWatcherRequestsLock)
            let removeWatchers = self._removeWatcherRequests
            self._removeWatcherRequests.removeAll()
            LHW_SPINLOCKER_UNLOCK(&self.removeWatcherRequestsLock)
            
            for handler in removeWatchers {
                // Cancel activeRequests
                for path in self.activeRequests.keys {
                    guard var requestInfo = self.activeRequests[path] else {
                        continue
                    }
                    
                    guard var watchers = requestInfo["watchers"] as? [LHWHandler] else {
                        continue
                    }
                    
                    watchers.remove(object: handler)
                    
                    requestInfo["watchers"] = watchers
                    self.activeRequests[path] = requestInfo
                    
                    if watchers.count == 0 {
                        self.scheduleCancelRequest(path: path)
                    }
                }
                
                // Remove livePathWatchers
                var keysTobeRemoved = [String]()
                for key in self.livePathWatchers.keys {
                    guard var watchers = self.livePathWatchers[key] else {
                        continue
                    }
                    
                    watchers.remove(object: handler)
                    
                    if watchers.count == 0 {
                        keysTobeRemoved.append(key)
                    }
                    
                    self.livePathWatchers[key] = watchers
                }
                
                if keysTobeRemoved.count > 0 {
                    for key in keysTobeRemoved {
                        self.livePathWatchers.removeValue(forKey: key)
                    }
                }
            }
        }
    }
    
    public func removeWatcher(_ watcher: LHWWatcher) {
        guard let handler = watcher.actionHandler else {
            print("===== warning: actionHandler is nil in removeWatcher")
            return
        }
        removeWatcherByHandler(handler)
    }
    
    public func removeWatcherByHandler(_ actionHandler: LHWHandler, fromPath: String) {
        var alreadyExecuting = false
        LHW_SPINLOCKER_LOCK(&removeWatcherFromPathRequestsLock)
        if !_removeWatcherFromPathRequests.isEmpty {
            alreadyExecuting = true
        }
        _removeWatcherFromPathRequests.append((actionHandler, fromPath))
        LHW_SPINLOCKER_UNLOCK(&removeWatcherFromPathRequestsLock)
        
        if alreadyExecuting && !isCurrentQueueStageQueue() {
            return
        }
        
        dispatchOnHighPriorityQueue {
            LHW_SPINLOCKER_LOCK(&self.removeWatcherFromPathRequestsLock)
            let removeWatchersFromPath = self._removeWatcherFromPathRequests
            self._removeWatcherFromPathRequests.removeAll()
            LHW_SPINLOCKER_UNLOCK(&self.removeWatcherFromPathRequestsLock)
            
            if removeWatchersFromPath.count > 1 {
                print("===== cancelled \(removeWatchersFromPath.count) requests at once")
            }
            
            for (handler, path) in removeWatchersFromPath {
                if path.isEmpty {
                    continue
                }
                
                // Cancel activeRequests
                for path in self.activeRequests.keys {
                    guard var requestInfo = self.activeRequests[path] else {
                        continue
                    }
                    
                    guard var watchers = requestInfo["watchers"] as? [LHWHandler] else {
                        continue
                    }
                    
                    if watchers.contains(where: { $0 === actionHandler }) {
                        watchers.remove(object: handler)
                    }
                    
                    requestInfo["watchers"] = watchers
                    self.activeRequests[path] = requestInfo
                    
                    if watchers.count == 0 {
                        self.scheduleCancelRequest(path: path)
                    }
                }
                
                // Remove livePathWatchers
                if var watchers = self.livePathWatchers[path] {
                    if watchers.contains(where: { $0 === actionHandler }) {
                        watchers.remove(object: handler)
                    }
                    
                    if watchers.count == 0 {
                        self.livePathWatchers.removeValue(forKey: path)
                    } else {
                        self.livePathWatchers[path] = watchers
                    }
                }
            }
        }
    }
    
    public func removeWatcher(_ watcher: LHWWatcher, fromPath: String) {
        guard let handler = watcher.actionHandler else {
            print("===== warning: actionHandler is nil")
            return
        }
        removeWatcherByHandler(handler, fromPath: fromPath)
    }
    
    public func removeAllWatchersFromPath(_ path: String) {
        dispatchOnHighPriorityQueue {
            guard var requestInfo = self.activeRequests[path] else {
                return
            }
            
            guard var watchers = requestInfo["watchers"] as? [LHWHandler] else {
                return
            }
            
            watchers.removeAll()
            requestInfo["watchers"] = watchers
            self.activeRequests[path] = requestInfo
            
            self.scheduleCancelRequest(path: path)
        }
    }
    
    public func requestActorStateNow(_ path: String) -> Bool {
        if let _ = activeRequests[path] {
            return true
        }
        return false
    }
    
    public func dispatchResource(path: String, resource: Any? = nil, arguments: Any? = nil) {
        dispatchOnStageQueue {
            let genericPath = self.genericStringForParametrizedPath(path)
            
            if let watchers = self.livePathWatchers[path] {
                for handler in watchers {
                    var watcher = handler.delegate
                    watcher?.actionStageResourceDispatched(path: path, resource: resource, arguments: arguments)
                    if handler.releaseOnMainThread {
                        DispatchQueue.main.async {
                            _ = watcher.self
                        }
                    }
                    watcher = nil
                }
            }
            
            if genericPath != path {
                if let watchers = self.livePathWatchers[genericPath] {
                    for handler in watchers {
                        var watcher = handler.delegate
                        watcher?.actionStageResourceDispatched(path: path, resource: resource, arguments: arguments)
                        if handler.releaseOnMainThread {
                            DispatchQueue.main.async {
                                _ = watcher.self
                            }
                        }
                        watcher = nil
                    }
                }
            }
        }
    }
    
    public func dispatchMessageToWatchers(path: String, messageType: String? = nil, message: Any? = nil) {
        dispatchOnStageQueue {
            let genericPath = self.genericStringForParametrizedPath(path)
            
            if let watchers = self.livePathWatchers[path] {
                for handler in watchers {
                    handler.receiveActorMessage(path: path, messageType: messageType, message: message)
                }
            }
            
            if genericPath != path {
                if let watchers = self.livePathWatchers[genericPath] {
                    for handler in watchers {
                        handler.receiveActorMessage(path: path, messageType: messageType, message: message)
                    }
                }
            }
        }
    }
    
    public func actionCompleted(_ action: String, result: Any? = nil) {
        dispatchOnStageQueue {
            guard let requestInfo = self.activeRequests[action] else {
                return
            }
            
            guard var actionWatchers = requestInfo["watchers"] as? [LHWHandler] else {
                return
            }
            
            self.activeRequests.removeValue(forKey: action)
            
            for handler in actionWatchers {
                var watcher = handler.delegate
                watcher?.actorCompleted(status: .success, path: action, result: result)
                
                if handler.releaseOnMainThread {
                    DispatchQueue.main.async {
                        _ = watcher.self
                    }
                }
                watcher = nil
            }
            
            actionWatchers.removeAll()
            
            guard let requestActor = requestInfo["requestActor"] as? LHWActor else {
                print("===== warning: requestActor is nil")
                return
            }
            
            guard let requestQueueName = requestActor.requestQueueName else {
                return
            }
            
            self.removeRequestFromQueueAndProceedIfFirst(
                name: requestQueueName, fromRequestActor: requestActor
            )
        }
    }
    
    public func actorMessageToWatchers(path: String, messageType: String? = nil, message: Any? = nil) {
        dispatchOnStageQueue {
            guard let requestInfo = self.activeRequests[path] else {
                return
            }
            
            guard let actionWatchers = requestInfo["watchers"] as? [LHWHandler] else {
                return
            }
            
            for handler in actionWatchers {
                handler.receiveActorMessage(path: path, messageType: messageType, message: message)
            }
        }
    }
    
    public func actionFailed(_ action: String, reason: LHWActionStageStatus) {
        dispatchOnStageQueue {
            guard let requestInfo = self.activeRequests[action] else {
                return
            }
            
            guard var actionWatchers = requestInfo["watchers"] as? [LHWHandler] else {
                return
            }
            
            self.activeRequests.removeValue(forKey: action)
            
            for handler in actionWatchers {
                var watcher = handler.delegate
                watcher?.actorCompleted(status: reason, path: action, result: nil)
                
                if handler.releaseOnMainThread {
                    DispatchQueue.main.async {
                        _ = watcher.self
                    }
                }
                watcher = nil
            }
            actionWatchers.removeAll()
            
            guard let requestActor = requestInfo["requestActor"] as? LHWActor else {
                print("===== warning: requestActor is nil")
                return
            }
            
            guard let requestQueueName = requestActor.requestQueueName else {
                return
            }
            
            self.removeRequestFromQueueAndProceedIfFirst(
                name: requestQueueName, fromRequestActor: requestActor
            )
        }
    }
    
    public func nodeRetrieved(path: String, node: LHWGraphNode<Any>) {
        actionCompleted(path, result: node)
    }
    
    public func nodeRetrieveProgress(path: String, progress: CGFloat) {
        dispatchOnStageQueue {
            guard let requestInfo = self.activeRequests[path] else {
                return
            }
            
            guard let watchers = requestInfo["watchers"] as? [LHWHandler] else {
                return
            }
            
            for handler in watchers {
                var watcher = handler.delegate
                watcher?.actorReportedProgress(path: path, progress: progress)
                
                if handler.releaseOnMainThread {
                    DispatchQueue.main.async {
                        _ = watcher.self
                    }
                }
                watcher = nil
            }
        }
    }
    
    public func nodeRetrieveFailed(path: String) {
        actionFailed(path, reason: .failed)
    }
    
    // MARK: -
    
    fileprivate func dispatchOnHighPriorityQueue(_ closure: @escaping () -> Void) {
        if isCurrentQueueStageQueue() {
            closure()
        } else {
            highPriorityStageQueue.async {
                closure()
            }
        }
    }
    
    private func _requestGeneric(
        joinOnly: Bool,
        inCurrentQueue: Bool,
        path: String,
        options: [String: Any]?,
        flags: Int,
        watcher: LHWWatcher,
        completion: ((String, Any?, Any?) -> Void)?) {
        guard let actionHandler = watcher.actionHandler else {
            print("===== warning: actionHandler is nil")
            return
        }
        
        let requestClosure = {
            if !actionHandler.hasDelegate() {
                print("===== error: actionHandler.delegate is nil")
                return
            }
            
            let genericPath = self.genericStringForParametrizedPath(path)
            var requestInfo = self.activeRequests[path]
            
            if joinOnly && requestInfo == nil { return }
            
            if requestInfo == nil {
                guard let requestActor = LHWActor.requestActorForGenericPath(genericPath, path: path) else {
                    print("===== error: request actor not found for \"\(path)\"")
                    return
                }
                
                let watchers = [actionHandler]
                
                requestInfo = [
                    "requestActor": requestActor,
                    "watchers": watchers
                ]
                
                self.activeRequests[path] = requestInfo
                
                requestActor.prepare(options: options)
                
                var executeNow = true
                if let requestQueueName = requestActor.requestQueueName {
                    var requestQueue = self.requestQueues[requestQueueName]
                    if requestQueue == nil {
                        requestQueue = [requestActor]
                    } else {
                        requestQueue!.append(requestActor)
                        if requestQueue!.count > 1 {
                            executeNow = false
                            print("===== adding request \(requestActor) to request queue \"\(requestQueueName)\"")
                            
                            if flags == LHWActorRequestFlags.ChangePriority.rawValue {
                                if requestQueue!.count > 2 {
                                    requestQueue!.removeLast()
                                    requestQueue!.insert(requestActor, at: 1)
                                    
                                    print("===== inserted actor with high priority (next in queue)")
                                }
                            }
                        }
                    }
                    self.requestQueues[requestQueueName] = requestQueue
                }
                
                if executeNow {
                    requestActor.execute(options: options, completion: completion)
                } else {
                    requestActor.storedOptions = options
                }
            } else {
                if var watchers = requestInfo!["watchers"] as? [LHWHandler] {
                    if !(watchers.contains(where: { $0 === actionHandler })) {
                        print("===== joining watcher to the wathcers of \"\(path)\"")
                        watchers.append(actionHandler)
                        
                        requestInfo!["watchers"] = watchers
                        self.activeRequests[path] = requestInfo!
                    } else {
                        print("===== continue to watch for actor \"\(path)\"")
                    }
                }
                
                guard let actor = requestInfo?["requestActor"] as? LHWActor else {
                    return
                }
                
                if actor.requestQueueName == nil {
                    actor.watcherJoined(watcherHandler: actionHandler, options: options, waitingInActorQueue: false)
                } else {
                    let reuqestQueue = self.requestQueues[actor.requestQueueName!]
                    if  reuqestQueue == nil || reuqestQueue?.count == 0 {
                        actor.watcherJoined(watcherHandler: actionHandler, options: options, waitingInActorQueue: false)
                    } else {
                        let wait = reuqestQueue?[0] !== actor
                        actor.watcherJoined(watcherHandler: actionHandler, options: options, waitingInActorQueue: wait)
                        
                        if flags == LHWActorRequestFlags.ChangePriority.rawValue {
                            self.changeActorPriority(path: path)
                        }
                    }
                }
            }
        }
        
        if inCurrentQueue {
            requestClosure()
        } else {
            dispatchOnStageQueue {
                requestClosure()
            }
        }
    }
    
    fileprivate func removeRequestFromQueueAndProceedIfFirst(name: String, fromRequestActor requestActor: LHWActor) {
        var requestQueueName = requestActor.requestQueueName
        if requestQueueName == nil {
            requestQueueName = name
        }
        
        guard var requestQueue = requestQueues[requestQueueName!] else {
            print("===== warning: requestQueue is nil")
            return
        }
        
        if requestQueue.count == 0 {
            print("===== warning: request queue \"\(requestActor.requestQueueName ?? "") is empty.\"")
        } else {
            if requestQueue[0] === requestActor {
                requestQueue.remove(at: 0)
                
                if requestQueue.count != 0 {
                    let nextRequest = requestQueue[0]
                    let nextRequestOptions = nextRequest.storedOptions
                    nextRequest.storedOptions = nil
                    
                    if !nextRequest.cancelled {
                        nextRequest.execute(options: nextRequestOptions)
                    }
                } else {
                    requestQueues.removeValue(forKey: requestActor.requestQueueName!)
                }
            } else {
                if let index = requestQueue.index(where: { $0 === requestActor }) {
                    requestQueue.remove(at: index)
                } else {
                    print("===== warning: request queue \"\(requestActor.requestQueueName ?? "")\" doesn't contain request to \(requestActor.path)")
                }
            }
        }
        
        requestQueues[requestQueueName!] = requestQueue
    }
    
    fileprivate func scheduleCancelRequest(path: String) {
        guard var requestInfo = activeRequests[path] else {
            print("===== warning: cannot cancel request to \"\(path)\": no active request found")
            return
        }
        
        guard let requestActor = requestInfo["requestActor"] as? LHWActor else {
            return
        }
        //            let cancelTimeout = Double(requestActor.cancelTimeout)
        
        activeRequests.removeValue(forKey: path)
        
        requestActor.cancel()
        print("===== cancelled request to \"\(path)\"")
        
        guard let requestQueueName = requestActor.requestQueueName else {
            return
        }
        
        removeRequestFromQueueAndProceedIfFirst(name: requestQueueName, fromRequestActor: requestActor)
        
        /*
                    if cancelTimeout <= DBL_EPSILON {
                        activeRequests.removeValue(forKey: path)
        
                        requestActor.cancel()
                        print("Cancelled request to \"\(path)\"")
                        if let requestQueueName = requestActor.requestQueueName {
                            removeRequestFromQueueAndProceedIfFirst(name: requestQueueName, fromrequestActor: requestActor)
                        }
                    } else {
                        print("Will cancel request to \"\(path)\" in \(cancelTimeout) s")
                        let cancelDict = [
                            "path": path,
                            "type": 0
                        ] as [String : Any]
        
                        performCancelRequest(cancelDict: cancelDict)
                    }
         */
    }
    
    /*
    func performCancelRequest(cancelDict: [String: Any]) {
        let path = cancelDict["path"] as! String
        
        dispatchOnStageQueue {
            let requestInfo =
        }
    }
 */
}

/// Debug
extension LHWActionStage {
    func dumpActorState() {
        dispatchOnStageQueue {
            print("===== Actor State =====")
            
            print("\(self.livePathWatchers.count) live node watchers")
            for (path, watchers) in self.livePathWatchers {
                print("    \(path)")
                for handler in watchers {
                    if let watcher = handler.delegate {
                        print("        \(watcher)")
                    }
                }
            }
            
            print("\(self.activeRequests.count) requests")
            for (path, _) in self.activeRequests {
                print("    \(path)")
            }
            
            print("=======================")
        }
    }
}

// MARK: - Default ActionStage

public let Actor = LHWActionStage.default
