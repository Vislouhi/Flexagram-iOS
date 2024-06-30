//
//  RoundVideoWriter.swift
//  Flexatar
//
//  Created by Matey Vislouh on 23.06.2024.
//

import Foundation
import AVFoundation
import TelegramCore
import SwiftSignalKit
import AccountContext
import UIKit
import MediaResources
import LocalMediaResources
import ImageCompression
import Postbox
//import MediaEditor
class TwoEventSemaphore {
    private let semaphore = DispatchSemaphore(value: 0)
    private var eventCount = 0
    private let lock = NSLock()
    
    // Function to be called when an event happens
    func eventHappened() {
        lock.lock()
        eventCount += 1
        if eventCount == 2 {
            semaphore.signal()
        }
        lock.unlock()
    }
    
    // Function to wait until two events have happened
    func wait() {
        semaphore.wait()
    }
}
public class RoundVideoWriter{
//    public init(){
//        let width = 400
//        let height = 400
//        
//    }
    static func configureSampleBuffer(pcmBuffer: AVAudioPCMBuffer,startTime:CMTime) -> CMSampleBuffer? {
        let audioBufferList = pcmBuffer.mutableAudioBufferList
        let asbd = pcmBuffer.format.streamDescription

        var sampleBuffer: CMSampleBuffer? = nil
        var format: CMFormatDescription? = nil
        
        var status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault,
                                                         asbd: asbd,
                                                   layoutSize: 0,
                                                       layout: nil,
                                                       magicCookieSize: 0,
                                                       magicCookie: nil,
                                                       extensions: nil,
                                                       formatDescriptionOut: &format);
        if (status != noErr) { return nil; }
        
