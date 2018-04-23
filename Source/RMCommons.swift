/*
 MIT License
 
 RMHttpCommons.swift
 Copyright (c) 2018 Roger Molas
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */


import Foundation

// RMHttp Base object protocol
public protocol RMHttpProtocol {
    associatedtype BaseObject
    
    static func getType() -> BaseObject.Type
    
    static func internalError() -> RMError?
}

// Response object protocol
public protocol RMHttpObjectAcceptable {
    associatedtype SerializedObject
    
    mutating func set(object: SerializedObject?)
    
    func getValue() -> SerializedObject?
    
    func getError() -> RMError? // Http Error value)
}

// HTTP parameters Encoding
public enum Encoding: String {
    case URLEncoding = "URLEncoding"
    case JSONEncoding = "JSONEncoding"
}

// HTTP Methods
public enum RMHttpMethod<Encoder> {
    case GET(Encoder)
    case POST(Encoder)
    case DELETE(Encoder)
    case PUT(Encoder)
    case PATCH(Encoder)
    
    // Parameters Encoding
    public var encoding: Encoder {
        switch self {
            case .GET (let encoder): return encoder
            case .POST(let encoder): return encoder
            case .DELETE(let encoder): return encoder
            case .PATCH(let encoder): return encoder
            case .PUT(let encoder): return encoder
        }
    }
    
    // HTTP Methods
    public var httpMethod: String {
        switch self {
            case .GET:return "GET"
            case .POST: return "POST"
            case .DELETE: return "DELETE"
            case .PATCH: return "PATCH"
            case .PUT: return "PUT"
        }
    }
}

// Data parsing problems
public enum RMHttpParsingError<TYPE:RMHttpProtocol> {
    case invalidType(TYPE)
    case noData(TYPE)
    case invalidData(TYPE)
    case unknown(TYPE)
}

// Response object type
public enum RMHttpObject<Value:RMHttpProtocol> : RMHttpObjectAcceptable {
    public typealias SerializedObject = Value
    
    case success(Value)
    case error(RMError)
    
    public func getValue() -> Value? {
        switch self {
        case .success(let value): return value
        case .error: return nil
        }
    }

    public func getError() -> RMError? {
        switch self {
            case .success: return nil
            case .error (let error): return error
        }
    }
    
    public var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .error:
            return false
        }
    }
    
    // Additional setter if custom object added
    public func set(object: SerializedObject?) { }
}

extension RMHttpObject {
    public var value: Value? { return getValue() }
    
    public var error: RMError? { return getError() }
}

// Comply to RMHttp base object Protocol
extension RMHttpObject : RMHttpProtocol {
    public typealias BaseObject = Value
    
    public static func internalError() -> RMError? {
        return nil
    }
    
    public static func getType() -> BaseObject.Type { return Value.self }
    
    public var type: BaseObject.Type {
        return RMHttpObject.getType() // Dynamic Object type
    }
}

// Dictionary Response (JSON object)
extension Dictionary:RMHttpProtocol {
    public typealias BaseObject = Dictionary<String, Any>
    
    public static func internalError() -> RMError? {
        return nil
    }

    public static func getType() -> Dictionary<String, Any>.Type {
        return Dictionary<String, Any>.self
    }
}

// Array Response (JSON Array)
extension Array:RMHttpProtocol {
    public typealias BaseObject = [Dictionary<String, Any>]
    
    public static func internalError() -> RMError? {
        return nil
    }
    
    public static func getType() -> [Dictionary<String, Any>].Type {
        return [Dictionary<String, Any>].self
    }
}

// String Response (all Strings, e.g HTM string)
extension String: RMHttpProtocol {
    public typealias BaseObject = String
    
    public static func internalError() -> RMError? {
        return nil
    }
    
    public static func getType() -> String.Type {
        return String.self
    }
}

// Error Response (All error)
extension RMError: RMHttpProtocol {
    public typealias BaseObject = RMError
    
    public static func internalError() -> RMError? {
        return nil
    }
    
    public static func getType() -> RMError.Type {
        return RMError.self
    }
}

extension NSNull: RMHttpProtocol {
    public typealias BaseObject = NSNull
    
    public static func internalError() -> RMError? {
        return nil
    }
    
    public static func getType() -> NSNull.Type {
        return NSNull.self
    }
}

func associatedObject<ValueType: AnyObject>( base: AnyObject, key: UnsafePointer<UInt8>, initialiser: () -> ValueType) -> ValueType {
    if let associated = objc_getAssociatedObject(base, key) as? ValueType { return associated }
    let associated = initialiser()
    objc_setAssociatedObject(base, key, associated, .OBJC_ASSOCIATION_RETAIN)
    return associated
}

func associateObject<ValueType: AnyObject>(base: AnyObject, key: UnsafePointer<UInt8>, value: ValueType) {
    objc_setAssociatedObject(base, key, value,.OBJC_ASSOCIATION_RETAIN)
}
