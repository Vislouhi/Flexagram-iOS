//
//  MetalResourceProviderFlx.swift
//  Flexatar
//
//  Created by Matey Vislouh on 04.05.2024.
//

import Foundation
import Metal
import MetalKit
public class MetalResProviderFlx{
    public static var indexCount = 0
    public static var vtxBufferOfset = 0
    public static var keyUv = SIMD3<Float>(0,0,1)
    public static func getFileUrl(name:String)->URL{
   
        let mainBundle = Bundle(for: MetalResProviderFlx.self)
        guard let path = mainBundle.path(forResource: "FlexatarMetalSourcesBundle", ofType: "bundle") else {
 
            fatalError("FLX_INJECT flexatar metal source bundle not found")
           
        }
        guard let bundle = Bundle(path: path) else {

            fatalError("FLX_INJECT bundle at path not found")
        }
        guard let fileUrl = bundle.url(forResource:name, withExtension: "dat") else{
            fatalError("FLX_INJECT file not found")
        }
        return fileUrl
    }
    public static func makeMTLBuffer(device:MTLDevice,buffer:Data)->MTLBuffer?{
        let mtlBuffer = device.makeBuffer(length: buffer.count, options: [])
        let pointer = mtlBuffer?.contents()
        
        buffer.withUnsafeBytes { (srcPointer: UnsafeRawBufferPointer) in
            pointer!.copyMemory(from: srcPointer.baseAddress!, byteCount: buffer.count)
        }
        return mtlBuffer
    }
    
    public static func faceUvBuffer(device:MTLDevice)->MTLBuffer?{
        if let buffer = try? Data(contentsOf: getFileUrl(name: "FLX_mesh_uv")){
            vtxBufferOfset = buffer.count
            let keyIdx = 50
            let startIdx = keyIdx*4*2;
            let keyUV = buffer.subdata(in: startIdx..<startIdx+8).toFloatArray()
            keyUv.x = keyUV[0]
            keyUv.y = keyUV[1]
            return makeMTLBuffer(device: device, buffer: buffer)
        }
        return nil
    }
    public static func faceIndexBuffer(device:MTLDevice)->MTLBuffer?{
        if let buffer = try? Data(contentsOf: getFileUrl(name: "FLX_mesh_idx")){
            indexCount = buffer.count/2
            return makeMTLBuffer(device: device, buffer: buffer)
        }
        return nil
    }
    public static func faceSpeachBshpBuffer(device:MTLDevice)->(MTLBuffer?,[Float]){
        if let buffer = try? Data(contentsOf: getFileUrl(name: "FLX_speech_bsh")){
            let buffer1 = buffer.subdata(in: 8..<buffer.count)
            let keyIdx:Int = 50
            var bshKeyPoints:[Float] = []
            for i in 0..<5{
                let startIdx = keyIdx*5*2*4 + i*2*4 + 4
                let keyY = buffer1.subdata(in: startIdx..<startIdx+4).toFloatArray()[0]
                bshKeyPoints.append(keyY)
            }
            
            return (makeMTLBuffer(device: device, buffer: buffer1),bshKeyPoints)
        }
        return (nil,[])
    }
    
    public static func faceEyebrowBshBuffer(device:MTLDevice)->MTLBuffer?{
        if let buffer = try? Data(contentsOf: getFileUrl(name: "FLX_bkg_anim_blendshapes")){
            return makeMTLBuffer(device: device, buffer: buffer)
        }
        return nil
    }
    public static func getBlinkPattern()->[Float]{
        if let buffer = try? Data(contentsOf: getFileUrl(name: "FLX_blink_pattern")){
            let count = buffer.count / MemoryLayout<Float>.size
            let animPattern =  buffer.withUnsafeBytes {pointer in
                [Float](UnsafeBufferPointer(start: pointer.baseAddress!.assumingMemoryBound(to: Float.self), count: count))
            }
            return animPattern
        }
        return [0]
    }
    public static func getMouthLineMask(device:MTLDevice)->MTLTexture  {
        guard let buffer = try? Data(contentsOf: getFileUrl(name: "FLX_mouth_line_mask"))else {
           fatalError("FLX_INJECT can not read and load mouth line mask")
        }
        let textureLoader = MTKTextureLoader(device: device)
        return try! textureLoader.newTexture(data: buffer)
        
//        return MTLTexture.from(data: <#T##Data#>, device: device)
    }
    
    public static func getAnimation()->[[Float]]{
        if let buffer = try? Data(contentsOf: getFileUrl(name: "FLX_neu")){
            let count = buffer.count / MemoryLayout<Float>.size
            let animPattern =  buffer.withUnsafeBytes {pointer in
                    [Float](UnsafeBufferPointer(start: pointer.baseAddress!.assumingMemoryBound(to: Float.self), count: count))
                }
//            print("FLX_INJECT pattern size \(animPattern.count) \(buffer.count)")
            var cntr = 0
            var ret:[[Float]] = []
            for _ in 0..<animPattern.count/10{
                var arr = [Float]()
                
                for _ in 0..<10{
                    arr.append(animPattern[cntr])
                    cntr+=1
                }
                ret.append(arr)
            }
//            print("FLX_INJECT anim arr \(ret) ")
            return ret
        }else{
            fatalError("FLX_INJECT can not read animation file")
        }
    }
}
