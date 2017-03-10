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
import Darwin.os.lock

@objc enum LHWActionStageStatus: Int {
    case Success = 0
    case Failed = -1
}

enum LHWActorRequestFlags: Int {
    case ChangePriority = 1
}

final class LHWActionStage: NSObject {
    // MARK: -
    static let instance = LHWActionStage()
    static let globalFileManager: FileManager = FileManager()
    
    // MARK: -
    private let graphQueueSpecific = "com.hanguang.app.ActionStageSwift.graphdispatchqueue"
    private let graphQueueSpecificKey = DispatchSpecificKey<String>()
    private let mainGraphQueue: DispatchQueue
    private let globalGraphQueue: DispatchQueue
    private let highPriorityGraphQueue: DispatchQueue
    
    private var removeWatcherRequestsLock: OSSpinLock = LHW_SPINLOCKER_INIT()
    private var removeWatcherFromPathRequestsLock: OSSpinLock = LHW_SPINLOCKER_INIT()
    
    private var _removeWatcherFromPathRequests: [(LHWHandler, String)]
    private var _removeWatcherRequests: [LHWHandler]
    
    private var requestQueues: [String: [LHWActor]]
    private var activeRequests: [String: Any]
//    private var cancelRequestTimers: Dictionary<String, Any>
    private var liveNodeWatchers: [String: [LHWHandler]]
    private var actorMessagesWatchers: [String: [LHWHandler]]
    
    private override init() {
        requestQueues = [String: Array<LHWActor>]()
        activeRequests = [String: Any]()
//        cancelRequestTimers = [String: Any]()
        liveNodeWatchers = [String: [LHWHandler]]()
        actorMessagesWatchers = [String: [LHWHandler]]()
        
        mainGraphQueue = DispatchQueue(label: graphQueueSpecific)
        
        globalGraphQueue = DispatchQueue(label: graphQueueSpecific+"-global")
        globalGraphQueue.setTarget(queue: mainGraphQueue)
        
        highPriorityGraphQueue = DispatchQueue(label: graphQueueSpecific+"-high")
        highPriorityGraphQueue.setTarget(queue: mainGraphQueue)
        
        mainGraphQueue.setSpecific(key: graphQueueSpecificKey, value: graphQueueSpecific)
        globalGraphQueue.setSpecific(key: graphQueueSpecificKey, value: graphQueueSpecific)
        highPriorityGraphQueue.setSpecific(key: graphQueueSpecificKey, value: graphQueueSpecific)
        
        _removeWatcherFromPathRequests = [(LHWHandler, String)]()
        _removeWatcherRequests = [LHWHandler]()
    }
    
    // MARK: -
    func globalStageDispatchQueue() -> DispatchQueue {
        return globalGraphQueue
    }
    
    func isCurrentQueueStageQueue() -> Bool { //
        return DispatchQueue.getSpecific(key: graphQueueSpecificKey) != nil
    }
    
