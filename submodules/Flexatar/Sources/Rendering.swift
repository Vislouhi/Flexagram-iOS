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


public class RenderEngine:FlexatarEngine{
    private let device:MTLDevice
    private let renderPassDescriptor:MTLRenderPassDescriptor
//    private let pipelineState: MTLRenderPipelineState
//    private let effectPipelineState: MTLRenderPipelineState
//    private let mouthPipelineState: MTLRenderPipelineState
//    private let videoFlxPipelineState: MTLRenderPipelineState
//    private var faceUvBuffer:MTLBuffer!
//    private var faceIdxBuffer:MTLBuffer!
//    private var speachBshpBuffer:MTLBuffer!
//    private var eyebrowBshpBuffer:MTLBuffer!
//    private var flexatarPackage:UnpackFlexatarFile?
//    private var newFlexatarPackage:UnpackFlexatarFile?
    
//    private var flexatarPackage2:UnpackFlexatarFile?
//    private var newFlexatarPackage2:UnpackFlexatarFile?
    
    private var counter:Int32 = 0
//    private var veiwModelBuffer:MTLBuffer
//    private var mouthLineMask:MTLTexture!
    private var screenRatio:Float
//    private var veiwModelMat:simd_float4x4
//    private var speechBshKey:[Float]!
    private let loadQueue = DispatchQueue(label: "ResLoadQueue")
    private var staticResoureceLoaded = false
 
    
    public static func getShaderLib(device:MTLDevice)->MTLLibrary{
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
        return library
    }
    public class PipelineStates{
        let head:MTLRenderPipelineState
        let effect:MTLRenderPipelineState
        let mouth:MTLRenderPipelineState
        let video:MTLRenderPipelineState
        public init(device:MTLDevice){
            let library = RenderEngine.getShaderLib(device: device)
            self.head = RenderEngine.createPipelineState(device:device,vertex: library.makeFunction(name: "clearVertex")!, fragment: library.makeFunction(name: "clearFragment")!)
            
            self.effect = RenderEngine.createPipelineState(device:device,vertex: library.makeFunction(name: "headEffectsVertex")!, fragment: library.makeFunction(name: "headEffectsFragment")!)
            self.mouth = RenderEngine.createPipelineState(device:device,vertex: library.makeFunction(name: "mouthVertex")!, fragment: library.makeFunction(name: "mouhtFragment")!)
            
            self.video = RenderEngine.createPipelineState(device:device,vertex: library.makeFunction(name: "videoFlxVertex")!, fragment: library.makeFunction(name: "videoFlxFragment")!)
        }
    }
    
