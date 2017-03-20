//
//  ActionStageSwift
//
//  Created by Sebastian Kreutzberger on 05.12.15.
//  Copyright © 2015 Sebastian Kreutzberger
//  Some rights reserved: http://opensource.org/licenses/MIT
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

#if os(iOS)
let OS = "iOS"
#elseif os(OSX)
let OS = "OSX"
#elseif os(watchOS)
let OS = "watchOS"
#elseif os(tvOS)
let OS = "tvOS"
#endif

public enum Level: Int {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
}

private let LHWLogQueue = LHWQueue(name: "com.hanguang.logqueue")

private let LHWLogFileHandle: FileHandle? = {
    let fileManager = GlobalFileManager
    let documentsDirectory = URL(string: LHWDocumentsPath)!
    
    let currentFilePath = documentsDirectory.appendingPathComponent("application-0.log")
    let oldestFilePath = documentsDirectory.appendingPathComponent("application-30.log")
    
    if fileManager.fileExists(atPath: oldestFilePath.path) {
        do {
            try fileManager.removeItem(atPath: oldestFilePath.path)
        } catch {
        }
    }
    
    for i in (0..<60).reversed() {
        let filePath = documentsDirectory.appendingPathComponent("application-\(i).log")
        let nextFilePath = documentsDirectory.appendingPathComponent("application-\(i+1).log")
        
        if fileManager.fileExists(atPath: filePath.path) {
            do {
                try fileManager.moveItem(atPath: filePath.path, toPath: nextFilePath.path)
            } catch {
            }
        }
    }
    
    fileManager.createFile(atPath: currentFilePath.path, contents: nil, attributes: nil)
    let fileHandle = FileHandle(forWritingAtPath: currentFilePath.path)
    fileHandle?.truncateFile(atOffset: 0)
    
    return fileHandle
}()

private var format = "$DHH:mm:ss.SSS$d $C$L$c $N.$F:$l - $M"

open class LHWLog {
    // MARK: - Types
    
    private struct LevelString {
        var verbose = "VERBOSE"
        var debug = "DEBUG"
        var info = "INFO"
        var warning = "WARNING"
        var error = "ERROR"
    }
    
    // For a colored log level word in a logged line
    // empty on default
    private struct LevelColor {
        var verbose = "💜 "     // silver
        var debug = "💚 "        // green
        var info = "💙 "         // blue
        var warning = "💛 "     // yellow
        var error = "❤️ "       // red
    }
    
    private struct FileLevelColor {
        var verbose = "251m"     // silver
        var debug = "35m"        // green
        var info = "38m"         // blue
        var warning = "178m"     // yellow
        var error = "197m"       // red
    }
    
    // MARK: - Properties
    open var debugPrint = false // set to true to debug the internal filter logic of the class
    var reset = "\u{001b}[0m"
    var escape = "\u{001b}[38;5;"
    
    
    var filters = [LHWFilterType]()
    let formatter = DateFormatter()
    
    /// do not log any message which has a lower level than this one
    private var minLevel = ActionStageSwift.Level.verbose
    
    /// set custom log level words for each level
    private var levelString = LevelString()
    
    /// set custom log level colors for each level
    private var levelColor = LevelColor()
    
    /// set custom file log level colors for each level
    private var fileLevelColor = FileLevelColor()
    
    open private(set) var logToFileEnabled: Bool = true
    
    open static let `default` = LHWLog()
    
    private init() {
//        #if DEBUG
//            logToFileEnabled = true
//        #else
//            logToFileEnabled = false
//        #endif
    }

    // MARK: Levels
    
    public func setEnabled(_ enabled: Bool) {
        logToFileEnabled = enabled
    }
    
    public func LHWLogIsEnabled() -> Bool {
        return logToFileEnabled
    }
    
    public func synchronize() {
        LHWLogQueue.dispatchOnQueue({
            LHWLogFileHandle?.synchronizeFile()
        }, synchronous: false)
    }
    
    public func getFilePaths(count: Int) -> [String] {
        var filePaths: [String] = [String]()
        let documentsDirectory = URL(string: LHWDocumentsPath)!
        
        for i in 0...count {
            let fileName = "application-\(i).log"
            let filePath = documentsDirectory.appendingPathComponent(fileName)
            
            if GlobalFileManager.fileExists(atPath: filePath.path) {
                filePaths.append(filePath.path)
            }
        }
        
        return filePaths
    }
    
    public func getPackedLogs() -> [Data] {
        var resultFiles: [Data] = [Data]()
        
        LHWLogQueue.dispatchOnQueue({ 
            LHWLogFileHandle?.synchronizeFile()
            
            let fileManager = GlobalFileManager
            let documentsDirectory = URL(string: LHWDocumentsPath)!
            
            for i in 0...4 {
                let fileName = "application-\(i).log"
                let filePath = documentsDirectory.appendingPathComponent(fileName)
                
                if fileManager.fileExists(atPath: filePath.path) {
                    if let fileData = try? Data(contentsOf: filePath) {
                        resultFiles.append(fileData)
                    }
                }
            }
        }, synchronous: true)
        
        return resultFiles
    }
    