        var timing: CMSampleTimingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: Int32(asbd.pointee.mSampleRate)),
            presentationTimeStamp: startTime,
            decodeTimeStamp: CMTime.invalid)
        status = CMSampleBufferCreate(allocator: kCFAllocatorDefault,
                                      dataBuffer: nil,
                                      dataReady: false,
                                      makeDataReadyCallback: nil,
                                      refcon: nil,
                                      formatDescription: format,
                                      sampleCount: CMItemCount(pcmBuffer.frameLength),
                                      sampleTimingEntryCount: 1,
                                      sampleTimingArray: &timing,
                                      sampleSizeEntryCount: 0,
                                      sampleSizeArray: nil,
                                      sampleBufferOut: &sampleBuffer);
        if (status != noErr) { NSLog("CMSampleBufferCreate returned error: \(status)"); return nil }
        
        status = CMSampleBufferSetDataBufferFromAudioBufferList(sampleBuffer!,
                                                                blockBufferAllocator: kCFAllocatorDefault,
                                                                blockBufferMemoryAllocator: kCFAllocatorDefault,
                                                                flags: 0,
                                                                bufferList: audioBufferList);
        if (status != noErr) { NSLog("CMSampleBufferSetDataBufferFromAudioBufferList returned error: \(status)"); return nil; }
        
        return sampleBuffer
    }
    private static func audioPCMBufferToCMSampleBuffer(audioBuffer: AVAudioPCMBuffer) -> CMSampleBuffer? {
        var audioFormat = audioBuffer.format.streamDescription.pointee
        let numSamples = audioBuffer.frameLength
//        let channels = Int(audioFormat.mChannelsPerFrame)
//
//        // Create AudioBufferList
//        var audioBufferList = AudioBufferList(
//            mNumberBuffers: 1,
//            mBuffers: AudioBuffer(
//                mNumberChannels: audioFormat.mChannelsPerFrame,
//                mDataByteSize: audioBuffer.audioBufferList.pointee.mBuffers.mDataByteSize,
//                mData: audioBuffer.audioBufferList.pointee.mBuffers.mData
//            )
//        )

        // Create CMBlockBuffer
        var blockBuffer: CMBlockBuffer?
        let status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: audioBuffer.audioBufferList.pointee.mBuffers.mData,
            blockLength: Int(audioBuffer.audioBufferList.pointee.mBuffers.mDataByteSize),
            blockAllocator: kCFAllocatorNull,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: Int(audioBuffer.audioBufferList.pointee.mBuffers.mDataByteSize),
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        if status != kCMBlockBufferNoErr {
            print("Error creating CMBlockBuffer: \(status)")
            return nil
        }

        // Create CMSampleBuffer
        var formatDescription: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &audioFormat,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )

        var sampleBuffer: CMSampleBuffer?
        let sampleBufferStatus = CMAudioSampleBufferCreateWithPacketDescriptions(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription!,
            sampleCount: CMItemCount(numSamples),
            presentationTimeStamp: CMTime.zero,
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        )

        if sampleBufferStatus != noErr {
            print("Error creating CMSampleBuffer: \(sampleBufferStatus)")
            return nil
        }

        return sampleBuffer
    }

    private static func makePcmBuffer()  -> AVAudioPCMBuffer? {
        let fileName = "flx_auido.bin"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
       
        
        do{
                // Calculate the frame length
            let rawData = try Data(contentsOf: fileURL)
            
            // Define the audio format
            let sampleRate: Double = 48000.0
            let channels: AVAudioChannelCount = 1  // Change this if your audio has multiple channels
            let bitsPerChannel: UInt32 = 16
            
            // Calculate the frame length
            let bytesPerFrame = Int(bitsPerChannel / 8) * Int(channels)
            let frameLength = rawData.count / bytesPerFrame
            
            // Define the audio format
            guard let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: channels, interleaved: true) else {
                print("Failed to create audio format")
                return nil
            }
            
            // Create a PCM buffer
            guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameLength)) else {
                print("Failed to create PCM buffer")
                return nil
            }
            
            // Fill the buffer with raw data
            rawData.withUnsafeBytes { rawBufferPointer in
                guard let rawPointer = rawBufferPointer.baseAddress else { return }
                let audioBufferPointer = pcmBuffer.audioBufferList.pointee.mBuffers.mData
                audioBufferPointer?.copyMemory(from: rawPointer, byteCount: rawData.count)
            }
            
            // Set the frame length
            pcmBuffer.frameLength = AVAudioFrameCount(frameLength)
            
            return pcmBuffer
        } catch {
            print("Error reading raw audio file: \(error)")
            return nil
        }
        
    }
    public static func makeRoundVideo(peerId:Int64,speechAnim:[[Float]],completion:@escaping(URL)->()){
        let width = 400
        let height = 400
        let frameRate:Int32 = 30
        let outputFileName = NSUUID().uuidString
        let outputFilePath = NSTemporaryDirectory() + outputFileName + ".mp4"
        
        let outputFileURL = URL(fileURLWithPath: outputFilePath)
       
//        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//        let outputFileURL = documentsDirectory.appendingPathComponent(outputFileName + ".mp4")
        do {
                let assetWriter = try AVAssetWriter(outputURL: outputFileURL, fileType: .mp4)
                
                // Video settings
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: width,
                    AVVideoHeightKey: height
                ]
                let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: nil)

                if assetWriter.canAdd(videoInput) {
                    assetWriter.add(videoInput)
                }
            print("FLX_INJECT start pcm buffer read")
                let audioBuffer = makePcmBuffer()!
                let sampleBuffer = configureSampleBuffer(pcmBuffer: audioBuffer, startTime: .zero)!
            print("FLX_INJECT pcm buffer read done")
//                 Audio settings
            var channelLayout = AudioChannelLayout()
            memset(&channelLayout, 0, MemoryLayout<AudioChannelLayout>.size)
            channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
            let outputSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 48000,
                AVEncoderBitRateKey: 32000,
                AVNumberOfChannelsKey: 1,
                AVChannelLayoutKey: NSData(bytes: &channelLayout, length: MemoryLayout<AudioChannelLayout>.size)
            ]
            
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)

                if assetWriter.canAdd(audioInput) {
                    assetWriter.add(audioInput)
                }

                // Start writing
                assetWriter.startWriting()
                assetWriter.startSession(atSourceTime: .zero)

                // Append video frames
