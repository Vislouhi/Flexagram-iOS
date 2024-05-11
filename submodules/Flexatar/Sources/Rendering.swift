//
//  Rendering.swift
//  Flexatar
//
//  Created by Matey Vislouh on 21.04.2024.
//

import Foundation
import AVFoundation
import UIKit
import SceneKit
import MetalKit


public class RenderEngine{
    private let device:MTLDevice
    private let renderPassDescriptor:MTLRenderPassDescriptor
    private let pipelineState: MTLRenderPipelineState
    private let mouthPipelineState: MTLRenderPipelineState
    private var faceUvBuffer:MTLBuffer!
    private var faceIdxBuffer:MTLBuffer!
    private var speachBshpBuffer:MTLBuffer!
    private var eyebrowBshpBuffer:MTLBuffer!
    private var flexatarPackage:UnpackFlexatarFile?
    private var newFlexatarPackage:UnpackFlexatarFile?
    private var counter:Int32 = 0
    private var veiwModelBuffer:MTLBuffer
    private var mouthLineMask:MTLTexture!
    private var screenRatio:Float
    private var veiwModelMat:simd_float4x4
    private var speechBshKey:[Float]!
    private let loadQueue = DispatchQueue(label: "ResLoadQueue")
    private var staticResoureceLoaded = false
    
    public init(pixelBuffer:CVPixelBuffer){
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        self.screenRatio = Float(height) /  Float(width)
        self.device = device
        
        
        
        
        
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, self.device, nil, &textureCache)
        guard let textureCache = textureCache else {
            fatalError("Invalid pixel buffer or texture cache")
        }
        var metalTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, .bgra8Unorm, width, height, 0, &metalTexture)

        guard let inputTexture = metalTexture else {
            fatalError("Failed to create Metal texture from pixel buffer")
        }
        
        self.renderPassDescriptor = MTLRenderPassDescriptor()
        self.renderPassDescriptor.colorAttachments[0].texture = CVMetalTextureGetTexture(inputTexture)
        self.renderPassDescriptor.colorAttachments[0].loadAction = .clear
        self.renderPassDescriptor.colorAttachments[0].storeAction = .store
        self.renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        let mainBundle = Bundle(for: RenderEngine.self)
        guard let path = mainBundle.path(forResource: "FlexatarMetalSourcesBundle", ofType: "bundle") else {
            fatalError("FLX_INJECT flexatar metal source bundle not found")
           
        }
        guard let bundle = Bundle(path: path) else {
           
            fatalError("FLX_INJECT bundle at path not found")
        }
        
        guard let library = try? device.makeDefaultLibrary(bundle: bundle) else{
            fatalError("FLX_INJECT library can not be initialized")
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "clearVertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "clearFragment")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        
       
        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        else {
            fatalError("Failed to create Metal render pipeline state")
        }
        self.pipelineState=pipelineState
        
        
        let mouthPipelineDescriptor = MTLRenderPipelineDescriptor()
        mouthPipelineDescriptor.vertexFunction = library.makeFunction(name: "mouthVertex")
        mouthPipelineDescriptor.fragmentFunction = library.makeFunction(name: "mouhtFragment")
        mouthPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        mouthPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        mouthPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        mouthPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        mouthPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        mouthPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        mouthPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        mouthPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        
       
        guard let mouthPipelineState = try? device.makeRenderPipelineState(descriptor: mouthPipelineDescriptor)
        else {
            fatalError("Failed to create Metal render pipeline state")
        }
        self.mouthPipelineState = mouthPipelineState
        
        veiwModelBuffer = device.makeBuffer(length: MemoryLayout<simd_float4x4>.size, options: [])!
        
        let sMat = GLKMatrix4MakeScale(1, -1, 1)
        let lookMat = GLKMatrix4MakeLookAt(0,0,2.5,0,0,0,0,1,0)
        veiwModelMat = lookMat.asSimd()*sMat.asSimd()
        veiwModelBuffer.loadFromStruct(veiwModelMat)
        
        self.loadQueue.async {[weak self] in
            if let self = self {
                self.faceUvBuffer = MetalResProviderFlx.faceUvBuffer(device: self.device)!
                self.faceIdxBuffer = MetalResProviderFlx.faceIndexBuffer(device: self.device)!
                let (speechBuffer,speechBshKey) = MetalResProviderFlx.faceSpeachBshpBuffer(device: self.device)
                self.speachBshpBuffer = speechBuffer!
                self.speechBshKey = speechBshKey
                self.eyebrowBshpBuffer = MetalResProviderFlx.faceEyebrowBshBuffer(device: self.device)!
                self.mouthLineMask = MetalResProviderFlx.getMouthLineMask(device: self.device)
                self.staticResoureceLoaded = true
            }
        }
      
    }
    public func loadFlexatar(){
        if let flxFileUrl = Bundle.main.path(forResource: "x00_char1t", ofType: "flx"){
            let flexatarPackage = UnpackFlexatarFile(path: flxFileUrl)
            flexatarPackage.prepareMetalRes(device: self.device)
            self.flexatarPackage = flexatarPackage
 //            let metaData = MetaDataFlexatar(withPreviewImage: true,atPath: flxFileUrl)
 //            print("FLX_INJECT meatadata name:\(metaData.flxInfo!.name)")
         }else{
             print("FLX_INJECT can not find flexatar file")
         }
    }
    public func loadFlexatar(path:String){
        self.loadQueue.async {[weak self] in
            if let self = self{
                let flexatarPackage = UnpackFlexatarFile(path: path)
                flexatarPackage.prepareMetalRes(device: self.device)
                self.newFlexatarPackage = flexatarPackage
            }
        }
    }
    
    public func draw(){
        if (!self.staticResoureceLoaded) {return}
        if let newFlxPack = self.newFlexatarPackage{
            self.flexatarPackage = newFlxPack
            self.newFlexatarPackage = nil
        }
            
        guard let flxPack = self.flexatarPackage else {return}
        
        let anim = AnimatorFlx.sharedInstance.getNext()
        let bshpCtrl = flxPack.calcBshpCtrl(rx: anim.rx, ry: anim.ry)
        var zrotMatrix = GLKMatrix4MakeZRotation(anim.rz).asSimd()
        let keyVtxList = flxPack.calcMouthKeyPoints(interUnit: bshpCtrl,viewModelMat: veiwModelMat,zRotMat: zrotMatrix,tx: anim.tx,ty:anim.ty,sc:anim.sc,screenRatio: screenRatio,speechBshKey:self.speechBshKey)
        let mouthPivots = flxPack.mouth.calcMouthPivots(idx: bshpCtrl.0, weights: bshpCtrl.1)
        let opFactor:[Float] = [0.03 + (-SoundProcessing.speachAnimVector[2] + SoundProcessing.speachAnimVector[3])*0.5]
//        print("FLX_INJECT mouthPivots \(mouthPivots)")
//        print("FLX_INJECT anim \(anim)")
        let commandQueue = self.device.makeCommandQueue()
        
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else {
            fatalError("Failed to create Metal command buffer")
        }

        // Create a Metal render command encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            fatalError("Failed to create Metal render command encoder")
        }
        self.drawMouth(renderEncoder: renderEncoder, flxPack: flxPack, idx: bshpCtrl.0, weight: bshpCtrl.1, pivot: mouthPivots, keyVtxList:keyVtxList,zrotMatrix: zrotMatrix)

        // Set the render pipeline state
        renderEncoder.setRenderPipelineState(pipelineState)
       
