/*
 MIT License
 
 RMParser.swift
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

public protocol RMHttpParserDelegate {
    func rmParserDidfinished(_ parser: RMParser)
    func rmParserDidFail(_ parser: RMParser, error: RMError?)
    func rmParserDidCancel(_ parser: RMParser)
}

public typealias RMHttpParserComplete = (RMResponse?) -> Swift.Void
public typealias RMHttpParserError = (RMError?) -> Swift.Void

open class RMParser: NSObject {
    public var delegate: RMHttpParserDelegate? = nil
    public var isCancel = false
    public var isError = false

    private var task: URLSessionDataTask? = nil
    private var receiveData: NSMutableData? = nil
    
    private var currentError: RMError? = nil
    private var currentRequest: RMRequest? = nil
    private var currentResponse: RMResponse? = nil
    
    private var parserSuccessHandler:RMHttpParserComplete? = nil
    private var parserErrorHandler: RMHttpParserError? = nil
    
    private var startTime: CFAbsoluteTime?
    private var initializeResponseTime: CFAbsoluteTime?
    private var endTime: CFAbsoluteTime?
    
    private var restrictedStatusCodes:Set<Int> = []
    
    public override init() { super.init() }
    
    public func parseWith(request: RMRequest,
                          completionHandler: RMHttpParserComplete?,
                          errorHandler: RMHttpParserError?) {
        
        parserSuccessHandler = nil
        parserErrorHandler = nil
        currentRequest = nil
        
        // Reference Callbacks and request
        parserSuccessHandler = completionHandler
        parserErrorHandler = errorHandler
        currentRequest = request
        restrictedStatusCodes = request.restrictStatusCodes
        
        // Session configuration
        var session = URLSession.shared
        let sessionConfig = request.sessionConfig // connection per host
        session = URLSession(configuration: sessionConfig!, delegate: self, delegateQueue: OperationQueue.main)
        task = session.dataTask(with: request.urlRequest)
        self.resume()
    }
    
    // MARK: Life cycle
    deinit {
        parserSuccessHandler = nil
        parserErrorHandler = nil
    }
    
    // MARK: Resume task operations
    public func resume() {
        guard let task = task else { return }
        if startTime == nil { startTime = CFAbsoluteTimeGetCurrent() }
        task.resume()
    }
    
    // MARK: Suppend task operations
    public func suspend() {
        guard let task = task else { return }
        task.suspend()
    }
    
    // MARK: Cancel task operations
    public func cancel() {
        guard let task = task else { return }
        
        task.cancel()
        receiveData = nil
        isCancel = true
        if delegate != nil {
            self.delegate?.rmParserDidCancel(self)
        }
    }
    
    // MARK: Set timeline for Task
    private func setTimeline() {
        self.currentResponse?.timeline = RMTime(
            requestTime: self.startTime!,
            initializeResponseTime: self.initializeResponseTime!,
            requestCompletionTime: self.endTime!)
    }
}

// MARK - URLSessionDataDelegate
extension RMParser: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.receiveData?.append(data)
    }
    
    // MARK: Start recieving response
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let response = response as? HTTPURLResponse
        self.initializeResponseTime = CFAbsoluteTimeGetCurrent()
        
        // initial current response
        self.currentResponse = RMResponse()
        self.currentResponse?.url = response?.url
        self.currentResponse?.httpResponse = response
        self.currentResponse?.statusCode = response?.statusCode
        self.currentResponse?.allHeaders = response?.allHeaderFields
        
        // Callback on Error
        if let currentResponse = response, self.restrictedStatusCodes.contains(currentResponse.statusCode) {
            self.isError = true
            self.endTime = CFAbsoluteTimeGetCurrent()
            self.setTimeline()
            
            // Add error object into response object
            let responseError = RMError()
            responseError.type = .StatusCode
            responseError.response = self.currentResponse
            responseError.request = self.currentRequest
            self.parserErrorHandler!(responseError)
            self.delegate?.rmParserDidFail(self, error: responseError)
            completionHandler(.cancel)
        }
        
        // Initialize data
        if self.receiveData != nil { self.receiveData = nil }
        self.receiveData = NSMutableData()
        self.receiveData?.length = 0
        completionHandler(.allow)
    }
}

// MARK - URLSessionTaskDelegate
extension RMParser: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.endTime = CFAbsoluteTimeGetCurrent()
        /** Spawn output to main queue */
        DispatchQueue.main.async {
             self.setTimeline() // Set response end time
            // Callback on Error
            guard error == nil else {
                self.isError = true
                let responseError = RMError(error: error!)
                responseError.type = .SessionTask
                self.parserErrorHandler!(responseError)
                self.delegate?.rmParserDidFail(self, error: responseError)
                return
            }
            
            if self.receiveData != nil && self.receiveData!.length > 0 {
                self.currentResponse?.data = self.receiveData!
            }
            self.parserSuccessHandler!(self.currentResponse)
            self.delegate?.rmParserDidfinished(self)
        }
    }
}