    func dispatchOnStageQueue(_ closure: @escaping () -> Void) {
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
                    print("=== Dispatch took \(executionTime) s" )
                }
            #endif
        } else {
            #if DEBUG
                globalGraphQueue.async {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    closure()
                    let executionTime = CFAbsoluteTimeGetCurrent() - startTime
                    if executionTime > 0.1 {
                        print("=== Dispatch took \(executionTime) s" )
                    }
                }
            #else
                globalGraphQueue.async {
                    closure()
                }
            #endif
        }
    }
    
    func genericStringForParametrizedPath(_ path: String) -> String {
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
    
    func requestActor(path: String, options: Dictionary<String, Any>, flags: Int = 0, watcher: LHWWatcher) {
        _requestGeneric(joinOnly: false, inCurrentQueue: false, path: path, options: options, flags: flags, watcher: watcher)
    }
    
    func changeActorPriority(path: String) {
        dispatchOnStageQueue {
            if let requestInfo = self.activeRequests[path] as? [String: Any] {
                let actor = requestInfo["requestBuilder"] as! LHWActor
                if actor.requestQueueName != nil {
                    var reuqestQueue = self.requestQueues[actor.requestQueueName!]
                    if  reuqestQueue != nil || reuqestQueue?.count != 0 {
                        if let index = reuqestQueue?.index(of: actor) {
                            if index != 0 && index != 1 {
                                reuqestQueue?.remove(at: index)
                                reuqestQueue?.insert(actor, at: 1)
                                
                                print("Changed actor \(path) priority (next in \(actor.requestQueueName)")
                            }
                        }
                    }
                }
            }
            
        }
    }
    
    func rejoinActionsWithGenericPathNow(genericPath: String, prefix: String, watcher: LHWWatcher) -> [String] {
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
    
    func isExecutingActorsWithGenericPath(genericPath: String) -> Bool {
        if !isCurrentQueueStageQueue() {
            print("\(#function) should be called from graph queue")
            return false
        }
        
        var result: Bool = false
        
        for (_, actionInfo) in activeRequests {
            if let actionInfo = actionInfo as? [String: Any] {
                if let _ = actionInfo["requestBuilder"] as? LHWActor {
                    if genericPath == LHWActor.genericPath() {
                        result = true
                        break
                    }
                }
            }
        }
        
        return result
    }
    
    func isExecutingActorsWithPathPrefix(pathPrefix: String) -> Bool {
        if !isCurrentQueueStageQueue() {
            print("\(#function) should be called from graph queue")
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
    
    func executingActorsWithPathPrefix(_ pathPrefix: String) -> Array<LHWActor>? {
        if !isCurrentQueueStageQueue() {
            print("\(#function) should be called from graph queue")
            return nil
        }
        
        var array = [LHWActor]()
        for (path, actionInfo) in activeRequests {
            if path.hasPrefix(pathPrefix) {
                if let actionInfo = actionInfo as? [String: Any] {
                    if let actor = actionInfo["requestBuilder"] as? LHWActor {
                        array.append(actor)
                    }
                }
            }
        }
        
        return array
    }
    
    func executingActorWithPath(_ path: String) -> LHWActor? {
        if !isCurrentQueueStageQueue() {
            print("\(#function) should be called from graph queue")
            return nil
        }
        
        if let requestInfo = activeRequests[path] as? [String: Any] {
            if let requestBuilder = requestInfo["requestBuilder"] as? LHWActor {
                return requestBuilder
            }
        }
        
        return nil
    }
    
    func watchForPath(_ path:String, watcher: LHWWatcher) {
        guard let actionHandler = watcher.actionHandler else {
            print("=== Warning: actionHandler is nil in \(#function):\(#line)")
            return
        }
        
        dispatchOnStageQueue {
            var pathWatchers = self.liveNodeWatchers[path]
            if pathWatchers == nil {
                pathWatchers = [LHWHandler]()
                self.liveNodeWatchers[path] = pathWatchers
            }
            
            if !pathWatchers!.contains(actionHandler) {
                pathWatchers!.append(actionHandler)
            }
        }
    }
    
    func watchForPaths(_ paths: Array<String>, watcher: LHWWatcher) {
        guard let actionHandler = watcher.actionHandler else {
            print("=== Warning: actionHandler is nil in \(#function):\(#line)")
            return
        }
        
        dispatchOnStageQueue {
            for path in paths {
                var pathWatchers = self.liveNodeWatchers[path]
                if pathWatchers == nil {
                    pathWatchers = [LHWHandler]()
                    self.liveNodeWatchers[path] = pathWatchers
                }
                
                if !pathWatchers!.contains(actionHandler) {
                    pathWatchers!.append(actionHandler)
                }
            }
        }
    }
    
    func watchForGenericPath(_ path: String, watcher: LHWWatcher) {
        guard let actionHandler = watcher.actionHandler else {
            print("=== Warning: actionHandler is nil in \(#function):\(#line)")
            return
        }
        
        dispatchOnStageQueue {
            let genericPath = self.genericStringForParametrizedPath(path)
            var pathWatchers = self.liveNodeWatchers[genericPath]
            if pathWatchers == nil {
                pathWatchers = [LHWHandler]()
                self.liveNodeWatchers[genericPath] = pathWatchers
            }
            
            pathWatchers!.append(actionHandler)
        }
    }
    
    func watchForMessagesToWatchersAtGenericPath(_ genericPath: String, watcher: LHWWatcher) {
        guard let actionHandler = watcher.actionHandler else {
            print("=== Warning: actionHandler is nil in \(#function):\(#line)")
            return
        }
        
        dispatchOnStageQueue {
            var pathWatchers = self.actorMessagesWatchers[genericPath]
            if pathWatchers == nil {
                pathWatchers = [LHWHandler]()
                self.actorMessagesWatchers[genericPath] = pathWatchers
            }
            
            pathWatchers!.append(actionHandler)
        }
    }
    
    func removeWatcherByHandler(_ actionHandler: LHWHandler) {
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
            var removeWatchers: [LHWHandler] = [LHWHandler]()
            LHW_SPINLOCKER_LOCK(&self.removeWatcherRequestsLock)
            for handler in self._removeWatcherRequests {
                removeWatchers.append(handler)
            }
            self._removeWatcherRequests.removeAll()
            LHW_SPINLOCKER_UNLOCK(&self.removeWatcherRequestsLock)
            
            for handler in removeWatchers {
                // Cancel activeRequests
                for path in self.activeRequests.keys {
                    var requestInfo = self.activeRequests[path] as? [String: Any]
                    var watchers = requestInfo?["watchers"] as? [LHWHandler]
                    watchers?.remove(object: handler)
                    
                    if watchers?.count == 0 {
                        self.scheduleCancelRequest(path: path)
                    }
                }
                
                // Remove liveNodeWatchers
                var keysTobeRemoved = [String]()
                for key in self.liveNodeWatchers.keys {
                    var watchers = self.liveNodeWatchers[key]
                    watchers?.remove(object: handler)
                    
                    if watchers?.count == 0 {
                        keysTobeRemoved.append(key)
                    }
                }
                
                if keysTobeRemoved.count > 0 {
                    for key in keysTobeRemoved {
                        self.liveNodeWatchers.removeValue(forKey: key)
                    }
                }
                
                // Remove actorMessagesWatchers
                var keysTobeRemoved1 = [String]()
                for key in self.actorMessagesWatchers.keys {
                    var watchers = self.actorMessagesWatchers[key]
                    watchers?.remove(object: handler)
                    
                    if watchers?.count == 0 {
                        keysTobeRemoved1.append(key)
                    }
                }
                
                if keysTobeRemoved1.count > 0 {
                    for key in keysTobeRemoved1 {
                        self.actorMessagesWatchers.removeValue(forKey: key)
                    }
                }
            }
        }
    }
    
    func removeWatcher(_ watcher: LHWWatcher) {
        removeWatcherByHandler(watcher.actionHandler!)
    }
    
    func removeWatcherByHandler(_ actionHandler: LHWHandler, fromPath: String) {
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
            var removeWatchersFromPath: [(LHWHandler, String)] = [(LHWHandler, String)]()
            LHW_SPINLOCKER_LOCK(&self.removeWatcherFromPathRequestsLock)
            for (handler, path) in self._removeWatcherFromPathRequests {
                removeWatchersFromPath.append((handler, path))
            }
            self._removeWatcherFromPathRequests.removeAll()
            LHW_SPINLOCKER_UNLOCK(&self.removeWatcherFromPathRequestsLock)
            
            if removeWatchersFromPath.count > 1 {
                print("Cancelled \(removeWatchersFromPath.count) requests at once")
            }

            
            for (handler, path) in removeWatchersFromPath {
                if path.characters.count == 0 {
                    continue
                }
                
                // Cancel activeRequests
                for path in self.activeRequests.keys {
                    if let requestInfo = self.activeRequests[path] as? [String: Any] {
                        if var watchers = requestInfo["watchers"] as? [LHWHandler] {
                            if watchers.contains(handler) {
                                watchers.remove(object: handler)
                            }
                            
                            if watchers.count == 0 {
                                self.scheduleCancelRequest(path: path)
                            }
                        }
                    }
                }
                
                // Remove liveNodeWatchers
                if var watchers = self.liveNodeWatchers[path] {
                    if watchers.contains(handler) {
                        watchers.remove(object: handler)
                    }
                    
                    if watchers.count == 0 {
                        self.liveNodeWatchers.removeValue(forKey: path)
                    }
                }
                
                // Remove actorMessagesWatchers
                if var watchers = self.actorMessagesWatchers[path] {
                    if watchers.contains(handler) {
                        watchers.remove(object: handler)
                    }
                    
                    if watchers.count == 0 {
                        self.actorMessagesWatchers.removeValue(forKey: path)
                    }
                }
            }
        }
    }
    
    func removeWatcher(_ watcher: LHWWatcher, fromPath: String) {
        if let handler = watcher.actionHandler {
            removeWatcherByHandler(handler, fromPath: fromPath)
        }
    }
    
    func removeAllWatchersFromPath(_ path: String) {
        dispatchOnHighPriorityQueue {
            if var requestInfo = self.activeRequests[path] as? [String: Any] {
                var watchers = requestInfo["watchers"] as? [LHWHandler]
                watchers?.removeAll()
                self.scheduleCancelRequest(path: path)
            }
        }
    }
    
    func requestActorStateNow(_ path: String) -> Bool {
        if let _ = activeRequests[path] {
            return true
        }
        return false
    }
    
    func dispatchResource(path: String, resource: Any? = nil, arguments: Any? = nil) {
        dispatchOnStageQueue {
            let genericPath = self.genericStringForParametrizedPath(path)
            
            if let watchers = self.liveNodeWatchers[path] {
                for handler in watchers {
                    var watcher = handler.delegate
                    watcher?.actionStageResourceDispatched?(path: path, resource: resource, arguments: arguments)
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
                        watcher?.actionStageResourceDispatched?(path: path, resource: resource, arguments: arguments)
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
    
    func actionCompleted(_ action: String, result: Any? = nil) {
        dispatchOnStageQueue {
            if let requestInfo = self.activeRequests[action] as? [String: Any] {
                var actionWatchers = requestInfo["watchers"] as! [LHWHandler]
                self.activeRequests.removeValue(forKey: action)
                
                for handler in actionWatchers {
                    var watcher = handler.delegate
                    watcher?.actorCompleted?(status: .Success, path: action, result: result)
                    
                    if handler.releaseOnMainThread {
                        DispatchQueue.main.async {
                            _ = watcher.self
                        }
                    }
                    watcher = nil
                }
                actionWatchers.removeAll()
                
                if let requestBuilder = requestInfo["requestBuilder"] as? LHWActor {
                    if let requestQueueName = requestBuilder.requestQueueName {
                        self.removeRequestFromQueueAndProceedIfFirst(
                            name: requestQueueName, fromRequestBuilder: requestBuilder
                        )
                    }
                } else {
                    print("===== Warning requestBuilder is nil")
                }
            }
        }
    }
    
    func dispatchMessageToWatchers(path: String, messageType: String? = nil, message: Any? = nil) {
        dispatchOnStageQueue {
            if let requestInfo = self.activeRequests[path] as? [String: Any] {
                let actionWatchers = requestInfo["watchers"] as! [LHWHandler]
                for handler in actionWatchers {
                    handler.receiveActorMessage(path: path, messageType: messageType, message: message)
                }
            }
            
            if self.actorMessagesWatchers.count != 0 {
                let genericPath = self.genericStringForParametrizedPath(path)
                if let messagesWatchers = self.actorMessagesWatchers[genericPath] {
                    for handler in messagesWatchers {
                        handler.receiveActorMessage(path: path, messageType: messageType, message: message)
                    }
                }
            }
        }
    }
    
    func actionFailed(_ action: String, reason: LHWActionStageStatus) {
        dispatchOnStageQueue {
            if let requestInfo = self.activeRequests[action] as? [String: Any] {
                var actionWatchers = requestInfo["watchers"] as! [LHWHandler]
                self.activeRequests.removeValue(forKey: action)
                
                for handler in actionWatchers {
                    var watcher = handler.delegate
                    watcher?.actorCompleted?(status: reason, path: action, result: nil)
                    
                    if handler.releaseOnMainThread {
                        DispatchQueue.main.async {
                            _ = watcher.self
                        }
                    }
                    watcher = nil
                }
                actionWatchers.removeAll()
                
                if let requestBuilder = requestInfo["requestBuilder"] as? LHWActor {
                    if let requestQueueName = requestBuilder.requestQueueName {
                        self.removeRequestFromQueueAndProceedIfFirst(
                            name: requestQueueName, fromRequestBuilder: requestBuilder
                        )
                    }
                } else {
                    print("===== Warning requestBuilder is nil")
                }
            }
        }
    }
    
    func nodeRetrieved(path: String, node: LHWGraphNode) {
        actionCompleted(path, result: node)
    }
    
    func nodeRetrieveProgress(path: String, progress: Float) {
        dispatchOnStageQueue {
            if let requestInfo = self.activeRequests[path] as? [String: Any] {
                if let watchers = requestInfo["watchers"] as? [LHWHandler] {
                    for handler in watchers {
                        var watcher = handler.delegate
                        watcher?.actorReportedProgress?(path: path, progress: progress)
                        
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
    
    func nodeRetrieveFailed(path: String) {
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
            print("===== SGraph State =====")
            
            print("\(self.liveNodeWatchers.count) live node watchers")
            for (path, watchers) in self.liveNodeWatchers {
                print("    \(path)")
                for handler in watchers {
                    if let watcher = handler.delegate {
                        print("        \(watcher)")
                    }
                }
            }
            
            print("\(self.activeRequests.count) requests")
            for (path, _) in self.activeRequests {
                print("        \(path)")
            }
            
            print("========================");
        }
    }
    
    private func _requestGeneric(joinOnly: Bool, inCurrentQueue: Bool, path: String, options: [String: Any], flags: Int, watcher: LHWWatcher) {
        guard let actionHandler = watcher.actionHandler else {
            print("=== Warning: actionHandler is nil in \(#function):\(#line)")
            return
        }
        
        let requestClosure = {
            if !actionHandler.hasDelegate() {
                print("Error: \(#function):\(#line) actionHandler.delegate is nil")
                return
            }
            
            var activeRequests = self.activeRequests
            let genericPath = self.genericStringForParametrizedPath(path)
            var requestInfo: Dictionary<String, Any>? = activeRequests[path] as? Dictionary<String, Any>
            
            if joinOnly && requestInfo == nil { return }
            
            if requestInfo == nil {
                if let requestBuilder = LHWActor.requestBuilderForGenericPath(genericPath, path: path) {
                    let watchers = [actionHandler]
                    
                    requestInfo = [
                        "requestBuilder": requestBuilder,
                        "watchers": watchers
                    ]
                    
                    activeRequests[path] = requestInfo
                    
                    requestBuilder.prepare(options: options)
                    
                    var executeNow = true
                    if let requestQueueName = requestBuilder.requestQueueName {
                        var requestQueue = self.requestQueues[requestQueueName]
                        if requestQueue == nil {
                            requestQueue = [requestBuilder]
                            self.requestQueues[requestQueueName] = requestQueue
                        } else {
                            requestQueue?.append(requestBuilder)
                            if requestQueue!.count > 1 {
                                executeNow = false
                                print("Adding request \(requestBuilder) to request queue \"\(requestQueueName)\"")
                                
                                if flags == LHWActorRequestFlags.ChangePriority.rawValue {
                                    if requestQueue!.count > 2 {
                                        requestQueue?.removeLast()
                                        requestQueue?.insert(requestBuilder, at: 1)
                                        
                                        print("Inserted actor with high priority (next in queue)")
                                    }
                                }
                            }
                        }
                    }
                    
                    if executeNow {
                        requestBuilder.execute(options: options)
                    } else {
                        requestBuilder.storedOptions = options
                    }
                } else {
                    print("Error: request builder not found for \"\(path)\"")
                }
            } else {
                var watchers = requestInfo?["watchers"] as! Array<LHWHandler>
                if !(watchers.contains(actionHandler)) {
                    print("Joining watcher to the wathcers of \"\(path)\"")
                    watchers.append(actionHandler)
                } else {
                    print("Continue to watch for actor \"\(path)\"")
                }
                
                let actor = requestInfo?["requestBuilder"] as! LHWActor
                if actor.requestQueueName == nil {
                    actor.watcherJoined(watcherHandler: actionHandler, options: options, waitingInActorQueue: false)
                } else {
                    var reuqestQueue = self.requestQueues[actor.requestQueueName!]
                    if  reuqestQueue == nil || reuqestQueue?.count == 0 {
                        actor.watcherJoined(watcherHandler: actionHandler, options: options, waitingInActorQueue: false)
                    } else {
                        let wait = reuqestQueue?[0] != actor
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
    
    private func removeRequestFromQueueAndProceedIfFirst(name: String, fromRequestBuilder requestBuilder: LHWActor) {
        var requestQueueName = requestBuilder.requestQueueName
        if requestQueueName == nil {
            requestQueueName = name
        }
        
        if var requestQueue = requestQueues[requestQueueName!] {
            if requestQueue.count == 0 {
                print("***** Warning ***** request queue \"\(requestBuilder.requestQueueName) is empty.\"")
            } else {
                if requestQueue[0] == requestBuilder {
                    requestQueue.remove(at: 0)
                    
                    if requestQueue.count != 0 {
                        let nextRequest = requestQueue[0]
                        let nextRequestOptions = nextRequest.storedOptions
                        nextRequest.storedOptions = nil
                        
                        if !nextRequest.cancelled {
                            nextRequest.execute(options: nextRequestOptions)
                        }
                    } else {
                        requestQueues.removeValue(forKey: requestBuilder.requestQueueName!)
                    }
                } else {
                    if requestQueue.contains(requestBuilder) {
                        if let index = requestQueue.index(of: requestBuilder) {
                            requestQueue.remove(at: index)
                        }
                    } else {
                        print("===== Warning request queue \"\(requestBuilder.requestQueueName)\" doesn't contain request to \(requestBuilder.path)")
                    }
                }
            }
        } else {
            print("Warning: requestQueue is nil")
        }
    }
    
    private func scheduleCancelRequest(path: String) {
        var activeRequests = self.activeRequests
        if var requestInfo = activeRequests[path] as? [String: Any] {
            let requestBuilder = requestInfo["requestBuilder"] as! LHWActor
//            let cancelTimeout = Double(requestBuilder.cancelTimeout)
            
            activeRequests.removeValue(forKey: path)
            
            requestBuilder.cancel()
            print("Cancelled request to \"\(path)\"")
            if let requestQueueName = requestBuilder.requestQueueName {
                removeRequestFromQueueAndProceedIfFirst(name: requestQueueName, fromRequestBuilder: requestBuilder)
            }
            
//            if cancelTimeout <= DBL_EPSILON {
//                activeRequests.removeValue(forKey: path)
//                
//                requestBuilder.cancel()
//                print("Cancelled request to \"\(path)\"")
//                if let requestQueueName = requestBuilder.requestQueueName {
//                    removeRequestFromQueueAndProceedIfFirst(name: requestQueueName, fromRequestBuilder: requestBuilder)
//                }
//            } else {
//                print("Will cancel request to \"\(path)\" in \(cancelTimeout) s")
//                let cancelDict = [
//                    "path": path,
//                    "type": 0
//                ] as [String : Any]
//                
//                performCancelRequest(cancelDict: cancelDict)
//            }
        } else {
            print("Warning: cannot cancel request to \"\(path)\": no active request found")
        }
    }
    
//    func performCancelRequest(cancelDict: [String: Any]) {
//        let path = cancelDict["path"] as! String
//        
//        dispatchOnStageQueue {
//            let requestInfo =
//        }
//    }
}
