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

enum LHWActionStageStatus: Int {
    case Success = 0
    case Failed = -1
}

final class LHWActionStage {
    // MARK: -
    static let LHWActionStageInstance = LHWActionStage()
    private let graphQueueSpecific = "com.hanguang.app.ActionStageSwift.graphdispatchqueue"
    private let graphQueueSpecificKey = DispatchSpecificKey<String>()
    private let mainGraphQueue: DispatchQueue
    let globalGraphQueue: DispatchQueue
    private let highPriorityGraphQueue: DispatchQueue
    
    private let removeWatcherRequestsLock: OSSpinLock = OS_SPINLOCK_INIT
    private let removeWatcherFromPathRequestsLock: OSSpinLock = OS_SPINLOCK_INIT
    
    private var _removeWatcherFromPathRequests: Array<(LHWHandler, String)>
    private var _removeWatcherRequests: Array<LHWHandler>
    
    private var requestQueues: Dictionary<String, Array<LHWActor>>
    private var activeRequests: Dictionary<String, Any>
    private var cancelRequestTimers: Dictionary<String, Any>
    private var liveNodeWatchers: Dictionary<String, Array<LHWHandler>>
    private var actorMessagesWatchers: Dictionary<String, Array<LHWWatcher>>
    
    private init() {
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
            print("\(self.liveNodeWatchers.count) live node watchers");
            liveNodeWatchers.forEach({ ((path, watchers)) in
                <#code#>
            })
            
            [_liveNodeWatchers enumerateKeysAndObjectsUsingBlock:^(NSString *path, NSArray *watchers, __unused BOOL *stop)
                {
                TGLog(@"    %@", path);
                for (ASHandle *handle in watchers)
                {
                id<ASWatcher> watcher = handle.delegate;
                if (watcher != nil)
                {
                TGLog(@"        %@", [watcher description]);
                }
                }
                }];
            TGLog(@"%d requests", _activeRequests.count);
            [_activeRequests enumerateKeysAndObjectsUsingBlock:^(NSString *path, __unused id obj, __unused BOOL *stop) {
                TGLog(@"        %@", path);
                }];
            TGLog(@"========================");
        }
    }
    
    func globalFileManager() -> FileManager {
        
    }
    
    func cancelActorTimeout(path: String) {
        
    }
    
    func genericStringForParametrizedPath(path: String) -> String {
        
    }
    
    func requestActor(path: String, options: Dictionary<String, Any>, flags: Int, watcher: LHWWatcher) {
        
    }
    
    func requestActor(path: String, options: Dictionary<String, Any>, watcher: LHWWatcher) {
        
    }
    
    func changeActorPriority(path: String) {
        
    }
    
    func rejoinActionsWithGenericPathNow(genericPath: String, prefix: String, watcher: LHWWatcher) {
        
    }
    
    func isExecutingActorsWithGenericPath(genericPath: String) -> Bool {
        
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