    /// log something generally unimportant (lowest priority)
    public func verbose(_ message: @autoclosure () -> Any, _
        file: String = #file, _ function: String = #function, line: Int = #line) {
        custom(level: .verbose, message: message, file: file, function: function, line: line)
    }
    
    /// log something which help during debugging (low priority)
    public func debug(_ message: @autoclosure () -> Any, _
        file: String = #file, _ function: String = #function, line: Int = #line) {
        custom(level: .debug, message: message, file: file, function: function, line: line)
    }
    
    /// log something which you are really interested but which is not an issue or error (normal priority)
    public func info(_ message: @autoclosure () -> Any, _
        file: String = #file, _ function: String = #function, line: Int = #line) {
        custom(level: .info, message: message, file: file, function: function, line: line)
    }
    
    /// log something which may cause big trouble soon (high priority)
    public func warning(_ message: @autoclosure () -> Any, _
        file: String = #file, _ function: String = #function, line: Int = #line) {
        custom(level: .warning, message: message, file: file, function: function, line: line)
    }
    
    /// log something which will keep you awake at night (highest priority)
    public func error(_ message: @autoclosure () -> Any, _
        file: String = #file, _ function: String = #function, line: Int = #line) {
        custom(level: .error, message: message, file: file, function: function, line: line)
    }
    
    /// custom logging to manually adjust values, should just be used by other frameworks
    public func custom(level: ActionStageSwift.Level, message: @autoclosure () -> Any,
                       file: String = #file, function: String = #function, line: Int = #line) {
        _log(level: level, message: message,
                      file: file, function: function, line: line)
    }
    
    // MARK: - Privates
    
    /// internal helper which dispatches send to dedicated queue if minLevel is ok
    private func _log(level: ActionStageSwift.Level,
                       message: @autoclosure () -> Any, file: String, function: String, line: Int) {
        var resolvedMessage: String?
        resolvedMessage = resolvedMessage == nil && hasMessageFilters() ? "\(message())" : nil
        
        if shouldLevelBeLogged(level, path: file, function: function, message: resolvedMessage) {
            let msgStr = resolvedMessage == nil ? "\(message())" : resolvedMessage!
            let f = stripParams(function: function)

            LHWLogQueue.dispatchOnQueue({
                if self.logToFileEnabled {
                    if let output = LHWLogFileHandle {
                        guard let formattedString = self.send(level, msg: msgStr, file: file, function: f, line: line, logToFile: self.logToFileEnabled) else {
                            return
                        }
                        
                        let line = formattedString + "\n"
                        if let data = line.data(using: .utf8) {
                            output.write(data)
                        }
                    }
                }
                
                if let formattedString = self.send(level, msg: msgStr, file: file, function: f, line: line) {
                    print(formattedString)
                }
            }, synchronous: false)
        }
    }
    
    /// removes the parameters from a function because it looks weird with a single param
    private func stripParams(function: String) -> String {
        var f = function
        if let indexOfBrace = f.characters.index(of: "(") {
            f = f.substring(to: indexOfBrace)
        }
        f += "()"
        return f
    }
    
    /// send / store the formatted log message to the destination
    /// returns the formatted log message for processing by inheriting method
    /// and for unit tests (nil if error)
    private func send(_ level: ActionStageSwift.Level, msg: String, file: String,
                      function: String, line: Int, logToFile: Bool = false) -> String? {
        
        if format.hasPrefix("$J") {
            return messageToJSON(level, msg: msg, file: file, function: function, line: line)
            
        } else {
            return formatMessage(format, level: level, msg: msg, file: file, function: function, line: line, logToFile: logToFile)
        }
    }
    
    // MARK: - Format
    
