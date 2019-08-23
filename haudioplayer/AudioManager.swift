//
//  AudioManager.swift
//  haudioplayer
//
//  Created by Sergii on 5/3/19.
//  Copyright © 2019 Sergei. All rights reserved.
//

import Foundation
import AudioToolbox
import Accelerate

enum AudioFileType: String {
    case mp3
    case aac
    case mpeg4
    case caf
    case wave
}

class AudioManager {
    
    enum _AudioManagerState {
        case initial
        case waitForData
        case waitForPlay
        case play
        case stop
    }
    
    //Audio Stream
    private var audioStream: AudioFileStreamID?
    fileprivate var streamDescription: AudioStreamBasicDescription = AudioStreamBasicDescription()
    fileprivate var audioStartOffset: UInt64 = 0
    fileprivate var audioFormatID: AudioFormatID = 0
    
    //AudioQueue
    fileprivate var audioQueue: AudioQueueRef?
    private let listenerProperties = [kAudioQueueProperty_IsRunning]
    private var audioQueueRunning = false
    fileprivate var primed = false
    var buffer: AudioQueueBufferRef?
    
    //converter
    var converter: AudioConverterRef?
    var newFormat = AudioStreamBasicDescription()
    
    //processing tap
    var processingTap: AudioQueueProcessingTapRef?
    
    fileprivate var _state: _AudioManagerState = .initial
    
    private lazy var unsafeSelf = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
    
    init() {}
    
    func prepare(for audioType: AudioFileType = .mp3) {
        
        _state = .initial
        
        
        var audioType = kAudioFileMP3Type
        
        switch audioType {
        default:
            audioType = kAudioFileMP3Type
        }
        
        let status: OSStatus = AudioFileStreamOpen(unsafeSelf, AudioManager_PropertyListener, AudioManager_PacketProcessor, audioType, &audioStream)
        assert(status == 0, "audio file stream open error")
    }
    
    func feed(data: Data, discontinuity: Bool = false) {
        guard let audioStream = audioStream else { return }
        let size = UInt32(data.count)
        let buffer = data.withUnsafeBytes {
            return UnsafeRawPointer($0)
        }
        
        let flag = discontinuity ? AudioFileStreamParseFlags.discontinuity : AudioFileStreamParseFlags(rawValue: 0)
        AudioFileStreamParseBytes(audioStream, size, buffer, flag)
    }
    
    func play() {
        guard let audioQueue = audioQueue else { return }
        AudioQueueStart(audioQueue, nil)
        _state = .waitForPlay
    }
    
    func stop() {
        guard let audioQueue = audioQueue else { return }
        AudioQueuePause(audioQueue)
    }
    
    fileprivate func prepareAudioQueue() {
        
        newFormat.mSampleRate       = streamDescription.mSampleRate
        newFormat.mFormatID         = kAudioFormatLinearPCM
        newFormat.mFormatFlags      = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved
        newFormat.mFramesPerPacket  = 1
        newFormat.mChannelsPerFrame = 2
        newFormat.mBitsPerChannel   = 32
        newFormat.mBytesPerFrame    = 4
        newFormat.mBytesPerPacket   = 4
        var status = AudioConverterNew(&streamDescription, &newFormat, &converter)
        guard status == noErr else { debugPrint("cant create converter"); return }
        
        status = AudioQueueNewOutput(&newFormat, AudioQueue_OutputCallback, unsafeSelf, nil, nil, 0, &audioQueue)
        
        guard status == noErr else {
            debugPrint("error creating audioqueue")
            return
        }
        
        initListeners()
        
        guard let queue = self.audioQueue else { debugPrint("no queue"); return }
        
//        var maxFrames : UInt32 = 0
//        var tapFormat = AudioStreamBasicDescription()
//        AudioQueueProcessingTapNew(queue, { (inUserData, processingTap, inNumberFrames, timeStamp, flags, outNumberFrames, bufferList) in
//           debugPrint("AudioQueueProcessingTapNewCallback")
//        }, unsafeSelf, [AudioQueueProcessingTapFlags.preEffects], &maxFrames, &tapFormat, &processingTap)
        
        _state = .waitForData
    }
    
