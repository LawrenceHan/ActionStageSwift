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

public enum LHWActionStageStatus: Int {
    case Success = 0
    case Failed = -1
}

public enum LHWActorRequestFlags: Int {
    case ChangePriority = 1
}

public let GlobalFileManager = FileManager.default

open class LHWActionStage {
    // MARK: -
    open static let `default` = LHWActionStage()
    
    // MARK: -
    private let graphQueueSpecific = "com.hanguang.app.ActionStageSwift.graphdispatchqueue"
    private let graphQueueSpecificKey = DispatchSpecificKey<String>()
    private let mainGraphQueue: DispatchQueue
    private let globalGraphQueue: DispatchQueue
    private let highPriorityGraphQueue: DispatchQueue
    
    private var removeWatcherRequestsLock = LHW_SPINLOCKER_INIT()
    private var removeWatcherFromPathRequestsLock = LHW_SPINLOCKER_INIT()
    
    private var _removeWatcherFromPathRequests: [(LHWHandler, String)]
    private var _removeWatcherRequests: [LHWHandler]
    
    private var requestQueues: [String: [LHWActor]]
    private var activeRequests: [String: Any]
//    private var cancelRequestTimers: Dictionary<String, Any>
    private var liveNodeWatchers: [String: [LHWHandler]]
    private var actorMessagesWatchers: [String: [LHWHandler]]
    
    private init() {
        requestQueues = [String: Array<LHWActor>]()
        activeRequests = [String: Any]()
//        cancelRequestTimers = [String: Any]()
        liveNodeWatchers = [String: [LHWHandler]]()
        actorMessagesWatchers = [String: [LHWHandler]]()
        
        mainGraphQueue = DispatchQueue(label: graphQueueSpecific)
        globalGraphQueue = DispatchQueue(label: graphQueueSpecific+"-global", target: mainGraphQueue)
        highPriorityGraphQueue = DispatchQueue(label: graphQueueSpecific+"-high", target: mainGraphQueue)
        
        mainGraphQueue.setSpecific(key: graphQueueSpecificKey, value: graphQueueSpecific)
        globalGraphQueue.setSpecific(key: graphQueueSpecificKey, value: graphQueueSpecific)
        highPriorityGraphQueue.setSpecific(key: graphQueueSpecificKey, value: graphQueueSpecific)
        
        _removeWatcherFromPathRequests = [(LHWHandler, String)]()
        _removeWatcherRequests = [LHWHandler]()
    }
    
    // MARK: -
    open func globalStageDispatchQueue() -> DispatchQueue {
        return globalGraphQueue
    }
    
    open func isCurrentQueueStageQueue() -> Bool {
        return DispatchQueue.getSpecific(key: graphQueueSpecificKey) != nil
    }
    
    open func dispatchOnStageQueue(_ closure: @escaping () -> Void) {
        var isGraphQueue = false
        isGraphQueue = DispatchQueue.getSpecific(key: graphQueueSpecificKey) != nil
        
        if isGraphQueue {
            #if DEBUG
                let startTime = CFAbsoluteTimeGetCurrent()
            #endif
            
            closure()
            
            #if DEBUG
                let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                if executionTime > 0.1 {
                    Logger.debug("===== ActionStage Dispatch took \(executionTime) s" )
                }
            #endif
        } else {
            #if DEBUG
                globalGraphQueue.async {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    closure()
                    let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                    if executionTime > 0.1 {
                        Logger.debug("===== ActionStage Dispatch took \(executionTime) s" )
                    }
                }
            #else
                globalGraphQueue.async {
                    closure()
                }
            #endif
        }
    }
    