//                var frameCount: Int64 = 0
//                let frameDuration = CMTimeMake(value: 1, timescale: frameRate)

//                for pixelBuffer in pixelBuffers {
//                    let presentationTime = CMTimeMake(value: frameCount, timescale: frameRate)
//                    while !videoInput.isReadyForMoreMediaData {
//                        Thread.sleep(forTimeInterval: 0.1)
//                    }
//                    pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
//                    frameCount += 1
//                }
            print("FLX_INJECT video writing done")
                // Append audio
                
//                let audioBufferList = audioBuffer.audioBufferList.pointee
//                let audioTime = CMTimeMake(value: 0, timescale: Int32(audioBuffer.format.sampleRate))
                while !audioInput.isReadyForMoreMediaData {Thread.sleep(forTimeInterval: 0.1)}
//                let sampleBuffer = configureSampleBuffer(pcmBuffer: audioBuffer, startTime: .zero)!
                audioInput.append(sampleBuffer)
////                audioInput.append(AVAudioPCMBufferPCMFormat(audioBufferList, frameLength: audioBuffer.frameLength))
//
                audioInput.markAsFinished()
            print("FLX_INJECT audio writing done")
            
            print("FLX_INJECT start video writing")
            let semaphore = TwoEventSemaphore()
            RenderEngine.flexatarDidLoad = {
                semaphore.eventHappened()
            }
            RenderEngine.staticResDidLoad = {
                semaphore.eventHappened()
            }
            
            _ = FrameProvider.drawPixelBuffer(peerId: peerId,width: 400,height: 400,tag: "round",speechAnim:[0,0,0,0,0],isRotated:false)
            semaphore.wait()
//            var i = 0
//        wloop:while true{
//                if let _ = FrameProvider.drawPixelBuffer(peerId: peerId,width: 400,height: 400,tag: "round",speechAnim:[0,0,0,0,0],isRotated:false){
//                    i+=1
//                    if i>30{
//                        break wloop
//                    }
//                }
//                Thread.sleep(forTimeInterval: 1/20)
//            }
            
            var counter:Int64 = 0
