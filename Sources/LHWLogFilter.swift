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
        case Path(LHWFilter.ComparisonType)
        case Function(LHWFilter.ComparisonType)
        case Message(LHWFilter.ComparisonType)
    }
    
    public enum ComparisonType {
        case StartsWith([String], Bool)
        case Contains([String], Bool)
        case Excludes([String], Bool)
        case EndsWith([String], Bool)
        case Equals([String], Bool)
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
        case let .Function(comparison):
            comparisonType = comparison
            
        case let .Path(comparison):
            comparisonType = comparison
            
        case let .Message(comparison):
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
        case let .Contains(strings, caseSensitive):
            matches = !strings.filter { string in
                return caseSensitive ? value.contains(string) :
                    value.lowercased().contains(string.lowercased())
                }.isEmpty
            
        case let .Excludes(strings, caseSensitive):
            matches = !strings.filter { string in
                return caseSensitive ? !value.contains(string) :
                    !value.lowercased().contains(string.lowercased())
                }.isEmpty
            
        case let .StartsWith(strings, caseSensitive):
            matches = !strings.filter { string in
                return caseSensitive ? value.hasPrefix(string) :
                    value.lowercased().hasPrefix(string.lowercased())
                }.isEmpty
            
        case let .EndsWith(strings, caseSensitive):
            matches = !strings.filter { string in
                return caseSensitive ? value.hasSuffix(string) :
                    value.lowercased().hasSuffix(string.lowercased())
                }.isEmpty
            
        case let .Equals(strings, caseSensitive):
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
        case .Excludes(_, _):
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
        return CompareFilter(.Function(.StartsWith(prefixes, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func contains(_ strings: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.Function(.Contains(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func excludes(_ strings: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.Function(.Excludes(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func endsWith(_ suffixes: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.Function(.EndsWith(suffixes, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func equals(_ strings: String..., caseSensitive: Bool = false,
                              required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.Function(.Equals(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
}

// Syntactic sugar for creating a message comparison filter
public class MessageFilterFactory {
    public static func startsWith(_ prefixes: String..., caseSensitive: Bool = false,
                                  required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.Message(.StartsWith(prefixes, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func contains(_ strings: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.Message(.Contains(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func excludes(_ strings: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.Message(.Excludes(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func endsWith(_ suffixes: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.Message(.EndsWith(suffixes, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func equals(_ strings: String..., caseSensitive: Bool = false,
                              required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.Message(.Equals(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
}

// Syntactic sugar for creating a path comparison filter
public class PathFilterFactory {
    public static func startsWith(_ prefixes: String..., caseSensitive: Bool = false,
                                  required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.Path(.StartsWith(prefixes, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func contains(_ strings: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.Path(.Contains(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func excludes(_ strings: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.Path(.Excludes(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func endsWith(_ suffixes: String..., caseSensitive: Bool = false,
                                required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.Path(.EndsWith(suffixes, caseSensitive)), required: required, minLevel: minLevel)
    }
    
    public static func equals(_ strings: String..., caseSensitive: Bool = false,
                              required: Bool = false, minLevel: ActionStageSwift.Level = .verbose) -> LHWFilterType {
        return CompareFilter(.Path(.Equals(strings, caseSensitive)), required: required, minLevel: minLevel)
    }
}

extension LHWFilter.TargetType : Equatable {
}

// The == does not compare associated values for each enum. Instead == evaluates to true
// if both enums are the same "types", ignoring the associated values of each enum
public func == (lhs: LHWFilter.TargetType, rhs: LHWFilter.TargetType) -> Bool {
    switch (lhs, rhs) {
        
    case (.Path(_), .Path(_)):
        return true
        
    case (.Function(_), .Function(_)):
        return true
        
    case (.Message(_), .Message(_)):
        return true
        
    default:
        return false
    }
}