    open func genericStringForParametrizedPath(_ path: String) -> String {
        if path.characters.count == 0 {
            return ""
        }
        
        var newPath: String.CharacterView = String.CharacterView()
        var skipCharacters: Bool = false;
        var skippedCharacters: Bool = false;
        
        for c in path.characters {
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
    
    open func requestActor(path: String, options: [String: Any]?, flags: Int = 0, watcher: LHWWatcher) {
        _requestGeneric(joinOnly: false, inCurrentQueue: false, path: path, options: options, flags: flags, watcher: watcher)
    }
    
    open func changeActorPriority(path: String) {
        dispatchOnStageQueue {
            guard let requestInfo = self.activeRequests[path] as? [String: Any] else {
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
                    
                    Logger.debug("Changed actor \(path) priority (next in \(requestQueueName)")
                }
            }
        }
    }
    
    open func rejoinActionsWithGenericPathNow(genericPath: String, prefix: String, watcher: LHWWatcher) -> [String] {
        let activeRequests = self.activeRequests
        var rejoinPaths = [String]()
        
        for path in activeRequests.keys {
            if (path == genericPath) || (genericStringForParametrizedPath(path) == genericPath && (prefix.characters.count == 0 || path.hasPrefix(prefix))) {
                rejoinPaths.append(path)
            }
        }
        
        for path in rejoinPaths {
            _requestGeneric(joinOnly: true, inCurrentQueue: true, path: path, options: [:], flags: 0, watcher: watcher)
        }
        
        return rejoinPaths
    }
    
    open func isExecutingActorsWithGenericPath(genericPath: String) -> Bool {
        if !isCurrentQueueStageQueue() {
            Logger.debug("\(#function) should be called from graph queue")
            return false
        }
        
        var result: Bool = false
        
        for (_, actionInfo) in activeRequests {
            guard let actionInfo = actionInfo as? [String: Any] else {
                continue
            }
            
            guard let requestActor = actionInfo["requestActor"] as? LHWActor else {
                continue
            }
            
            if genericPath == type(of: requestActor).genericPath() {
                result = true
                break
            }
        }
        
        return result
    }
    
    open func isExecutingActorsWithPathPrefix(pathPrefix: String) -> Bool {
        if !isCurrentQueueStageQueue() {
            Logger.debug("\(#function) should be called from graph queue")
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
    
    open func executingActorsWithPathPrefix(_ pathPrefix: String) -> Array<LHWActor>? {
        if !isCurrentQueueStageQueue() {
            Logger.debug("\(#function) should be called from graph queue")
            return nil
        }
        
        var array = [LHWActor]()
        for (path, actionInfo) in activeRequests {
            if path.hasPrefix(pathPrefix) {
                guard let actionInfo = actionInfo as? [String: Any] else {
                    continue
                }
                
                guard let actor = actionInfo["requestActor"] as? LHWActor else {
                    continue
                }
                
                array.append(actor)
            }
        }
        
        return array
    }
    
    open func executingActorWithPath(_ path: String) -> LHWActor? {
        if !isCurrentQueueStageQueue() {
            Logger.debug("\(#function) should be called from graph queue")
            return nil
        }
        
        guard let requestInfo = activeRequests[path] as? [String: Any] else {
            return nil
        }
        
        guard let requestActor = requestInfo["requestActor"] as? LHWActor else {
            return nil
        }
        
        return requestActor
    }
    
    open func watchForPath(_ path:String, watcher: LHWWatcher) {
        guard let actionHandler = watcher.actionHandler else {
            Logger.debug("===== Warning: actionHandler is nil in \(#function):\(#line)")
            return
        }
        
        dispatchOnStageQueue {
            var pathWatchers = self.liveNodeWatchers[path]
            if pathWatchers == nil {
                pathWatchers = [LHWHandler]()
                self.liveNodeWatchers[path] = pathWatchers
            }
            
            if !self.liveNodeWatchers[path]!.contains(where: { $0 === actionHandler }) {
                self.liveNodeWatchers[path]!.append(actionHandler)
            }
        }
    }
    
    open func watchForPaths(_ paths: Array<String>, watcher: LHWWatcher) {
        guard let actionHandler = watcher.actionHandler else {
            Logger.debug("===== Warning: actionHandler is nil in \(#function):\(#line)")
            return
        }
        
        dispatchOnStageQueue {
            for path in paths {
                var pathWatchers = self.liveNodeWatchers[path]
                if pathWatchers == nil {
                    pathWatchers = [LHWHandler]()
                    self.liveNodeWatchers[path] = pathWatchers
                }
                
                if !self.liveNodeWatchers[path]!.contains(where: { $0 === actionHandler }) {
                    self.liveNodeWatchers[path]!.append(actionHandler)
                }
            }
        }
    }
    
    open func watchForGenericPath(_ path: String, watcher: LHWWatcher) {
        guard let actionHandler = watcher.actionHandler else {
            Logger.debug("===== Warning: actionHandler is nil in \(#function):\(#line)")
            return
        }
        
        dispatchOnStageQueue {
            let genericPath = self.genericStringForParametrizedPath(path)
            var pathWatchers = self.liveNodeWatchers[genericPath]
            if pathWatchers == nil {
                pathWatchers = [LHWHandler]()
                self.liveNodeWatchers[genericPath] = pathWatchers
            }
            
            self.liveNodeWatchers[genericPath]!.append(actionHandler)
        }
    }
    
    open func watchForMessagesToWatchersAtGenericPath(_ genericPath: String, watcher: LHWWatcher) {
        guard let actionHandler = watcher.actionHandler else {
            Logger.debug("===== Warning: actionHandler is nil in \(#function):\(#line)")
            return
        }
        
        dispatchOnStageQueue {
            var pathWatchers = self.actorMessagesWatchers[genericPath]
            if pathWatchers == nil {
                pathWatchers = [LHWHandler]()
                self.actorMessagesWatchers[genericPath] = pathWatchers
            }
            
            self.actorMessagesWatchers[genericPath]!.append(actionHandler)
        }
    }
    
    open func removeWatcherByHandler(_ actionHandler: LHWHandler) {
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
                    guard var requestInfo = self.activeRequests[path] as? [String: Any] else {
                        continue
                    }
                    
                    guard var watchers = requestInfo["watchers"] as? [LHWHandler] else {
                        continue
                    }
                    
                    watchers.remove(object: handler)
                    
                    if watchers.count == 0 {
                        self.scheduleCancelRequest(path: path)
                    }
                    
                    requestInfo["watchers"] = watchers
                    self.activeRequests[path] = requestInfo
                }
                
                // Remove liveNodeWatchers
                var keysTobeRemoved = [String]()
                for key in self.liveNodeWatchers.keys {
                    guard var watchers = self.liveNodeWatchers[key] else {
                        continue
                    }
                    
                    watchers.remove(object: handler)
                    
                    if watchers.count == 0 {
                        keysTobeRemoved.append(key)
                    }
                    
                     self.liveNodeWatchers[key] = watchers
                }
                
                if keysTobeRemoved.count > 0 {
                    for key in keysTobeRemoved {
                        self.liveNodeWatchers.removeValue(forKey: key)
                    }
                }
                
                // Remove actorMessagesWatchers
                var keysTobeRemoved1 = [String]()
                for key in self.actorMessagesWatchers.keys {
                    guard var watchers = self.actorMessagesWatchers[key] else {
                        continue
                    }
                    
                    watchers.remove(object: handler)
                    
                    if watchers.count == 0 {
                        keysTobeRemoved1.append(key)
                    }
                    
                    self.actorMessagesWatchers[key] = watchers
                }
                
                if keysTobeRemoved1.count > 0 {
                    for key in keysTobeRemoved1 {
                        self.actorMessagesWatchers.removeValue(forKey: key)
                    }
                }
            }
        }
    }
    