    public class StaticResources{
        let veiwModelBuffer:MTLBuffer
        let faceUvBuffer:MTLBuffer
        let faceIdxBuffer:MTLBuffer
        let speachBshpBuffer:MTLBuffer
        let eyebrowBshpBuffer:MTLBuffer
        let mouthLineMask:MTLTexture
        let speechBshKey:[Float]
        let veiwModelMat: simd_float4x4
        public init(device:MTLDevice){
            self.veiwModelBuffer = device.makeBuffer(length: MemoryLayout<simd_float4x4>.size, options: [])!
            
            let sMat = GLKMatrix4MakeScale(1, -1, 1)
            let lookMat = GLKMatrix4MakeLookAt(0,0,2.5,0,0,0,0,1,0)
            self.veiwModelMat = lookMat.asSimd()*sMat.asSimd()
            self.veiwModelBuffer.loadFromStruct(veiwModelMat)
            
            self.faceUvBuffer = MetalResProviderFlx.faceUvBuffer(device: device)!
            self.faceIdxBuffer = MetalResProviderFlx.faceIndexBuffer(device: device)!
            let (speechBuffer,speechBshKey) = MetalResProviderFlx.faceSpeachBshpBuffer(device: device)
            self.speachBshpBuffer = speechBuffer!
            self.speechBshKey = speechBshKey
            self.eyebrowBshpBuffer = MetalResProviderFlx.faceEyebrowBshBuffer(device: device)!
            self.mouthLineMask = MetalResProviderFlx.getMouthLineMask(device: device)
        }
    }
    public static var flexatarDidLoad: (()->())?
    public class FlexatarLoader{
        public var previousPath = ""
        public var previousEffectPath:String?
        public var flexatarPackage:UnpackFlexatarFile?
        public var flexatarPackage2:UnpackFlexatarFile?
        public var newFlexatarPackage2:UnpackFlexatarFile?
        public var newFlexatarPackage:UnpackFlexatarFile?
        private var device:MTLDevice
//        private var newFlexatarPackage2:UnpackFlexatarFile?
        public init(device: MTLDevice){
            self.device=device
        }
        public func loadFlexatar(path:String,effectPath:String? = nil){
           
           
            if (effectPath == self.previousPath){
                if let currentPackage = self.flexatarPackage{
                    self.newFlexatarPackage2 = currentPackage
                }
            }else if let previousEffectPath = self.previousEffectPath, let ePath = effectPath{
                if (ePath == previousEffectPath){
                    self.newFlexatarPackage2 = nil
                }else{
                    let flexatarPackage2 = UnpackFlexatarFile(path: ePath)
                    flexatarPackage2.prepareMetalRes(device: device)
                    self.newFlexatarPackage2 = flexatarPackage2
                }
            }else{
                if let ePath = effectPath{
                    let flexatarPackage2 = UnpackFlexatarFile(path: ePath)
                    flexatarPackage2.prepareMetalRes(device: device)
                    self.newFlexatarPackage2 = flexatarPackage2
                }
            }
            
            self.previousPath = path
            self.previousEffectPath = effectPath
            
                
            let flexatarPackage = UnpackFlexatarFile(path: path)
            flexatarPackage.prepareMetalRes(device: device)
            self.newFlexatarPackage = flexatarPackage
            flexatarDidLoad?()

        }
        public func swithDrawing(photo:@escaping(UnpackFlexatarFile,UnpackFlexatarFile?)->(),video:@escaping(UnpackFlexatarFile)->()){
            
            if let newFlxPack = self.newFlexatarPackage{
                self.flexatarPackage = newFlxPack
                self.newFlexatarPackage = nil
            }
            
            if let newFlxPack2 = self.newFlexatarPackage2{
                self.flexatarPackage2 = newFlxPack2
                self.newFlexatarPackage2 = nil
            }
                
            guard let flxPack = self.flexatarPackage else {return}
            if flxPack.flxType == .Photo {
                photo(flxPack,self.flexatarPackage2)
            }else{
    //            TODO: draw video flexatar
                video(flxPack)
            }
        }
        public func destroy(){
            flexatarPackage=nil
            flexatarPackage2=nil
            newFlexatarPackage2=nil
            newFlexatarPackage=nil
        }
        
    }
    
    private let pipelineSates:PipelineStates
    private var staticResources:StaticResources!
    private let flexatarLoader:FlexatarLoader
    public var effectCtrl:EffectCtrlProvider
    public static var staticResDidLoad:(()->())?
    
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
        

        self.pipelineSates = PipelineStates(device: device)
        self.flexatarLoader = FlexatarLoader(device: device)
        self.effectCtrl = EffectCtrlProvider()
        
        
//        veiwModelBuffer = device.makeBuffer(length: MemoryLayout<simd_float4x4>.size, options: [])!
        
//        let sMat = GLKMatrix4MakeScale(1, -1, 1)
//        let lookMat = GLKMatrix4MakeLookAt(0,0,2.5,0,0,0,0,1,0)
//        veiwModelMat = lookMat.asSimd()*sMat.asSimd()
//        veiwModelBuffer.loadFromStruct(veiwModelMat)
        