    /// returns the log message based on the format pattern
    private func formatMessage(_ format: String, level: ActionStageSwift.Level,
                               msg: String, file: String, function: String, line: Int, logToFile: Bool = false) -> String {
        
        var text = ""
        let phrases: [String] = format.components(separatedBy: "$")
        
        for phrase in phrases {
            if !phrase.isEmpty {
                let firstChar = phrase[phrase.startIndex]
                let rangeAfterFirstChar = phrase.index(phrase.startIndex, offsetBy: 1)..<phrase.endIndex
                let remainingPhrase = phrase[rangeAfterFirstChar]
                
                switch firstChar {
                case "L":
                    text += levelWord(level) + remainingPhrase
                case "M":
                    text += msg + remainingPhrase
                case "N":
                    // name of file without suffix
                    text += fileNameWithoutSuffix(file) + remainingPhrase
                case "n":
                    // name of file with suffix
                    text += fileNameOfFile(file) + remainingPhrase
                case "F":
                    text += function + remainingPhrase
                case "l":
                    text += String(line) + remainingPhrase
                case "D":
                    // start of datetime format
                    text += formatDate(remainingPhrase)
                case "d":
                    text += remainingPhrase
                case "Z":
                    // start of datetime format in UTC timezone
                    text += formatDate(remainingPhrase, timeZone: "UTC")
                case "z":
                    text += remainingPhrase
                case "C":
                    // color code ("" on default)
                    let esc = logToFile ? escape : ""
                    text += esc + colorForLevel(level, logToFile) + remainingPhrase
                case "c":
                    let res = logToFile ? reset : ""
                    text += res + remainingPhrase
                default:
                    text += phrase
                }
            }
        }
        return text
    }
    