    open func removeWatcher(_ watcher: LHWWatcher) {
        if let handler = watcher.actionHandler {
            removeWatcherByHandler(handler)
        }
    }
    
    open func removeWatcherByHandler(_ actionHandler: LHWHandler, fromPath: String) {
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
                Logger.debug("Cancelled \(removeWatchersFromPath.count) requests at once")
            }
            
            for (handler, path) in removeWatchersFromPath {
                if path.characters.count == 0 {
                    continue
                }
                
                // Cancel activeRequests
                for path in self.activeRequests.keys {
                    guard var requestInfo = self.activeRequests[path] as? [String: Any] else {
                        continue
                    }
                    
                    guard var watchers = requestInfo["watchers"] as? [LHWHandler] else {
                        continue
                    }
                    
                    if watchers.contains(where: { $0 === actionHandler }) {
                        watchers.remove(object: handler)
                    }
                    
                    if watchers.count == 0 {
                        self.scheduleCancelRequest(path: path)
                    }

                    requestInfo["watchers"] = watchers
                    self.activeRequests[path] = requestInfo
                }
                
                // Remove liveNodeWatchers
                if var watchers = self.liveNodeWatchers[path] {
                    if watchers.contains(where: { $0 === actionHandler }) {
                        watchers.remove(object: handler)
                    }
                    
                    if watchers.count == 0 {
                        self.liveNodeWatchers.removeValue(forKey: path)
                    } else {
                        self.liveNodeWatchers[path] = watchers
                    }
                }
                
                // Remove actorMessagesWatchers
                if var watchers = self.actorMessagesWatchers[path] {
                    if watchers.contains(where: { $0 === actionHandler }) {
                        watchers.remove(object: handler)
                    }
                    
                    if watchers.count == 0 {
                        self.actorMessagesWatchers.removeValue(forKey: path)
                    } else {
                        self.actorMessagesWatchers[path] = watchers
                    }
                }
            }
        }
    }
    
    open func removeWatcher(_ watcher: LHWWatcher, fromPath: String) {
        if let handler = watcher.actionHandler {
            removeWatcherByHandler(handler, fromPath: fromPath)
        }
    }
    
    open func removeAllWatchersFromPath(_ path: String) {
        dispatchOnHighPriorityQueue {
            guard var requestInfo = self.activeRequests[path] as? [String: Any] else {
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
    
    open func requestActorStateNow(_ path: String) -> Bool {
        if let _ = activeRequests[path] {
            return true
        }
        return false
    }
    
    open func dispatchResource(path: String, resource: Any? = nil, arguments: Any? = nil) {
        dispatchOnStageQueue {
            let genericPath = self.genericStringForParametrizedPath(path)
            
            if let watchers = self.liveNodeWatchers[path] {
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
                if let watchers = self.liveNodeWatchers[genericPath] {
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
    
    open func actionCompleted(_ action: String, result: Any? = nil) {
        dispatchOnStageQueue {
            guard let requestInfo = self.activeRequests[action] as? [String: Any] else {
                return
            }
            
            guard var actionWatchers = requestInfo["watchers"] as? [LHWHandler] else {
                return
            }
            
            self.activeRequests.removeValue(forKey: action)
            
            for handler in actionWatchers {
                var watcher = handler.delegate
                watcher?.actorCompleted(status: .Success, path: action, result: result)
                
                if handler.releaseOnMainThread {
                    DispatchQueue.main.async {
                        _ = watcher.self
                    }
                }
                watcher = nil
            }
            
            actionWatchers.removeAll()
            
            guard let requestActor = requestInfo["requestActor"] as? LHWActor else {
                Logger.debug("===== Warning requestActor is nil")
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
    
    open func dispatchMessageToWatchers(path: String, messageType: String? = nil, message: Any? = nil) {
        dispatchOnStageQueue {
            guard let requestInfo = self.activeRequests[path] as? [String: Any] else {
                return
            }
            
            guard let actionWatchers = requestInfo["watchers"] as? [LHWHandler] else {
                return
            }
            
            for handler in actionWatchers {
                handler.receiveActorMessage(path: path, messageType: messageType, message: message)
            }
            
            if self.actorMessagesWatchers.count != 0 {
                let genericPath = self.genericStringForParametrizedPath(path)
                
                guard let messagesWatchers = self.actorMessagesWatchers[genericPath] else {
                    return
                }
                
                for handler in messagesWatchers {
                    handler.receiveActorMessage(path: path, messageType: messageType, message: message)
                }
            }
        }
    }
    
    open func actionFailed(_ action: String, reason: LHWActionStageStatus) {
        dispatchOnStageQueue {
            guard let requestInfo = self.activeRequests[action] as? [String: Any] else {
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
                Logger.debug("===== Warning requestActor is nil")
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
    
    open func nodeRetrieved(path: String, node: LHWGraphNode) {
        actionCompleted(path, result: node)
    }
    
    open func nodeRetrieveProgress(path: String, progress: Float) {
        dispatchOnStageQueue {
            guard let requestInfo = self.activeRequests[path] as? [String: Any] else {
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
    
    open func nodeRetrieveFailed(path: String) {
        actionFailed(path, reason: .Failed)
    }
    
    // MARK: -
    private func dispatchOnHighPriorityQueue(_ closure: @escaping () -> Void) {
        if isCurrentQueueStageQueue() {
            closure()
        } else {
            highPriorityGraphQueue.async {
                closure()
            }
        }
    }
    
    private func dumpGraphState() {
        dispatchOnStageQueue {
            Logger.debug("===== SGraph State =====")
            
            Logger.debug("\(self.liveNodeWatchers.count) live node watchers")
            for (path, watchers) in self.liveNodeWatchers {
                Logger.debug("    \(path)")
                for handler in watchers {
                    if let watcher = handler.delegate {
                        Logger.debug("        \(watcher)")
                    }
                }
            }
            
            Logger.debug("\(self.activeRequests.count) requests")
            for (path, _) in self.activeRequests {
                Logger.debug("        \(path)")
            }
            
            Logger.debug("========================");
        }
    }
    
    private func _requestGeneric(joinOnly: Bool, inCurrentQueue: Bool, path: String, options: [String: Any]?, flags: Int, watcher: LHWWatcher) {
        guard let actionHandler = watcher.actionHandler else {
            Logger.debug("===== Warning: actionHandler is nil in \(#function):\(#line)")
            return
        }
        
        let requestClosure = {
            if !actionHandler.hasDelegate() {
                Logger.debug("===== Error: \(#function):\(#line) actionHandler.delegate is nil")
                return
            }
            
            let genericPath = self.genericStringForParametrizedPath(path)
            var requestInfo = self.activeRequests[path] as? [String: Any]
            
            if joinOnly && requestInfo == nil { return }
            
            if requestInfo == nil {
                guard let requestActor = LHWActor.requestActorForGenericPath(genericPath, path: path) else {
                    Logger.debug("Error: request builder not found for \"\(path)\"")
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
                            Logger.debug("Adding request \(requestActor) to request queue \"\(requestQueueName)\"")
                            
                            if flags == LHWActorRequestFlags.ChangePriority.rawValue {
                                if requestQueue!.count > 2 {
                                    requestQueue!.removeLast()
                                    requestQueue!.insert(requestActor, at: 1)
                                    
                                    Logger.debug("Inserted actor with high priority (next in queue)")
                                }
                            }
                        }
                    }
                    self.requestQueues[requestQueueName] = requestQueue
                }
                
                if executeNow {
                    requestActor.execute(options: options)
                } else {
                    requestActor.storedOptions = options
                }
            } else {
                if var watchers = requestInfo!["watchers"] as? Array<LHWHandler> {
                    if !(watchers.contains(where: { $0 === actionHandler })) {
                        Logger.debug("Joining watcher to the wathcers of \"\(path)\"")
                        watchers.append(actionHandler)
                        
                        requestInfo!["watchers"] = watchers
                        self.activeRequests[path] = requestInfo!
                    } else {
                        Logger.debug("Continue to watch for actor \"\(path)\"")
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
    
    private func removeRequestFromQueueAndProceedIfFirst(name: String, fromRequestActor requestActor: LHWActor) {
        var requestQueueName = requestActor.requestQueueName
        if requestQueueName == nil {
            requestQueueName = name
        }
        
        guard var requestQueue = requestQueues[requestQueueName!] else {
            Logger.debug("===== Warning: requestQueue is nil")
            return
        }
        
        if requestQueue.count == 0 {
            Logger.debug("===== Warning request queue \"\(requestActor.requestQueueName ?? "") is empty.\"")
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
                if requestQueue.contains(where: { $0 === requestActor }) {
                    if let index = requestQueue.index(where: { $0 === requestActor }) {
                        requestQueue.remove(at: index)
                    }
                } else {
                    Logger.debug("===== Warning request queue \"\(requestActor.requestQueueName ?? "")\" doesn't contain request to \(requestActor.path)")
                }
            }
        }
        
        requestQueues[requestQueueName!] = requestQueue
    }
    
    private func scheduleCancelRequest(path: String) {
        guard var requestInfo = activeRequests[path] as? [String: Any] else {
            Logger.debug("===== Warning: cannot cancel request to \"\(path)\": no active request found")
            return
        }
        
        guard let requestActor = requestInfo["requestActor"] as? LHWActor else {
            return
        }
        //            let cancelTimeout = Double(requestActor.cancelTimeout)
        
        activeRequests.removeValue(forKey: path)
        
        requestActor.cancel()
        Logger.debug("===== Cancelled request to \"\(path)\"")
        
        guard let requestQueueName = requestActor.requestQueueName else {
            return
        }
        
        removeRequestFromQueueAndProceedIfFirst(name: requestQueueName, fromRequestActor: requestActor)
        
        /*
                    if cancelTimeout <= DBL_EPSILON {
                        activeRequests.removeValue(forKey: path)
        
                        requestActor.cancel()
                        Logger.debug("Cancelled request to \"\(path)\"")
                        if let requestQueueName = requestActor.requestQueueName {
                            removeRequestFromQueueAndProceedIfFirst(name: requestQueueName, fromrequestActor: requestActor)
                        }
                    } else {
                        Logger.debug("Will cancel request to \"\(path)\" in \(cancelTimeout) s")
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

// MARK: - Default ActionStage

public let ActionStageInstance = LHWActionStage.default