        self.loadQueue.async {[weak self] in
            if let self = self {
                self.staticResources = StaticResources(device: device)
                Self.staticResDidLoad?()
//                self.faceUvBuffer = MetalResProviderFlx.faceUvBuffer(device: self.device)!
//                self.faceIdxBuffer = MetalResProviderFlx.faceIndexBuffer(device: self.device)!
//                let (speechBuffer,speechBshKey) = MetalResProviderFlx.faceSpeachBshpBuffer(device: self.device)
//                self.speachBshpBuffer = speechBuffer!
//                self.speechBshKey = speechBshKey
//                self.eyebrowBshpBuffer = MetalResProviderFlx.faceEyebrowBshBuffer(device: self.device)!
//                self.mouthLineMask = MetalResProviderFlx.getMouthLineMask(device: self.device)
                self.staticResoureceLoaded = true
            }
        }
      
    }
    
    public static func createPipelineState(device:MTLDevice,vertex:MTLFunction,fragment:MTLFunction) -> MTLRenderPipelineState{
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertex
        pipelineDescriptor.fragmentFunction = fragment
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
        return pipelineState
    }
    
    public func loadFlexatar(){
        if let flxFileUrl = Bundle.main.path(forResource: "x00_char1t", ofType: "flx"){
            let flexatarPackage = UnpackFlexatarFile(path: flxFileUrl)
            flexatarPackage.prepareMetalRes(device: self.device)
//            self.flexatarPackage = flexatarPackage
 //            let metaData = MetaDataFlexatar(withPreviewImage: true,atPath: flxFileUrl)
 //            print("FLX_INJECT meatadata name:\(metaData.flxInfo!.name)")
         }else{
             print("FLX_INJECT can not find flexatar file")
         }
    }