    /// returns the log payload as optional JSON string
    private func messageToJSON(_ level: ActionStageSwift.Level,
                               msg: String, file: String, function: String, line: Int) -> String? {
        let dict: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "level": level.rawValue,
            "message": msg,
            "file": file,
            "function": function,
            "line": line]
        return jsonStringFromDict(dict)
    }
    
    /// returns the string of a level
    private func levelWord(_ level: ActionStageSwift.Level) -> String {
        
        var str = ""
        
        switch level {
        case ActionStageSwift.Level.debug:
            str = levelString.debug
            
        case ActionStageSwift.Level.info:
            str = levelString.info
            
        case ActionStageSwift.Level.warning:
            str = levelString.warning
            
        case ActionStageSwift.Level.error:
            str = levelString.error
            
        default:
            // Verbose is default
            str = levelString.verbose
        }
        return str
    }
    
    /// returns color string for level
    private func colorForLevel(_ level: ActionStageSwift.Level, _ logToFile: Bool = false) -> String {
        var color = ""
        
        switch level {
        case ActionStageSwift.Level.debug:
            color = logToFile ? fileLevelColor.debug : levelColor.debug
            
        case ActionStageSwift.Level.info:
            color =  logToFile ? fileLevelColor.info : levelColor.info
            
        case ActionStageSwift.Level.warning:
            color =  logToFile ? fileLevelColor.warning : levelColor.warning
            
        case ActionStageSwift.Level.error:
            color =  logToFile ? fileLevelColor.error : levelColor.error
            
        default:
            color =  logToFile ? fileLevelColor.verbose : levelColor.verbose
        }
        return color
    }
    
    /// returns the filename of a path
    private func fileNameOfFile(_ file: String) -> String {
        let fileParts = file.components(separatedBy: "/")
        if let lastPart = fileParts.last {
            return lastPart
        }
        return ""
    }
    
    /// returns the filename without suffix (= file ending) of a path
    private func fileNameWithoutSuffix(_ file: String) -> String {
        let fileName = fileNameOfFile(file)
        
        if !fileName.isEmpty {
            let fileNameParts = fileName.components(separatedBy: ".")
            if let firstPart = fileNameParts.first {
                return firstPart
            }
        }
        return ""
    }
    
    /// returns a formatted date string
    /// optionally in a given abbreviated timezone like "UTC"
    private func formatDate(_ dateFormat: String, timeZone: String = "") -> String {
        if !timeZone.isEmpty {
            formatter.timeZone = TimeZone(abbreviation: timeZone)
        }
        formatter.dateFormat = dateFormat
        //let dateStr = formatter.string(from: NSDate() as Date)
        let dateStr = formatter.string(from: Date())
        return dateStr
    }
    
    /// returns the json-encoded string value
    /// after it was encoded by jsonStringFromDict
    private func jsonStringValue(_ jsonString: String?, key: String) -> String {
        guard let str = jsonString else {
            return ""
        }
        
        // remove the leading {"key":" from the json string and the final }
        let offset = key.characters.count + 5
        let endIndex = str.index(str.startIndex,
                                 offsetBy: str.characters.count - 2)
        let range = str.index(str.startIndex, offsetBy: offset)..<endIndex
        return str[range]
    }
    
    /// turns dict into JSON-encoded string
    private func jsonStringFromDict(_ dict: [String: Any]) -> String? {
        var jsonString: String?
        
        // try to create JSON string
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [])
            jsonString = String(data: jsonData, encoding: .utf8)
        } catch {
            print("LHWLog could not create JSON from dict.")
        }
        return jsonString
    }
    
    // MARK: - Filters
    
    /// Add a filter that determines whether or not a particular message will be logged to this destination
    public func addFilter(_ filter: LHWFilterType) {
        filters.append(filter)
    }
    
    /// Remove a filter from the list of filters
    public func removeFilter(_ filter: LHWFilterType) {
        let index = filters.index {
            return ObjectIdentifier($0) == ObjectIdentifier(filter)
        }
        
        guard let filterIndex = index else {
            return
        }
        
        filters.remove(at: filterIndex)
    }
    
    /// Answer whether the destination has any message filters
    /// returns boolean and is used to decide whether to resolve
    /// the message before invoking shouldLevelBeLogged
    private func hasMessageFilters() -> Bool {
        return !getFiltersTargeting(LHWFilter.TargetType.Message(.Equals([], true)),
                                    fromFilters: self.filters).isEmpty
    }
    
    /// checks if level is at least minLevel or if a minLevel filter for that path does exist
    /// returns boolean and can be used to decide if a message should be logged or not
    private func shouldLevelBeLogged(_ level: ActionStageSwift.Level, path: String,
                             function: String, message: String? = nil) -> Bool {
        
        if filters.isEmpty {
            if level.rawValue >= minLevel.rawValue {
                if debugPrint {
                    print("filters is empty and level >= minLevel")
                }
                return true
            } else {
                if debugPrint {
                    print("filters is empty and level < minLevel")
                }
                return false
            }
        }
        
        let (matchedExclude, allExclude) = passedExcludedFilters(level, path: path,
                                                                 function: function, message: message)
        if allExclude > 0 && matchedExclude != allExclude {
            if debugPrint {
                print("filters is not empty and message was excluded")
            }
            return false
        }
        
        let (matchedRequired, allRequired) = passedRequiredFilters(level, path: path,
                                                                   function: function, message: message)
        let (matchedNonRequired, allNonRequired) = passedNonRequiredFilters(level, path: path,
                                                                            function: function, message: message)
        if allRequired > 0 {
            if matchedRequired == allRequired {
                return true
            }
        } else {
            // no required filters are existing so at least 1 optional needs to match
            if allNonRequired > 0 {
                if matchedNonRequired > 0 {
                    return true
                }
            } else if allExclude == 0 {
                // no optional is existing, so all is good
                return true
            }
        }
        
        if level.rawValue < minLevel.rawValue {
            if debugPrint {
                print("filters is not empty and level < minLevel")
            }
            return false
        }
        
        return false
    }
    
    private func getFiltersTargeting(_ target: LHWFilter.TargetType, fromFilters: [LHWFilterType]) -> [LHWFilterType] {
        return fromFilters.filter { filter in
            return filter.getTarget() == target
        }
    }
    
    /// returns a tuple of matched and all filters
    private func passedRequiredFilters(_ level: ActionStageSwift.Level, path: String,
                               function: String, message: String?) -> (Int, Int) {
        let requiredFilters = self.filters.filter { filter in
            return filter.isRequired() && !filter.isExcluded()
        }
        
        let matchingFilters = applyFilters(requiredFilters, level: level, path: path,
                                           function: function, message: message)
        if debugPrint {
            print("matched \(matchingFilters) of \(requiredFilters.count) required filters")
        }
        
        return (matchingFilters, requiredFilters.count)
    }
    
    /// returns a tuple of matched and all filters
    private func passedNonRequiredFilters(_ level: ActionStageSwift.Level,
                                  path: String, function: String, message: String?) -> (Int, Int) {
        let nonRequiredFilters = self.filters.filter { filter in
            return !filter.isRequired() && !filter.isExcluded()
        }
        
        let matchingFilters = applyFilters(nonRequiredFilters, level: level,
                                           path: path, function: function, message: message)
        if debugPrint {
            print("matched \(matchingFilters) of \(nonRequiredFilters.count) non-required filters")
        }
        return (matchingFilters, nonRequiredFilters.count)
    }
    
    /// returns a tuple of matched and all exclude filters
    private func passedExcludedFilters(_ level: ActionStageSwift.Level,
                               path: String, function: String, message: String?) -> (Int, Int) {
        let excludeFilters = self.filters.filter { filter in
            return filter.isExcluded()
        }
        
        let matchingFilters = applyFilters(excludeFilters, level: level,
                                           path: path, function: function, message: message)
        if debugPrint {
            print("matched \(matchingFilters) of \(excludeFilters.count) exclude filters")
        }
        return (matchingFilters, excludeFilters.count)
    }
    
    private func applyFilters(_ targetFilters: [LHWFilterType], level: ActionStageSwift.Level,
                      path: String, function: String, message: String?) -> Int {
        return targetFilters.filter { filter in
            
            let passes: Bool
            
            if !filter.reachedMinLevel(level) {
                return false
            }
            
            switch filter.getTarget() {
            case .Path(_):
                passes = filter.apply(path)
                
            case .Function(_):
                passes = filter.apply(function)
                
            case .Message(_):
                guard let message = message else {
                    return false
                }
                
                passes = filter.apply(message)
            }
            
            return passes
            }.count
    }
}

// MARK: - Default Logger

public let Logger = LHWLog.default