//        videoLoop:while true{
//                if let _ = FrameProvider.drawPixelBuffer(peerId: peerId,width: 400,height: 400,tag: "round",speechAnim:[0,0,0,0,0],isRotated:false){
//                    counter += 1
//                }
//                if counter >= 10 {
//                    break videoLoop
//                }
//            }
////                let frameTotalCount = 100
//            counter = 0
            var timeCounter:Double = 0
            var currentSpeechFrame:Int = 0
            let speechDelta:Double = 1/20
        videoLoop:while true{
                currentSpeechFrame = Int(timeCounter / speechDelta)
            if currentSpeechFrame >= speechAnim.count {break videoLoop}
            if let pixelBuffer = FrameProvider.drawPixelBuffer(peerId: peerId,width: 400,height: 400,tag: "round",speechAnim:speechAnim[currentSpeechFrame],isRotated:false){
                    let presentationTime = CMTimeMake(value: counter, timescale: frameRate)
                    print(videoInput.isReadyForMoreMediaData)
                    while !videoInput.isReadyForMoreMediaData {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    counter += 1
                    timeCounter += 1/30
//                    if counter > frameTotalCount{
//                        break videoLoop
//                    }
                }else{
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
            ChooserFlx.inst(tag: "round", peerId: peerId).renderEngine = nil
            FrameProvider.destroyEngineInstance()
                videoInput.markAsFinished()
           
                // Finish writing
                assetWriter.finishWriting {
                    completion(outputFileURL)
                    print("FLX_INJECT Finished writing video to \(outputFileURL)")
                }

            } catch {
                print("FLX_INJECT Error setting up asset writer: \(error)")
            }
        
        
    
        
    }
    public static func makeVideoMessage(url:URL,duration: Double,context:AccountContext,peerId: PeerId){
        let videoPaths: [String] = [url.getPath()]
        
        
        let startTime: Double = 0.0
        let finalDuration: Double = duration
       
        
        let dimensions = PixelDimensions(width: 400, height: 400)
        
        
       
        let thumbnailImage: Signal<UIImage, NoError> = Signal { subscriber in
            let composition = composition(url: url)
            
            
            let imageGenerator = AVAssetImageGenerator(asset: composition)
            imageGenerator.maximumSize = dimensions.cgSize
            imageGenerator.appliesPreferredTrackTransform = true
            
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTime(seconds: startTime, preferredTimescale: composition.duration.timescale))], completionHandler: { _, image, _, _, _ in
                if let image {
                    subscriber.putNext(UIImage(cgImage: image))
                }
                subscriber.putCompletion()
            })
            
            return ActionDisposable {
                imageGenerator.cancelAllCGImageGeneration()
            }
        }
        let _ = (thumbnailImage
        |> deliverOnMainQueue).startStandalone(next: {  thumbnailImage in
//            guard let self else {
//                return
//            }
            
 
            
            
            let dimensions = PixelDimensions(width: 400, height: 400)
            let resource: TelegramMediaResource = LocalFileVideoMediaResource(randomId: Int64.random(in: Int64.min ... Int64.max), paths: videoPaths, adjustments: nil)
            
            
            var previewRepresentations: [TelegramMediaImageRepresentation] = []
                        
            let thumbnailResource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
            let thumbnailSize = CGSize(width:400,height:400).aspectFitted(CGSize(width: 320.0, height: 320.0))
            if let thumbnailData = scaleImageToPixelSize(image: thumbnailImage, size: thumbnailSize)?.jpegData(compressionQuality: 0.4) {
                context.account.postbox.mediaBox.storeResourceData(thumbnailResource.id, data: thumbnailData)
                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(thumbnailSize), resource: thumbnailResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
            }
            
            let tempFile = TempBox.shared.tempFile(fileName: "file")
            defer {
                TempBox.shared.dispose(tempFile)
            }
            if let data = compressImageToJPEG(thumbnailImage, quality: 0.7, tempFilePath: tempFile.path) {
                context.account.postbox.mediaBox.storeCachedResourceRepresentation(resource, representation: CachedVideoFirstFrameRepresentation(), data: data)
            }

            let media = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: previewRepresentations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: [.FileName(fileName: "video.mp4"), .Video(duration: finalDuration, size: dimensions, flags: [.instantRoundVideo], preloadSize: nil)])
            
            
            let attributes: [MessageAttribute] = []
//            if self.cameraState.isViewOnceEnabled {
//                attributes.append(AutoremoveTimeoutMessageAttribute(timeout: viewOnceTimeout, countdownBeginTime: nil))
//            }
               let message = EnqueueMessage.message(
                    text: "",
                    attributes: attributes,
                    inlineStickers: [:],
                    mediaReference: .standalone(media: media),
                    threadId: nil,
                    replyToMessageId: nil,
                    replyToStoryId: nil,
                    localGroupingKey: nil,
                    correlationId: nil,
                    bubbleUpEmojiOrStickersets: []
                )
            _ = (enqueueMessages(account: context.account, peerId: peerId, messages: [message])
                 |> deliverOnMainQueue).startStandalone(next: {_ in })
            
        })
        
       
    }
    private static func composition(url:URL) -> AVComposition{
        let composition = AVMutableComposition()
        var currentTime = CMTime.zero
        let asset = AVAsset(url: url)
        let duration = asset.duration
        do {
            try composition.insertTimeRange(
                CMTimeRangeMake(start: .zero, duration: duration),
                of: asset,
                at: currentTime
            )
            currentTime = CMTimeAdd(currentTime, duration)
        } catch {
        }
        return composition
    }
}
