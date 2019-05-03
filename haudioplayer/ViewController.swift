//
//  ViewController.swift
//  haudioplayer
//
//  Created by Sergei on 4/21/19.
//  Copyright © 2019 Sergei. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let audioList = [
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3"
    ]
    
    var reader = RemoteStreamReader()
    var audioManager = AudioManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        reader.delegate = self
        audioManager.prepare(for: .mp3)
    }

    @IBAction func downloadTouched(_ sender: Any) {
        guard let url = URL(string: audioList[0]) else { return }
        reader.startRead(from: url)
    }
    
    @IBAction func playTouched(_ sender: Any) {
        audioManager.play()
    }
    
    @IBAction func pauseTouched(_ sender: Any) {
        audioManager.stop()
    }
}

extension ViewController: StreamReaderDelegate {
    
    func streamReader(_ reader: StreamReader, didRead data: Data) {
        audioManager.feed(data: data)
    }
    
}

