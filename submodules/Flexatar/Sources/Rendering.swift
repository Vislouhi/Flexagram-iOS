//
//  Rendering.swift
//  Flexatar
//
//  Created by Matey Vislouh on 21.04.2024.
//

import Foundation
import AVFoundation
import UIKit
public class FrameProvider{
    
    public static var pixelBuffer: CVPixelBuffer?
    public static var frameTimer: Timer?
    public static var position:Int = 0
    public static func invalidateFlexatarDrawTimer(){
        print("FLX_INJECT stop")
        if let isValid = frameTimer?.isValid{
            if (isValid) {
                DispatchQueue.main.async{
                    frameTimer?.invalidate()
                }
            }
            pixelBuffer = nil
        }
    }
    public static func flexatarDrawTimer( onFrame:@escaping(CVPixelBuffer)->()){
       
        DispatchQueue.main.async{
            if let timer = frameTimer{
                if timer.isValid {
                    timer.invalidate()
                }
            }
            frameTimer = Timer.scheduledTimer(withTimeInterval: Double(1)/Double(24), repeats: true) { _ in

                    if let pixelBuffer = FrameProvider.drawPixelBuffer(){
                        onFrame(pixelBuffer)
                    }
      
            }
        }
    }
    
    public static func drawPixelBuffer() ->  CVPixelBuffer?{
        let width = Int(640)
        let height = Int(480)

        if pixelBuffer == nil {
            let status = CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
            
            guard status == kCVReturnSuccess else {
                return nil
            }
        }
        if let buffer = pixelBuffer {
            // Lock the base address of the pixel buffer for writing
            CVPixelBufferLockBaseAddress(buffer, [])
            defer {
                CVPixelBufferUnlockBaseAddress(buffer, [])
            }
            
            // Get the base address of the pixel buffer
            guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
                return nil
            }
            
            // Create a Core Graphics context using the pixel buffer
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(data: baseAddress,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                          space: colorSpace,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
                return nil
            }
            
            // Draw a rectangle on the context
            context.setAlpha(255.0)
            context.setFillColor(UIColor.black.cgColor)
            let rectFull = CGRect(origin: CGPoint(x:0,y:0), size: CGSize(width: width, height: height))
            context.fill(rectFull)
            
            context.setFillColor(UIColor.red.cgColor)
            var barWidth = Int( -SoundProcessing.speachAnimVector[2] * Float(width)/4 )
            if barWidth<0 {barWidth = 0}
            barWidth+=10
            let x = width/2 - barWidth/2
            
            let barHeight = abs(Int(SoundProcessing.speachAnimVector[0] * Float(height)/2 ))+10
            let y = height/2 - barHeight/2
            
            let rect = CGRect(origin: CGPoint(x:x,y:y), size: CGSize(width: barWidth, height: barHeight))
            position+=1
            if position == 500{position = 0}
            context.fill(rect)
            
            
            return buffer
        }
        return nil
    }
    
}