    private func initListeners() {
        guard let queue = self.audioQueue else { return }
        
        let status = AudioQueueAddPropertyListener(queue, kAudioQueueProperty_IsRunning, AudioQueue_PropertyListener, unsafeSelf)
        guard status == noErr else {
            debugPrint("cant add property listener", status)
            return
        }
    }
    
    fileprivate func listen(property: AudioQueuePropertyID, in AQ: AudioQueueRef) {
        var dataSize: UInt32 = 0
        var status = AudioQueueGetPropertySize(AQ, property, &dataSize)
        if status == noErr {
            switch property {
            case kAudioQueueProperty_IsRunning:
                var running: UInt32 = 0
                status = AudioQueueGetProperty(AQ, property, &running, &dataSize)
                audioQueueRunning = running == 1
                debugPrint("AudioQueuePropertyListenerProc:kAudioQueueProperty_IsRunning: ", audioQueueRunning)
            default:
                break
            }
        }
    }
    fileprivate func prepareToPlay() {
        
        guard let queue = audioQueue else { return }
        
        if !primed {
            var prepare: UInt32 = 0
            AudioQueuePrime(queue, prepare, &prepare)
            debugPrint("prepared", prepare)
            primed = true
        }
        
        if _state == .waitForPlay && primed {
            play()
        }
    }
    
    func transformInputData(inInputData: UnsafeMutableRawPointer, size: UInt32) {
        
        var newBuffer = AudioBuffer(mNumberChannels: 2, mDataByteSize: 4096, mData: inInputData)
        var newBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: newBuffer)
        var numberOfPackets: UInt32 = 4096/4
        var newSize = size
        
        guard let converter = converter else { debugPrint("no converter"); return }
        
        var status = AudioConverterFillComplexBuffer(converter, AudioConverterInputDataProc, unsafeSelf, &newSize, &newBufferList, nil)
    }
}

fileprivate func AudioConverterInputDataProc(_ converter: AudioConverterRef, _ packetsNum: UnsafeMutablePointer<UInt32>, _ ioData: UnsafeMutablePointer<AudioBufferList>, _ outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?, _ clientData: UnsafeMutableRawPointer?) -> OSStatus {
    
    return noErr
}

