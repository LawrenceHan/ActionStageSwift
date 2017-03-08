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

enum LHWActionStageStatus: Int {
    case Success = 0
    case Failed = -1
}

enum LHWActorRequestFlags: Int {
    case ChangePriority = 1
}

final class LHWActionStage: NSObject {
    // MARK: -
    static let LHWActionStageInstance = LHWActionStage()
    static let globalFileManager: FileManager = FileManager()
    
    // MARK: -
    private let graphQueueSpecific = "com.hanguang.app.ActionStageSwift.graphdispatchqueue"
    private let graphQueueSpecificKey = DispatchSpecificKey<String>()
    private let mainGraphQueue: DispatchQueue
    let globalGraphQueue: DispatchQueue
    private let highPriorityGraphQueue: DispatchQueue
    
    private let removeWatcherRequestsLock: os_unfair_lock = os_unfair_lock_s()
    private let removeWatcherFromPathRequestsLock: os_unfair_lock = os_unfair_lock_s()
    
    private var _removeWatcherFromPathRequests: Array<(LHWHandler, String)>
    private var _removeWatcherRequests: Array<LHWHandler>
    
    private var requestQueues: Dictionary<String, Array<LHWActor>>
    private var activeRequests: Dictionary<String, Any>
    private var cancelRequestTimers: Dictionary<String, Any>
    private var liveNodeWatchers: Dictionary<String, Array<LHWHandler>>
    private var actorMessagesWatchers: Dictionary<String, Array<LHWWatcher>>
    
    private override init() {
        requestQueues = [String: Array<LHWActor>]()
        activeRequests = [String: Any]()
        cancelRequestTimers = [String: Any]()
        liveNodeWatchers = [String: Array<LHWHandler>]()
        actorMessagesWatchers = [String: Array<LHWWatcher>]()
        
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
    func isCurrentQueueStageQueue() -> Bool {
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
    
    func dispatchOnHighPriorityQueue(_ closure: @escaping () -> Void) {
        if isCurrentQueueStageQueue() {
            closure()
        } else {
            highPriorityGraphQueue.async {
                closure()
            }
        }
    }
    
    func dumpGraphState() {
        dispatchOnStageQueue {
            print("===== SGraph State =====")
            
            print("\(self.liveNodeWatchers.count) live node watchers")
            self.liveNodeWatchers.forEach({ (path, watchers) in
                print("    \(path)")
                for handler in watchers {
                    if let watcher = handler.delegate {
                        print("        \(watcher)")
                    }
                }
            })
                
            print("\(self.activeRequests.count) requests")
            self.activeRequests.forEach({ (path, obj) in
                print("        \(path)")
            })
            
            print("========================");
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
    
    private func _requestGeneric(joinOnly: Bool, inCurrentQueue: Bool, path: String, options: [String: Any], flags: Int, watcher: LHWWatcher) {
        let actionHandler = watcher.actionHandler
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
    
    func requestActor(path: String, options: Dictionary<String, Any>, flags: Int, watcher: LHWWatcher) {
        
    }
    
    func requestActor(path: String, options: Dictionary<String, Any>, watcher: LHWWatcher) {
        
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
            self._requestGeneric(joinOnly: true, inCurrentQueue: true, path: path, options: [:], flags: 0, watcher: watcher)
        }
        
        return rejoinPaths
    }
    
    func isExecutingActorsWithGenericPath(genericPath: String) -> Bool {
        if !isCurrentQueueStageQueue() {
            print("\(#function) should be called from graph queue")
            return false
        }
        
        var result: Bool = false
        
        activeRequests.forEach { (path, requestInfo) in
            <#code#>
        }
    }
    
    func isExecutingActorsWithPathPrefix(pathPrefix: String) -> Bool {
        
    }
    
    func executingActorsWithPathPrefix(_ pathPrefix: String) -> Array<LHWActor> {
        
    }
    
    func executingActorWithPath(_ path: String) -> LHWActor {
        
    }
    
    func watchForPath(_ path:String, watcher: LHWWatcher) {
        
    }
    
    func watchForPaths(_ paths: Array<String>, watcher: LHWWatcher) {
        
    }
    
    func watchForGenericPath(_ path: String, watcher: LHWWatcher) {
        
    }
    
    func watchForMessagesToWatchersAtGenericPath(_ genericPath: String, watcher: LHWWatcher) {
        
    }
    
    func removeWatcherByHandle(_ actionHandler: LHWHandler) {
        
    }
    
    func removeWatcher(_ watcher: LHWWatcher) {
        
    }
    
    func removeWatcherByHandle(_ actionHandler: LHWHandler, fromPath: String) {
        
    }
    
    func removeWatcher(_ watcher: LHWWatcher, fromPath: String) {
        
    }
    
    func removeAllWatchersFromPath(_ path: String) {
        
    }
    
    func requestActorStateNow(_ path: String) -> Bool {
        
    }
    
    // MARK: -
    func dispatchResource(path: String, resource: Any?, arguments: Any?) {
        
    }
    
    func dispatchResource(path: String, resource: Any?) {
        
    }
    
    func actionCompleted(_ action: String, result: Any?) {
        
    }
    
    func dispatchMessageToWatchers(path: String, messageType: String, message: Any?) {
        
    }
    
    func actionFailed(_ action: String, reason: Int) {
        
    }
    
    func nodeRetrieved(path: String, node: LHWGraphNode) {
        
    }
    
    func nodeRetrieveProgress(path: String, progress: Float) {
        
    }
    
    func nodeRetrieveFailed(path: String) {
        
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
}
