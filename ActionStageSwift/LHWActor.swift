//
//  LHWActor.swift
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

class LHWActor: NSObject {
    // MARK: -
    private static var registeredRequestBuilders: Dictionary<String, AnyClass> = Dictionary<String, AnyClass>()
    
    var path: String
    var requestQueueName: String? = nil
    var storedOptions: Dictionary<String, Any>? = Dictionary<String, Any>()
    var requiresAuthorization: Bool = false
    var cancelTimeout: TimeInterval
    var cancelToken: Any? = nil
    var multipleCancelTokens: [Any] = [Any]()
    var cancelled: Bool = false
    
    required init(path: String) {
        self.cancelTimeout = 0
        self.path = path
    }
    
    // MARK: -
    class func registerActorClass(_ requestBuilderClass: AnyClass) {
        guard let genericPath = requestBuilderClass.genericPath() else {
            print("Error: LHWActor.registerActorClass: genericPath is nil")
            return
        }
        
        registeredRequestBuilders[genericPath] = requestBuilderClass
    }
    
    class func requestBuilderForGenericPath(_ genericPath: String, path: String) -> LHWActor? {
        let builderClass = registeredRequestBuilders[genericPath]
        if builderClass != nil && builderClass is LHWActor.Type {
            let builderInstance = (builderClass as! LHWActor.Type).init(path: path)
            return builderInstance
        } else {
            return nil
        }
    }
    
    class func genericPath() -> String? {
        print("Error: LHWActor.genericPath: no default implementation provided")
        return nil
    }
    
    // MARK: -
    func prepare(options: [String: Any]?) {
    }
    
    func execute(options: [String: Any]?) {
    }
    
    func cancel() {
        cancelled = true
    }
    
    func addCancelToken(token: Any) {
        multipleCancelTokens.append(token)
    }
    
    func watcherJoined(watcherHandler: LHWHandler, options: Dictionary<String, Any>, waitingInActorQueue: Bool) {
    }
    
    func handleRequestProblem() {
    }
    
}