fileprivate func AudioManager_PropertyListener(_ clientData: UnsafeMutableRawPointer, _ inAudioFileStream: AudioFileStreamID, _ inPropertyID: AudioFileStreamPropertyID, _ ioFlags: UnsafeMutablePointer<AudioFileStreamPropertyFlags>) {
    debugPrint("AudioManager_PropertyListener")
    
    let audioManager = Unmanaged<AudioManager>.fromOpaque(clientData).takeUnretainedValue()
    
    var dataSize:UInt32 = 0
    var writable: DarwinBoolean = false
    var status = noErr
    
    switch inPropertyID {
    case kAudioFileStreamProperty_DataFormat:
        debugPrint("kAudioFileStreamProperty_DataFormat")
        
        status = AudioFileStreamGetPropertyInfo(inAudioFileStream, inPropertyID, &dataSize, &writable)
        assert(noErr == status)
        
        status = AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &dataSize, &audioManager.streamDescription)
        assert(noErr == status)
        
        debugPrint("estimated duration: ", (1 / audioManager.streamDescription.mSampleRate) * Double(audioManager.streamDescription.mFramesPerPacket))
        
        
        
    case kAudioFileStreamProperty_FileFormat:
        debugPrint("kAudioFileStreamProperty_FileFormat")
        
        status = AudioFileStreamGetPropertyInfo(inAudioFileStream, inPropertyID, &dataSize, &writable)
        assert(noErr == status)
        
        status = AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &dataSize, &audioManager.audioFormatID)
        assert(noErr == status)
        
    case kAudioFileStreamProperty_FormatList:
        debugPrint("kAudioFileStreamProperty_FormatList")
    case kAudioFileStreamProperty_MagicCookieData:
        debugPrint("kAudioFileStreamProperty_MagicCookieData")
    case kAudioFileStreamProperty_AudioDataByteCount:
        debugPrint("kAudioFileStreamProperty_AudioDataByteCount")
    case kAudioFileStreamProperty_AudioDataPacketCount:
        debugPrint("kAudioFileStreamProperty_AudioDataPacketCount")
    case kAudioFileStreamProperty_MaximumPacketSize:
        debugPrint("kAudioFileStreamProperty_MaximumPacketSize")
    case kAudioFileStreamProperty_DataOffset:
        debugPrint("kAudioFileStreamProperty_DataOffset")
        
        status = AudioFileStreamGetPropertyInfo(inAudioFileStream, inPropertyID, &dataSize, &writable)
        assert(noErr == status)
        
        status = AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &dataSize, &audioManager.audioStartOffset)
        assert(noErr == status)
        
    case kAudioFileStreamProperty_ChannelLayout:
        debugPrint("kAudioFileStreamProperty_ChannelLayout")
    case kAudioFileStreamProperty_PacketToFrame:
        debugPrint("kAudioFileStreamProperty_PacketToFrame")
    case kAudioFileStreamProperty_FrameToPacket:
        debugPrint("kAudioFileStreamProperty_FrameToPacket")
    case kAudioFileStreamProperty_PacketToByte:
        debugPrint("kAudioFileStreamProperty_PacketToByte")
    case kAudioFileStreamProperty_ByteToPacket:
        debugPrint("kAudioFileStreamProperty_ByteToPacket")
    case kAudioFileStreamProperty_PacketTableInfo:
        debugPrint("kAudioFileStreamProperty_PacketTableInfo")
    case kAudioFileStreamProperty_PacketSizeUpperBound:
        debugPrint("kAudioFileStreamProperty_PacketSizeUpperBound")
    case kAudioFileStreamProperty_AverageBytesPerPacket:
        debugPrint("kAudioFileStreamProperty_AverageBytesPerPacket")
    case kAudioFileStreamProperty_InfoDictionary:
        debugPrint("kAudioFileStreamProperty_InfoDictionary")
    case kAudioFileStreamProperty_BitRate:
        debugPrint("kAudioFileStreamProperty_BitRate")
    case kAudioFileStreamProperty_ReadyToProducePackets:
        debugPrint("kAudioFileStreamProperty_ReadyToProducePackets")
        audioManager.prepareAudioQueue()
    default:
        debugPrint("some other property")
        break
    }
}

fileprivate func AudioManager_PacketProcessor(_ clientData: UnsafeMutableRawPointer, _ inNumberBytes: UInt32, _ inNumberPackets: UInt32, _ inInputData: UnsafeRawPointer, _ inPacketDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>) {
    debugPrint("AudioManager_PacketProcessor")
    
    let audioManager = Unmanaged<AudioManager>.fromOpaque(clientData).takeUnretainedValue()
    
    audioManager.transformInputData(inInputData: mutablePointer, size: inNumberBytes)
    
    guard let queue = audioManager.audioQueue else { debugPrint("no audio queue"); return }
    var status = AudioQueueAllocateBuffer(queue, inNumberBytes, &audioManager.buffer)
    guard status == noErr else { debugPrint("no audio queue buffer"); return }
    
    audioManager.buffer!.pointee.mAudioDataByteSize = inNumberBytes
    memcpy(audioManager.buffer!.pointee.mAudioData, inInputData, Int(inNumberBytes))
    
    status = AudioQueueEnqueueBuffer(queue, audioManager.buffer!, inNumberPackets, inPacketDescriptions)
    guard status == noErr else { debugPrint("cannot enqueue"); return }
    
    audioManager.prepareToPlay()
}

private func AudioQueue_OutputCallback(_ inUserData: UnsafeMutableRawPointer?, _ inAQ: AudioQueueRef, _ inBuffer: AudioQueueBufferRef) {
    debugPrint("AudioQueue_OutputCallback")
    guard let clientData = inUserData else { return }
    let audioManager = Unmanaged<AudioManager>.fromOpaque(clientData).takeUnretainedValue()
}

fileprivate func AudioQueue_PropertyListener(_ inUserData: UnsafeMutableRawPointer?, _ inAQ: AudioQueueRef, _ inID: AudioQueuePropertyID) {
    debugPrint("AudioQueue_PropertyListener")
    guard let clientData = inUserData else { return }
    let audioManager = Unmanaged<AudioManager>.fromOpaque(clientData).takeUnretainedValue()
    audioManager.listen(property: inID, in: inAQ)
}