//    private var previousPath = ""
//    private var previousEffectPath:String?
    public func loadFlexatar(path:String,effectPath:String? = nil){
        self.loadQueue.async {[weak self] in
            guard let self = self else{return}
            self.flexatarLoader.loadFlexatar(path: path,effectPath:effectPath)
//            if (effectPath == self.previousPath){
//                if let currentPackage = self.flexatarPackage{
//                    self.newFlexatarPackage2 = currentPackage
//                }
//            }else if let previousEffectPath = self.previousEffectPath, let ePath = effectPath{
//                if (ePath == previousEffectPath){
//                    self.newFlexatarPackage2 = nil
//                }else{
//                    let flexatarPackage2 = UnpackFlexatarFile(path: ePath)
//                    flexatarPackage2.prepareMetalRes(device: self.device)
//                    self.newFlexatarPackage2 = flexatarPackage2
//                }
//            }else{
//                if let ePath = effectPath{
//                    let flexatarPackage2 = UnpackFlexatarFile(path: ePath)
//                    flexatarPackage2.prepareMetalRes(device: self.device)
//                    self.newFlexatarPackage2 = flexatarPackage2
//                }
//            }
//            
//            self.previousPath = path
//            self.previousEffectPath = effectPath
//            
//                
//            let flexatarPackage = UnpackFlexatarFile(path: path)
//            flexatarPackage.prepareMetalRes(device: self.device)
//            self.newFlexatarPackage = flexatarPackage

        }
    }
   
    
    public func draw(speechAnim:[Float]?=nil,isRotated:Bool=true){
        if (!self.staticResoureceLoaded) {return}
        self.flexatarLoader.swithDrawing (photo:{[weak self] flxPack1, flxPack2 in
            self?.drawPhoto(flxPack1,flxPack2,speechAnim:speechAnim,isRotated:isRotated)
        }, video: {[weak self] flxPack in
            self?.drawVideo(flxPack,isRotated:isRotated,speechAnim:speechAnim)
        })

//        if let newFlxPack = self.flexatarLoader.newFlexatarPackage{
//            self.flexatarLoader.flexatarPackage = newFlxPack
//            self.flexatarLoader.newFlexatarPackage = nil
//        }
//        
//        if let newFlxPack2 = self.flexatarLoader.newFlexatarPackage2{
//            self.flexatarLoader.flexatarPackage2 = newFlxPack2
//            self.flexatarLoader.newFlexatarPackage2 = nil
//        }
//            
//        guard let flxPack = self.flexatarLoader.flexatarPackage else {return}
//        if flxPack.flxType == .Photo {
//            drawPhoto(flxPack,self.flexatarLoader.flexatarPackage2)
//        }else{
//            TODO: draw video flexatar
//            drawVideo(flxPack)
//        }
        
        
    }

    private static func drawMouth(pipelineStates:PipelineStates, renderEncoder: MTLRenderCommandEncoder,flxPack:UnpackFlexatarFile,idx:[Int32],weight:[Float],pivot:(SIMD2<Float>,SIMD2<Float>,Float),keyVtxList:[SIMD4<Float>],zrotMatrix: simd_float4x4,alpha:Float = 1,isRotated:Bool){
        renderEncoder.setRenderPipelineState(pipelineStates.mouth)
        
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
        
        let rotated:[Int32] = [isRotated ? 1 : 0]
        renderEncoder.setVertexBytes(rotated, length:  4 , index: 8)
        
        renderEncoder.setFragmentBytes(idx, length: 4 * 4, index: 0)

       
        renderEncoder.setFragmentBytes(weight, length: 4 * 4, index: 2)
        
        renderEncoder.setFragmentBytes( flxPack.mouth.teethGap, length: 2 * 4, index: 3)
        var isTop:[Int32] = [0]
        renderEncoder.setFragmentBytes( isTop, length: 1 * 4, index: 4)
        var alpha1:[Float] = [alpha]
        renderEncoder.setFragmentBytes( alpha1, length: 1 * 4, index: 5)
        

        renderEncoder.setFragmentTexture(flxPack.mouth.texture, index: 1)
        
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: flxPack.mouth.idxCount, indexType: .uint16, indexBuffer: flxPack.mouth.idxBuffer!, indexBufferOffset: 0, instanceCount: 1)
        
        var pivot2 = pivot.0
        renderEncoder.setVertexBytes(&pivot2, length: 2 * 4, index: 4)
        var position2 = SIMD2<Float>(keyVtxList[1].x,keyVtxList[0].y)

        renderEncoder.setVertexBytes(&position2, length: 2 * 4, index: 6)
        
        isTop = [1]
        renderEncoder.setFragmentBytes( isTop, length: 1 * 4, index: 4)
        alpha1 = [alpha]
        renderEncoder.setFragmentBytes( alpha1, length: 1 * 4, index: 5)
        
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: flxPack.mouth!.idxCount, indexType: .uint16, indexBuffer: flxPack.mouth!.idxBuffer!, indexBufferOffset: 0, instanceCount: 1)
        
    }
    private func drawVideo(_ flxPack:UnpackFlexatarFile,isRotated:Bool=true,speechAnim:[Float]?=nil){
        var speachVector = SoundProcessing.speachAnimVector
        if let spAnim = speechAnim{
            speachVector = spAnim
        }
        var ratio:Float = 1
        if let vRatio = flxPack.videoRatio{
            ratio = self.screenRatio*vRatio
        }
        print("FLX_INJECT vratio \(ratio)")
        Self.drawVideoFlx(flxPack, device: self.device, pipelineStates: pipelineSates, renderPassDescriptor: renderPassDescriptor, staticResources: staticResources, isRotated: isRotated,speechVector: speachVector, screenRatio: ratio)
    }
    public static func drawVideoFlx(_ flxPack:UnpackFlexatarFile, device:MTLDevice,pipelineStates:PipelineStates,renderPassDescriptor: MTLRenderPassDescriptor,staticResources:StaticResources,isRotated:Bool=false,drawable:CAMetalDrawable?=nil,speechVector:[Float],screenRatio:Float=1){
        let commandQueue = device.makeCommandQueue()
        
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else {
            fatalError("Failed to create Metal command buffer")
        }

        // Create a Metal render command encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            fatalError("Failed to create Metal render command encoder")
        }
        let (texIdx, videoTexture) = flxPack.getNextVideoTexture()
        let (rx,ry,rz) = flxPack.getVideoHeadPosition(idx:texIdx)
        let bshpCtrl = flxPack.calcBshpCtrl(rx: rx, ry: ry)
        let mouthPivots = flxPack.mouth.calcMouthPivots(idx: bshpCtrl.0, weights: bshpCtrl.1)
        let zrotMatrix = GLKMatrix4MakeZRotation(-rz*0.83).asSimd()
        let opFactor:[Float] = [0.03 + (-speechVector[2] + speechVector[3])*0.5]
        
        let keyVtxList = flxPack.calcMouthKeyPointsVideo(idx:texIdx,speechBshKey:staticResources.speechBshKey,screenRatio:screenRatio)
        Self.drawMouth(pipelineStates: pipelineStates, renderEncoder: renderEncoder, flxPack: flxPack, idx: bshpCtrl.0, weight: bshpCtrl.1, pivot: mouthPivots, keyVtxList:keyVtxList,zrotMatrix: zrotMatrix,isRotated: isRotated)
        
        renderEncoder.setRenderPipelineState(pipelineStates.video)

       
        renderEncoder.setVertexBuffer(flxPack.videoMarkers, offset: MetalResProviderFlx.vtxBufferOfset * texIdx, index: 0)
        
        renderEncoder.setVertexBytes(&flxPack.videoOrientationMatrix, length: 16 * 4 , index: 1)
      
        renderEncoder.setVertexBuffer(staticResources.faceUvBuffer, offset: 0, index: 2)
        renderEncoder.setVertexBuffer(staticResources.speachBshpBuffer, offset: 0, index: 4)
        
        var speachWeight1 = SIMD4<Float>(speechVector[0], speechVector[1], speechVector[2],speechVector[3])
        renderEncoder.setVertexBytes(&speachWeight1, length: 4 * 4, index: 5)
        var speachWeight2 = SIMD4<Float>(speechVector[4], flxPack.getMouthScale(idx: texIdx),0, 0)
        renderEncoder.setVertexBytes(&speachWeight2, length: 4 * 4, index: 6)
        
        let rotated:[Int32] = [isRotated ? 1 : 0]
        renderEncoder.setVertexBytes(rotated, length:  4 , index: 7)
        let sRat:[Float] = [screenRatio]
        renderEncoder.setVertexBytes(sRat, length:  4 , index: 8)
        
       
        renderEncoder.setFragmentTexture(videoTexture, index: 0)
        renderEncoder.setFragmentTexture(staticResources.mouthLineMask, index: 1)
        
        renderEncoder.setFragmentBytes(opFactor, length: 1 * 4, index: 2)