//        var clearQuads: [SIMD2<Float>] = []
//        let layerRect = CGRect(x: 0.1, y: 0.1, width: 0.1, height: 0.1)
//        let quadVertices: [SIMD2<Float>] = [
//            SIMD2<Float>(Float(layerRect.minX), Float(layerRect.minY)),
//            SIMD2<Float>(Float(layerRect.maxX), Float(layerRect.minY)),
//            SIMD2<Float>(Float(layerRect.minX), Float(layerRect.maxY)),
//            SIMD2<Float>(Float(layerRect.maxX), Float(layerRect.minY)),
//            SIMD2<Float>(Float(layerRect.minX), Float(layerRect.maxY)),
//            SIMD2<Float>(Float(layerRect.maxX), Float(layerRect.maxY))
//        ].map { v in
//            var v = v
//            v.y = -1.0 + v.y * 2.0
//            v.x = -1.0 + v.x * 2.0
//            return v
//        }
//        clearQuads.append(contentsOf: quadVertices)
        
//        renderEncoder.setVertexBytes(clearQuads, length: 4 * clearQuads.count * 2, index: 0)
        renderEncoder.setVertexBuffer(faceUvBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(flxPack.mandalaBlendshapes, offset: 0, index: 1)
        
        renderEncoder.setVertexBytes(bshpCtrl.0, length: 4 * 4, index: 2)
//        var textureWeight = SIMD4<Float>(1, 0, 0, 0)
        renderEncoder.setVertexBytes(bshpCtrl.1, length: 4 * 4, index: 3)
        
        renderEncoder.setVertexBuffer(self.speachBshpBuffer, offset: 0, index: 4)
        
        var speachWeight1 = SIMD4<Float>(SoundProcessing.speachAnimVector[0], SoundProcessing.speachAnimVector[1], SoundProcessing.speachAnimVector[2], SoundProcessing.speachAnimVector[3])
        renderEncoder.setVertexBytes(&speachWeight1, length: 4 * 4, index: 5)
        var speachWeight2 = SIMD4<Float>(SoundProcessing.speachAnimVector[4], anim.tx, anim.ty, anim.sc)
        renderEncoder.setVertexBytes(&speachWeight2, length: 4 * 4, index: 6)
        
        renderEncoder.setVertexBuffer(self.veiwModelBuffer, offset: 0, index: 7)
        var extraRotMatrix = bshpCtrl.2
        renderEncoder.setVertexBytes(&extraRotMatrix, length: 16 * 4, index: 8)
        
        renderEncoder.setVertexBuffer(self.eyebrowBshpBuffer, offset: 0, index: 9)
        
        var params = SIMD4<Float>(anim.eb, screenRatio, anim.bl, 0)
        renderEncoder.setVertexBytes(&params, length: 4 * 4 , index: 10)
//        print("FLX_INJECT rotz \(anim.rz)")
        
        renderEncoder.setVertexBytes(&zrotMatrix, length: 16 * 4 , index: 11)
        
        renderEncoder.setVertexBuffer(flxPack.blinkBlendshape, offset: 0, index: 12)
        
        

        renderEncoder.setFragmentBytes(bshpCtrl.0, length: 4 * 4, index: 0)

        renderEncoder.setFragmentBytes(bshpCtrl.1, length: 4 * 4, index: 2)
        renderEncoder.setFragmentBytes(opFactor, length: 1 * 4, index: 4)

        renderEncoder.setFragmentTexture(flxPack.faceTexture, index: 1)
        renderEncoder.setFragmentTexture(mouthLineMask, index: 3)
        
        
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: MetalResProviderFlx.indexCount, indexType: .uint16, indexBuffer: faceIdxBuffer, indexBufferOffset: 0, instanceCount: 1)

        
      

        // End encoding and commit the command buffer
        renderEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
    }
    private func drawMouth(renderEncoder: MTLRenderCommandEncoder,flxPack:UnpackFlexatarFile,idx:[Int32],weight:[Float],pivot:(SIMD2<Float>,SIMD2<Float>,Float),keyVtxList:[SIMD4<Float>],zrotMatrix: simd_float4x4){
        renderEncoder.setRenderPipelineState(mouthPipelineState)
        
        renderEncoder.setVertexBuffer(flxPack.mouth.uvBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(flxPack.mouth.mandalaBlendshapes, offset: 0, index: 1)
        renderEncoder.setVertexBytes(idx, length: 4 * 4, index: 2)

        renderEncoder.setVertexBytes(weight, length: 4 * 4, index: 3)
        var pivot1 = pivot.1
        renderEncoder.setVertexBytes(&pivot1, length: 2 * 4, index: 4)
//        var position1 = SIMD2<Float>(0,0)
        var position1 = SIMD2<Float>(keyVtxList[3].x,keyVtxList[2].y)
//        print("FLX_INJECT position \(position1)")
        renderEncoder.setVertexBytes(&position1, length: 2 * 4, index: 6)
        let mSacle:[Float] = [(keyVtxList[5].x - keyVtxList[4].x)/pivot.2]
        renderEncoder.setVertexBytes(mSacle, length: 1 * 4, index: 5)
        var zrotMatrix1 = zrotMatrix
        renderEncoder.setVertexBytes(&zrotMatrix1, length: 16 * 4 , index: 7)
        
        renderEncoder.setFragmentBytes(idx, length: 4 * 4, index: 0)

       
        renderEncoder.setFragmentBytes(weight, length: 4 * 4, index: 2)
        
        renderEncoder.setFragmentBytes( flxPack.mouth.teethGap, length: 2 * 4, index: 3)
        var isTop:[Int32] = [0]
        renderEncoder.setFragmentBytes( isTop, length: 1 * 4, index: 4)
        

        renderEncoder.setFragmentTexture(flxPack.mouth.texture, index: 1)
        
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: flxPack.mouth.idxCount, indexType: .uint16, indexBuffer: flxPack.mouth.idxBuffer!, indexBufferOffset: 0, instanceCount: 1)
        
        var pivot2 = pivot.0
        renderEncoder.setVertexBytes(&pivot2, length: 2 * 4, index: 4)
        var position2 = SIMD2<Float>(keyVtxList[1].x,keyVtxList[0].y)

        renderEncoder.setVertexBytes(&position2, length: 2 * 4, index: 6)
        
        isTop = [1]
        renderEncoder.setFragmentBytes( isTop, length: 1 * 4, index: 4)
        
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: flxPack.mouth!.idxCount, indexType: .uint16, indexBuffer: flxPack.mouth!.idxBuffer!, indexBufferOffset: 0, instanceCount: 1)
        
    }
    
    static func mkTextureArray(device:MTLDevice,images:[UIImage]) -> MTLTexture?{

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(images[0].size.width),
            height: Int(images[0].size.height),
            mipmapped: false
            
        )
        textureDescriptor.usage = .shaderRead
        textureDescriptor.arrayLength = images.count
        textureDescriptor.textureType = .type2DArray
        let texture = device.makeTexture(descriptor: textureDescriptor)!
        
        for i in 0..<images.count{
            guard let cgImage = images[i].cgImage else {
                fatalError("FLX_INJECT Failed to get CGImage from UIImage")
            }

            let height = cgImage.height
            let width = cgImage.width

            let bytesPerPixel = 4
            let bytesPerRow = bytesPerPixel * width
            let bitsPerComponent = 8
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

            var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

            guard let context = CGContext(data: &pixelData, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
                return nil
            }

            context.draw(cgImage, in: CGRect(origin: .zero, size: CGSize(width: width, height: height)))

            let region = MTLRegionMake2D(0, 0, width, height)
            

            
            texture.replace(region: region, mipmapLevel: 0, slice: i, withBytes: pixelData, bytesPerRow: width * 4, bytesPerImage: 0)
         
        }
        
        return texture
        
    }
    
}

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
    
    public static var renderEngine:RenderEngine?
    
    public static func drawPixelBuffer() ->  CVPixelBuffer?{
        let width = Int(640)
        let height = Int(480)

        if pixelBuffer == nil {
            let pixelBufferAttributes: [String:AnyObject] = [String(kCVPixelBufferPixelFormatTypeKey) : NSNumber(integerLiteral: Int(kCVPixelFormatType_32BGRA)),
                                                                         String(kCVPixelBufferWidthKey) : NSNumber(value: width),
                                                                         String(kCVPixelBufferHeightKey) : NSNumber(value: height),
                                                                         String(kCVPixelBufferMetalCompatibilityKey) : NSNumber(booleanLiteral: true),
                                                                         String(kCVPixelBufferIOSurfacePropertiesKey) : [:] as AnyObject ]
            
            let status = CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, pixelBufferAttributes as CFDictionary, &pixelBuffer)
            
            guard status == kCVReturnSuccess else {
                return nil
            }
            renderEngine = RenderEngine(pixelBuffer: pixelBuffer!)
//            if let flxFileUrl = Bundle.main.path(forResource: "x00_char1t", ofType: "flx"){
            renderEngine?.loadFlexatar(path: ChooserFlx.photoFlexatarChooser.path1)
//            }
        }
      
        if let buffer = pixelBuffer {
            renderEngine?.draw()
            // Lock the base address of the pixel buffer for writing
            /*
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
            context.setFillColor(UIColor.green.cgColor)
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
            */
            
            return buffer
        }
        return nil
    }
    
}


