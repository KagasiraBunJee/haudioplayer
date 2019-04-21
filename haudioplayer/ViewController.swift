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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let url = URL(string: audioList[0]) else { return }
        reader.startRead(from: url)
    }


}

