//
//  Filter.swift
//  SwiftyBeaver
//
//  Created by Jeff Roberts on 5/31/16.
//  Copyright © 2015 Sebastian Kreutzberger
//  Some rights reserved: http://opensource.org/licenses/MIT
//

//
//  LHWLogFilter.swift
//  ActionStageSwift
//
//  Created by Hanguang on 2017/3/20.
//  Copyright © 2017年 Hanguang. All rights reserved.
//

import Foundation

/// FilterType is a protocol that describes something that determines
/// whether or not a message gets logged. A filter answers a Bool when it
/// is applied to a value. If the filter passes, it shall return true,
/// false otherwise.
///
/// A filter must contain a target, which identifies what it filters against
/// A filter can be required meaning that all required filters against a specific
/// target must pass in order for the message to be logged. At least one non-required
/// filter must pass in order for the message to be logged
public protocol LHWFilterType : class {
    func apply(_ value: Any) -> Bool
    func getTarget() -> LHWFilter.TargetType
    func isRequired() -> Bool
    func isExcluded() -> Bool
    func reachedMinLevel(_ level: ActionStageSwift.Level) -> Bool
}

/// Filters is syntactic sugar used to easily construct filters
public class LHWFilters {
    public static let Path = PathFilterFactory.self
    public static let Function = FunctionFilterFactory.self
    public static let Message = MessageFilterFactory.self
}

/// Filter is an abstract base class for other filters
public class LHWFilter {
    public enum TargetType {
        case path(LHWFilter.ComparisonType)
        case function(LHWFilter.ComparisonType)
        case message(LHWFilter.ComparisonType)
    }
    
    public enum ComparisonType {
        case startsWith([String], Bool)
        case contains([String], Bool)
        case excludes([String], Bool)
        case endsWith([String], Bool)
        case equals([String], Bool)
    }
    
    let targetType: LHWFilter.TargetType
    let required: Bool
    let minLevel: ActionStageSwift.Level
    
    public init(_ target: LHWFilter.TargetType, required: Bool, minLevel: ActionStageSwift.Level) {
        self.targetType = target
        self.required = required
        self.minLevel = minLevel
    }
    
    public func getTarget() -> LHWFilter.TargetType {
        return self.targetType
    }
    
    public func isRequired() -> Bool {
        return self.required
    }
    
    public func isExcluded() -> Bool {
        return false
    }
    
    /// returns true of set minLevel is >= as given level
    public func reachedMinLevel(_ level: ActionStageSwift.Level) -> Bool {
        //Logger.debug("checking if given level \(level) >= \(minLevel)")
        return level.rawValue >= minLevel.rawValue
    }
}

/// CompareFilter is a FilterType that can filter based upon whether a target
/// starts with, contains or ends with a specific string. CompareFilters can be
/// case sensitive.
public class CompareFilter: LHWFilter, LHWFilterType {
    
    private var filterComparisonType: LHWFilter.ComparisonType?
    
    override public init(_ target: LHWFilter.TargetType, required: Bool, minLevel: ActionStageSwift.Level) {
        super.init(target, required: required, minLevel: minLevel)
        
        let comparisonType: LHWFilter.ComparisonType?
        switch self.getTarget() {
        case let .function(comparison):
            comparisonType = comparison
            
        case let .path(comparison):
            comparisonType = comparison
            
        case let .message(comparison):
            comparisonType = comparison
            
            /*default:
             comparisonType = nil*/
        }
        self.filterComparisonType = comparisonType
    }
    
    public func apply(_ value: Any) -> Bool {
        guard let value = value as? String else {
            return false
        }
        
        guard let filterComparisonType = self.filterComparisonType else {
            return false
        }
        
        let matches: Bool
        switch filterComparisonType {
        case let .contains(strings, caseSensitive):
            matches = !strings.filter { string in
                return caseSensitive ? value.contains(string) :
                    value.lowercased().contains(string.lowercased())
                }.isEmpty
            
        case let .excludes(strings, caseSensitive):
            matches = !strings.filter { string in
                return caseSensitive ? !value.contains(string) :
                    !value.lowercased().contains(string.lowercased())
                }.isEmpty
            
        case let .startsWith(strings, caseSensitive):
            matches = !strings.filter { string in
                return caseSensitive ? value.hasPrefix(string) :
                    value.lowercased().hasPrefix(string.lowercased())
                }.isEmpty
            
        case let .endsWith(strings, caseSensitive):
            matches = !strings.filter { string in
                return caseSensitive ? value.hasSuffix(string) :
                    value.lowercased().hasSuffix(string.lowercased())
                }.isEmpty
            
        case let .equals(strings, caseSensitive):
            matches = !strings.filter { string in
                return caseSensitive ? value == string :
                    value.lowercased() == string.lowercased()
                }.isEmpty
        }
        
        return matches
    }
    
    override public func isExcluded() -> Bool {
        guard let filterComparisonType = self.filterComparisonType else { return false }
        
        switch filterComparisonType {
        case .excludes(_, _):
            return true
        default:
            return false
        }
    }
}

// Syntactic sugar for creating a function comparison filter
public class FunctionFilterFactory {
    public static func startsWith(_ prefixes: String..., caseSensitive: Bool = false,
                                  required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.function(.startsWith(prefixes, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func contains(_ strings: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.function(.contains(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func excludes(_ strings: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.function(.excludes(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func endsWith(_ suffixes: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.function(.endsWith(suffixes, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func equals(_ strings: String..., caseSensitive: Bool = false,
                              required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.function(.equals(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
}

// Syntactic sugar for creating a message comparison filter
public class MessageFilterFactory {
    public static func startsWith(_ prefixes: String..., caseSensitive: Bool = false,
                                  required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.message(.startsWith(prefixes, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func contains(_ strings: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.message(.contains(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func excludes(_ strings: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.message(.excludes(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func endsWith(_ suffixes: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.message(.endsWith(suffixes, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func equals(_ strings: String..., caseSensitive: Bool = false,
                              required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.message(.equals(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
}

// Syntactic sugar for creating a path comparison filter
public class PathFilterFactory {
    public static func startsWith(_ prefixes: String..., caseSensitive: Bool = false,
                                  required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.path(.startsWith(prefixes, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func contains(_ strings: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.path(.contains(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func excludes(_ strings: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.path(.excludes(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func endsWith(_ suffixes: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.path(.endsWith(suffixes, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func equals(_ strings: String..., caseSensitive: Bool = false,
                              required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.path(.equals(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
}

extension LHWFilter.TargetType : Equatable {
}

// The == does not compare associated values for each enum. Instead == evaluates to true
// if both enums are the same "types", ignoring the associated values of each enum
public func == (lhs: LHWFilter.TargetType, rhs: LHWFilter.TargetType) -> Bool {
    switch (lhs, rhs) {
        
    case (.path(_), .path(_)):
        return true
        
    case (.function(_), .function(_)):
        return true
        
    case (.message(_), .message(_)):
        return true
        
    default:
        return false
    }
}