extension SCNMatrix4{
    
    static func *(lhs: SCNMatrix4, rhs: SCNMatrix4) -> SCNMatrix4 {
        return SCNMatrix4Mult(rhs,lhs)
    }
}

extension GLKMatrix4{
    
    static func *(lhs: GLKMatrix4, rhs: GLKMatrix4) -> GLKMatrix4 {
        return GLKMatrix4Multiply(lhs,rhs)
    }
    func asSimd() -> simd_float4x4{
        let matrix = self
        return simd_float4x4([
            simd_float4(matrix.m00, matrix.m01, matrix.m02, matrix.m03),
            simd_float4(matrix.m10, matrix.m11, matrix.m12, matrix.m13),
            simd_float4(matrix.m20, matrix.m21, matrix.m22, matrix.m23),
            simd_float4(matrix.m30, matrix.m31, matrix.m32, matrix.m33),
        ])
        
    }
}

extension MTLBuffer {
    
    func loadFromStruct<T>(_ s:T){
        _ = withUnsafeBytes(of:s){(pointer ) in
            memcpy(self.contents(),  UnsafeRawPointer(pointer.baseAddress!), self.length)
        }
    }
}

extension MTLTexture? {
    public static func from( data:Data,device:MTLDevice) -> MTLTexture{
        let textureLoader = MTKTextureLoader(device: device)
        return try! textureLoader.newTexture(data: data)
       
    }
}
