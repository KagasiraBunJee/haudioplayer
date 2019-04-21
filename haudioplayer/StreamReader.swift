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

public class RemoteStreamReader: NSObject, StreamReader, URLSessionDelegate {
    
    private lazy var downloadsSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "hplayer_bg_task")
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    private var task: URLSessionDataTask?
    
    var delegate: StreamReaderDelegate?
    
    override init() {
        super.init()
    }
    
    func startRead(from url: URL) {
        let urlRequest = URLRequest(url: url)
        task = downloadsSession.dataTask(with: urlRequest)
        task?.resume()
    }
    
    private func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        debugPrint(#function)
    }
    
    private func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        delegate?.streamReader?(self, receivedError: error)
    }
}

extension RemoteStreamReader: URLSessionDataDelegate {
    
    private func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        let info = [
            StreamDataInfoKey.fullDataSize.rawValue: response.expectedContentLength,
            StreamDataInfoKey.mimeType.rawValue: response.mimeType ?? "audio/mpeg"
        ] as StreamDataInfo
        
        delegate?.streamReader?(self, receivedInfo: info)
        completionHandler(.allow)
    }
    
    private func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        delegate?.streamReader?(self, didRead: data)
    }
    
}
