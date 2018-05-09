/*
 MIT License
 
 RMResponse.swift
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

// JSON Type (Object or Array)
public typealias JSONObject = Dictionary<String, Any>
public typealias JSONArray = [Dictionary<String, Any>]

public enum RMResponseType {
    case object
    case array
    case string
}

// Status code that do not contain response data.
private let successStatusCodes: Set<Int> = [204, 205]

open class RMResponse {
    public var data: NSMutableData? = nil
    public var url: URL? = nil
    public var statusCode: Int!
    public var allHeaders: [AnyHashable : Any]!
    public var httpResponse: HTTPURLResponse? = nil
    public var timeline: RMTime = RMTime()
    
    public var currentType: RMResponseType!
   
    public init() { }
    
    // Serialize JSON response
    public func JSONResponse<T:RMHttpProtocol>(type:RMResponseType, value: T) -> RMHttpObject<T> {
        currentType = type // reference the type
        
        // Check if status code success but no response
        if self.data == nil && !successStatusCodes.contains((httpResponse?.statusCode)!) {
            let error = RMError()
            error.type = .StatusCode
            error.setHttpResponse(error: RMHttpParsingError.noData(NSNull()))
            error.response = self
            return .error(error)
        }
        
        switch type {
        case .object:
            let data =  httpJSONResponseObject(expected: Dictionary<String, Any>())
            if data.isSuccess {
                return data as! RMHttpObject<T>
            }
            return .error(data.error!)
        
        case .array:
            let data =  httpJSONResponseArray(expected: [Dictionary<String, Any>()])
            if data.isSuccess {
                return data as! RMHttpObject<T>
            }
            return .error(data.error!)
        
        default:
            let error = RMError()
            error.type = .Parsing
            return .error(error)
        }
    }
    
    // Serialize String response
    public func StringResponse(encoding: String.Encoding?) -> RMHttpObject<String> {
        return httpResponseString(encoding: encoding)
    }
}

// Private Operations
extension RMResponse {
    
    // JSON Object
    private func httpJSONResponseObject<T>(expected: T) -> RMHttpObject<T> {
        let succesDictionary = ["success" : true] as! T
        if let response = httpResponse, successStatusCodes.contains(response.statusCode) { return .success(succesDictionary)}
        do {
            if let object = try JSONSerialization.jsonObject(with: self.data! as Data, options: .allowFragments) as? T {                
                return .success(object)
            } else {
                let error = RMError()
                error.type = .Parsing
                error.setHttpResponse(error: RMHttpParsingError.invalidType(expected))
                return .error(error)
            }
        } catch let error {
            let error = RMError(error: error)
            error.type = .Parsing
            return .error(error)
        }
    }
    
    // JSON Array
    private func httpJSONResponseArray<T>(expected: T) -> RMHttpObject<T> {
        let succesDictionary = [["success" : true]] as! T
        
        if let response = httpResponse, successStatusCodes.contains(response.statusCode) {
            return .success(succesDictionary)
        }
        
        do {
            if let object = try JSONSerialization.jsonObject(with: self.data! as Data, options: .allowFragments) as? T {
                return .success(object)
            } else {
                let error = RMError()
                error.type = .Parsing
                error.setHttpResponse(error: RMHttpParsingError.invalidType(expected))
                return .error(error)
            }
        } catch let error {
            let error = RMError(error: error)
            error.type = .Parsing
            return .error(error)
        }
    }
    
    // String Response
    private func httpResponseString(encoding: String.Encoding?) -> RMHttpObject<String> {
        if let response = httpResponse, successStatusCodes.contains(response.statusCode) { return .success("success") }
        if let string:String = String(data:self.data! as Data, encoding: encoding!) {
            return .success(string)
        }
        let error = RMError()
        error.type = .Parsing
        error.setHttpResponse(error: RMHttpParsingError.invalidType(String()))
        return .error(error)
    }
}

extension RMResponse: CustomStringConvertible {
    public var description: String {
        var desc: [String] = []
        if let headers = allHeaders {
            desc.append("\(headers)")
        }
        if let status = statusCode {
            desc.append("\(status)")
        }
        if let urlRequest = url {
            desc.append("\(urlRequest)")
        }        
        return desc.joined(separator: " : ")
    }
}
