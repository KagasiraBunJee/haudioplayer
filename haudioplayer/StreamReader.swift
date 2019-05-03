//
//  StreamReader.swift
//  haudioplayer
//
//  Created by Sergei on 4/21/19.
//  Copyright © 2019 Sergei. All rights reserved.
//

import Foundation
import AudioToolbox
import AVFoundation
import UIKit

@objc enum StreamDataInfoKey: Int {
    case fullDataSize
    case mimeType
}

typealias StreamDataInfo = [StreamDataInfoKey.RawValue: Any]

@objc
protocol StreamReaderDelegate {
    @objc optional func streamReader(_ reader: StreamReader, receivedInfo: StreamDataInfo)
    @objc optional func streamReader(_ reader: StreamReader, receivedError: Error?)
    @objc optional func streamReader(_ reader: StreamReader, didRead data: Data)
}

@objc
protocol StreamReader {
    func startRead(from url: URL)
}

public class RemoteStreamReader: NSObject, StreamReader {
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "some_bg_session")
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private var task: URLSessionDataTask?
    private var backgroundTask: UIBackgroundTaskIdentifier?
    
    weak var delegate: StreamReaderDelegate?
    
    override init() {
        super.init()
    }
    
    func startRead(from url: URL) {
        var urlRequest = URLRequest(url: url)
        urlRequest.addValue("1", forHTTPHeaderField: "Icy-MetaData")
        
        endBackgroundTask()
        self.backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            self.endBackgroundTask()
        })
        
        task = session.dataTask(with: urlRequest)
        task?.resume()
    }
    
    private func endBackgroundTask() {
        if let task = self.backgroundTask {
            UIApplication.shared.endBackgroundTask(task)
            self.backgroundTask = UIBackgroundTaskIdentifier.invalid
        }
    }
}

extension RemoteStreamReader: URLSessionDataDelegate {
    
    @available(iOS 11.0, *)
    public func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
        
        completionHandler(.continueLoading, request)
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        debugPrint(#function)
    }
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        debugPrint(error)
        delegate?.streamReader?(self, receivedError: error)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
//        debugPrint(response)
        let info = [
            StreamDataInfoKey.fullDataSize.rawValue: response.expectedContentLength,
            StreamDataInfoKey.mimeType.rawValue: response.mimeType ?? "audio/mpeg"
        ] as StreamDataInfo
        
        delegate?.streamReader?(self, receivedInfo: info)
        completionHandler(.allow)
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        debugPrint("URLSessionDataTask")
        delegate?.streamReader?(self, didRead: data)
    }
    
}