//        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: clearQuads.count)
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: MetalResProviderFlx.indexCount, indexType: .uint16, indexBuffer: staticResources.faceIdxBuffer, indexBufferOffset: 0, instanceCount: 1)
        
//        self.drawMouth(renderEncoder: renderEncoder, flxPack: flxPack, idx: bshpCtrl.0, weight: bshpCtrl.1, pivot: mouthPivots, keyVtxList:keyVtxList,zrotMatrix: zrotMatrix)
        renderEncoder.endEncoding()
        if let drawable = drawable{
            commandBuffer.present(drawable)
        }
        commandBuffer.commit()
        if drawable == nil {
            commandBuffer.waitUntilCompleted()
        }
        
    }
    
    public class EffectCtrlProvider{
        public var effectIdx:Int = 0
        public var mixWeight:Float = 0.5
        private var dynamicMixWeight:Float = 0.0
        private var dynamicMixWeightDirection:Float = 1.0
        
        public func calcMixWeight() -> Float{
            
            if effectIdx == 2{
                dynamicMixWeight += dynamicMixWeightDirection * 0.005
                if dynamicMixWeight > 1{
                    dynamicMixWeightDirection = -1
                    dynamicMixWeight += dynamicMixWeightDirection * 0.005
                }
                if dynamicMixWeight < 0{
                    dynamicMixWeightDirection = 1
                    dynamicMixWeight += dynamicMixWeightDirection * 0.005
                }
                return dynamicMixWeight
            }
            if effectIdx == 3{
                dynamicMixWeight += dynamicMixWeightDirection * 0.005
                if dynamicMixWeight > 1{
                    
                    dynamicMixWeight = 0
                }
                return dynamicMixWeight
            }
            return mixWeight
        }
    }
    public static func drawPhotoFLx(_ flxPack:UnpackFlexatarFile,_ flxPack2:UnpackFlexatarFile?,pipelineStates:PipelineStates, device:MTLDevice, renderPassDescriptor: MTLRenderPassDescriptor,speechVector:[Float],mixWeight:Float, effectIdx:Int, screenRatio: Float, staticResources:StaticResources, isRotated:Bool=true, drawable:CAMetalDrawable?=nil){
        
        let isEffectMode = (flxPack2 != nil) && (effectIdx != 0)
        
        let currentMixWeight = mixWeight
                
        var mouhtMixWeight = currentMixWeight
        
        let isHybrid = effectIdx == 3
        if isEffectMode {
            mouhtMixWeight = isHybrid ? Self.calcWeightForMouthHybrid(mixWeight: currentMixWeight) : currentMixWeight
        }
        
        let anim = AnimatorFlx.sharedInstance.getNext()
        let bshpCtrl = flxPack.calcBshpCtrl(rx: anim.rx, ry: anim.ry)
        var zrotMatrix = GLKMatrix4MakeZRotation(anim.rz).asSimd()
        
        var keyVtxList = flxPack.calcMouthKeyPoints(interUnit: bshpCtrl,viewModelMat: staticResources.veiwModelMat,zRotMat: zrotMatrix,tx: anim.tx,ty:anim.ty,sc:anim.sc,screenRatio: screenRatio,speechBshKey:staticResources.speechBshKey)
        
        if isEffectMode {
            let keyVtxList2 = flxPack2!.calcMouthKeyPoints(interUnit: bshpCtrl,viewModelMat: staticResources.veiwModelMat,zRotMat: zrotMatrix,tx: anim.tx,ty:anim.ty,sc:anim.sc,screenRatio: screenRatio,speechBshKey:staticResources.speechBshKey)
            for i in 0..<keyVtxList.count{
                keyVtxList[i] = keyVtxList[i] * SIMD4<Float>(repeating: mouhtMixWeight) + keyVtxList2[i] * SIMD4<Float>(repeating: 1 - mouhtMixWeight)
            }
        }
        
        let mouthPivots = flxPack.mouth.calcMouthPivots(idx: bshpCtrl.0, weights: bshpCtrl.1)
            
        
        let opFactor:[Float] = [0.03 + (-speechVector[2] + speechVector[3])*0.5]
        
        
//        print("FLX_INJECT mouthPivots \(mouthPivots)")
//        print("FLX_INJECT anim \(anim)")
        let commandQueue = device.makeCommandQueue()
        
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else {
            fatalError("Failed to create Metal command buffer")
        }

        // Create a Metal render command encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            fatalError("Failed to create Metal render command encoder")
        }
        Self.drawMouth(pipelineStates:pipelineStates,renderEncoder: renderEncoder, flxPack: flxPack, idx: bshpCtrl.0, weight: bshpCtrl.1, pivot: mouthPivots, keyVtxList:keyVtxList,zrotMatrix: zrotMatrix,isRotated: isRotated)
        
        if isEffectMode {
            let mouthPivots2 = flxPack2!.mouth.calcMouthPivots(idx: bshpCtrl.0, weights: bshpCtrl.1)
            Self.drawMouth(pipelineStates:pipelineStates, renderEncoder: renderEncoder, flxPack: flxPack2!, idx: bshpCtrl.0, weight: bshpCtrl.1, pivot: mouthPivots2, keyVtxList:keyVtxList,zrotMatrix: zrotMatrix,alpha: 1 - mouhtMixWeight,isRotated: isRotated)
        }

        // Set the render pipeline state
        if isEffectMode{
            renderEncoder.setRenderPipelineState(pipelineStates.effect)
        }else{
            renderEncoder.setRenderPipelineState(pipelineStates.head)
        }
        
       

        renderEncoder.setVertexBuffer(staticResources.faceUvBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(flxPack.mandalaBlendshapes, offset: 0, index: 1)
        
        renderEncoder.setVertexBytes(bshpCtrl.0, length: 4 * 4, index: 2)
//        var textureWeight = SIMD4<Float>(1, 0, 0, 0)
        renderEncoder.setVertexBytes(bshpCtrl.1, length: 4 * 4, index: 3)
        
        renderEncoder.setVertexBuffer(staticResources.speachBshpBuffer, offset: 0, index: 4)
        
        
        var speachWeight1 = SIMD4<Float>(speechVector[0], speechVector[1], speechVector[2], speechVector[3])

        renderEncoder.setVertexBytes(&speachWeight1, length: 4 * 4, index: 5)
        var speachWeight2 = SIMD4<Float>(speechVector[4], anim.tx, anim.ty, anim.sc)
        renderEncoder.setVertexBytes(&speachWeight2, length: 4 * 4, index: 6)
        
        renderEncoder.setVertexBuffer(staticResources.veiwModelBuffer, offset: 0, index: 7)
        var extraRotMatrix = bshpCtrl.2
        renderEncoder.setVertexBytes(&extraRotMatrix, length: 16 * 4, index: 8)
        
        renderEncoder.setVertexBuffer(staticResources.eyebrowBshpBuffer, offset: 0, index: 9)
        
        var params = SIMD4<Float>(anim.eb, screenRatio, anim.bl, currentMixWeight)
        renderEncoder.setVertexBytes(&params, length: 4 * 4 , index: 10)
//        print("FLX_INJECT rotz \(anim.rz)")
        
        renderEncoder.setVertexBytes(&zrotMatrix, length: 16 * 4 , index: 11)
        
        renderEncoder.setVertexBuffer(flxPack.blinkBlendshape, offset: 0, index: 12)
       
        
        

        renderEncoder.setFragmentBytes(bshpCtrl.0, length: 4 * 4, index: 0)

        renderEncoder.setFragmentBytes(bshpCtrl.1, length: 4 * 4, index: 2)
        renderEncoder.setFragmentBytes(opFactor, length: 1 * 4, index: 4)

        renderEncoder.setFragmentTexture(flxPack.faceTexture, index: 1)
        renderEncoder.setFragmentTexture(staticResources.mouthLineMask, index: 3)
        
        let rotated:[Int32] = [isRotated ? 1 : 0]
        renderEncoder.setVertexBytes(rotated, length:  4 , index: isEffectMode ? 15 : 13)
        
        if isEffectMode {
            renderEncoder.setVertexBuffer(flxPack2!.mandalaBlendshapes, offset: 0, index: 13)
            let effectID:[Int32] = [isHybrid ? 1 : 0]
            renderEncoder.setVertexBytes(effectID, length: 1 * 4, index: 14)
            renderEncoder.setFragmentTexture(flxPack2!.faceTexture, index: 6)
            let mixWeight1:[Float] = [currentMixWeight]
            renderEncoder.setFragmentBytes(mixWeight1, length: 1 * 4, index: 5)
            
           
        }
        
        
        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: MetalResProviderFlx.indexCount, indexType: .uint16, indexBuffer: staticResources.faceIdxBuffer, indexBufferOffset: 0, instanceCount: 1)

        
      

        // End encoding and commit the command buffer
        renderEncoder.endEncoding()
        if let drawable = drawable{
            commandBuffer.present(drawable)
        }
        commandBuffer.commit()
        if drawable == nil {
            commandBuffer.waitUntilCompleted()
        }
    }
    private func drawPhoto(_ flxPack:UnpackFlexatarFile,_ flxPack2:UnpackFlexatarFile?, speechAnim:[Float]?=nil,isRotated:Bool=true){
        let currentMixWeight = self.effectCtrl.calcMixWeight()
        var speachVector = SoundProcessing.speachAnimVector
        if let spAnim = speechAnim{
            speachVector = spAnim
        }
        Self.drawPhotoFLx(flxPack, flxPack2, pipelineStates: self.pipelineSates, device: self.device, renderPassDescriptor: self.renderPassDescriptor, speechVector: speachVector, mixWeight: currentMixWeight, effectIdx: self.effectCtrl.effectIdx, screenRatio: self.screenRatio, staticResources: self.staticResources,isRotated: isRotated)
    }
    
    
    private static func calcWeightForMouthHybrid(mixWeight:Float) -> Float{
        let theta = mixWeight * 6.28
        let linePoint = SIMD3<Float>(sin(theta),cos(theta),1.0)
        var w = simd_dot(simd_cross(linePoint, MetalResProviderFlx.keyUv), SIMD3<Float>(0,0,1)) / 0.15
        w = simd_clamp(w, -1, 1)
        w += 1
        w /= 2.0
        return w
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
    private static func mixMouthPivots(_ pivots1: (SIMD2<Float>, SIMD2<Float>, Float),_ pivots2: (SIMD2<Float>, SIMD2<Float>, Float),weight:Float) -> (SIMD2<Float>, SIMD2<Float>, Float){
        let p1 = pivots1.0 * SIMD2<Float>(repeating: weight) + pivots2.0 * SIMD2<Float>(repeating: 1 - weight)
        let p2 = pivots1.1 * SIMD2<Float>(repeating: weight) + pivots2.1 * SIMD2<Float>(repeating: 1 - weight)
        let p3 = pivots1.2 * weight + pivots2.2 * (1 - weight)
        return (p1,p2,p3)
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
    public static func flexatarDrawTimer(peerId:Int64, onFrame:@escaping(CVPixelBuffer)->()){
       
        DispatchQueue.main.async{
            if let timer = frameTimer{
                if timer.isValid {
                    timer.invalidate()
                }
            }
            frameTimer = Timer.scheduledTimer(withTimeInterval: Double(1)/Double(30), repeats: true) { _ in

                if let pixelBuffer = FrameProvider.drawPixelBuffer(peerId:peerId){
                        onFrame(pixelBuffer)
                    }
      
            }
        }
    }
    
    public static var renderEngine:RenderEngine?
    public static func destroyEngineInstance(){
        
        renderEngine = nil
        pixelBuffer = nil
    }
    public static func drawPixelBuffer(peerId:Int64,width:Int=640,height:Int=480,tag:String="call",speechAnim:[Float]?=nil,isRotated:Bool=true) ->  CVPixelBuffer?{
       

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
            print("FLX_INJECT init render engine inst")
            renderEngine = RenderEngine(pixelBuffer: pixelBuffer!)
//            if let flxFileUrl = Bundle.main.path(forResource: "x00_char1t", ofType: "flx"){
            let chooser = ChooserFlx.inst(tag: tag, peerId: peerId)
            chooser.renderEngine = renderEngine
            
//            print("FLX_INJECT currentPath \(currentPath)")
            if chooser.currentType == .video{
                renderEngine?.loadFlexatar(path: chooser.videoPath)
            }else{
                print("FLX_INJECT path1 \(chooser.path1)")
                renderEngine?.loadFlexatar(path: chooser.path1,effectPath:chooser.path2)
                renderEngine?.effectCtrl.effectIdx = chooser.effectIdx
                renderEngine?.effectCtrl.mixWeight =  1 - chooser.mixWeight
            }
//            }
        }
      
        if let buffer = pixelBuffer {
            
            renderEngine?.draw(speechAnim:speechAnim,isRotated:isRotated)
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
