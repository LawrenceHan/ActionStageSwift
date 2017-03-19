//
//  LHWLog.swift
//  ActionStageSwift
//
//
//  Created by Hanguang on 2017/3/19.
//  Copyright © 2017年 Hanguang. All rights reserved.
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
//

import Foundation
import ObjectiveC

open class LHWLog {
    // MRAK: -
//    open static let `default` = LHWLog()
    
    static let LHWLogQueue = LHWQueue(name: "com.hanguang.logqueue")
    static let LHWLogFileHandle = FileHandle()
    
    private init() {
        let fileManager = FileManager()
//        let documentsDirectory = ActionStageInstance.
//        NSString *documentsDirectory = [TGAppDelegate documentsPath];
//        
//        NSString *currentFilePath = [documentsDirectory stringByAppendingPathComponent:@"application-0.log"];
//        NSString *oldestFilePath = [documentsDirectory stringByAppendingPathComponent:@"application-30.log"];
//        
//        if ([fileManager fileExistsAtPath:oldestFilePath])
//        [fileManager removeItemAtPath:oldestFilePath error:nil];
//        
//        for (int i = 60 - 1; i >= 0; i--)
//        {
//            NSString *filePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"application-%d.log", i]];
//            NSString *nextFilePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"application-%d.log", i + 1]];
//            if ([fileManager fileExistsAtPath:filePath])
//            {
//                [fileManager moveItemAtPath:filePath toPath:nextFilePath error:nil];
//            }
//        }
//        
//        [fileManager createFileAtPath:currentFilePath contents:nil attributes:nil];
//        fileHandle = [NSFileHandle fileHandleForWritingAtPath:currentFilePath];
//        [fileHandle truncateFileAtOffset:0];
    }
    
    // MRAK: -
    public func LHWLogSetEnabled(_ enabled: Bool) {
        
    }
    
    public func LHWLogIsEnabled() -> Bool {
        return false
    }
    
    public func LHWLog(_ format: String) {
        
    }
    
    public func LHWLogWithArgs(_ format: String, args: CVarArg) {
        
    }
    
    public func LHWLogSynchronize() {
        
    }
    
    public func LHWLogGetFilePaths(count: Int) -> [String]? {
        return nil
    }
    
    public func LHWLogGetPackedLogs() -> [Data]? {
        return nil
    }
    
    // MRAK: -

}

// MARK: - Default LHWLog
//public let LHWLogger = LHWLog.default
