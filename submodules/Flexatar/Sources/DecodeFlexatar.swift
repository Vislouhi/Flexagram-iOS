//
//  DecodeFlexatar.swift
//  Flexatar
//
//  Created by Matey Vislouh on 26.04.2024.
//

import Foundation
import UIKit
import SceneKit

struct FlxNodeHeader:Codable{
    var type:String
    var index:Int
    
}

struct FlxInfoNode:Codable{
    var name:String
    var date:String?
    var type:String?
    
}
struct Delimiter:Codable{
    var type:String
    
}
class MetaDataFlexatar{
    public var imageData:Data?
    public var flxInfo:FlxInfoNode?
    
    init(withPreviewImage:Bool,atPath path:String){
//        if let flxFileUrl = Bundle.main.path(forResource: "x00_char1t", ofType: "flx"){
            
            guard let fileHandle = FileHandle(forReadingAtPath: path) else {
                print("FLX_INJECT Failed to open file for reading")
               return
            }
            
            defer {
                fileHandle.closeFile() // Close the file when done
            }
            let decoder = JSONDecoder()
        let (_,flxinfo) = Self.readBlock(fileHandle: fileHandle, decoder: decoder)
//            print("FLX_INJECT header \(header!.type)")
            self.flxInfo = try? decoder.decode(FlxInfoNode.self, from: flxinfo)
//            print("FLX_INJECT flx info: \(flxInfo!.name)")
            
        let (_,imgData) = Self.readBlock(fileHandle: fileHandle, decoder: decoder)
            self.imageData = imgData

//        }else{
//            print("FLX_INJECT can not find flexatar file")
//        }
        
    }
    public static func readBlock(fileHandle:FileHandle,decoder:JSONDecoder)->(FlxNodeHeader?,Data){
        let fileData = fileHandle.readData(ofLength: 8)
        if fileData.isEmpty{
            return (nil, Data())
        }
        var lengthHeader = fileData.withUnsafeBytes { $0.load(as: UInt64.self)}
        let nodeHeader = try? decoder.decode(FlxNodeHeader.self, from: fileHandle.readData(ofLength: Int(lengthHeader)))
        lengthHeader = fileHandle.readData(ofLength: 8).withUnsafeBytes { $0.load(as: UInt64.self)}
        
        return (nodeHeader,fileHandle.readData(ofLength: Int(lengthHeader)))
        
    }
}

public class UnpackFlexatarFile{
    private static let DELIMITER = "Delimiter"
    private static let TEXTURE_KEY = "mandalaTextureBlurBkg"
    private static let TEXTURE_MOUTH_KEY = "mandalaTexture"
    private static let FACE_ENTRY = "face"
    private static let MOUTH_ENTRY = "mouth"
    
    private var dataDict = [String:[String:[Data]]]()
    
    public var faceTexture:MTLTexture?
    
    public var mandalaTriangles:[[CGPoint]] = []
    
    public var mandalaBorder:[(CGPoint,CGPoint)] = []
    public var mandalaFaces:[[Int]] = []
    public var mandalaBlendshapes:MTLBuffer?
    public var blinkBlendshape:MTLBuffer?
    public var mouth:UnpackMouth!
    
    init(path:String){
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            print("FLX_INJECT Failed to open file for reading")
           return
        }
        
        defer {
            fileHandle.closeFile() // Close the file when done
        }
        let decoder = JSONDecoder()
        
        var partName = Self.FACE_ENTRY
        self.dataDict[partName] = [String:[Data]]()
        while(true){
            let (nodeHeader,data) =  MetaDataFlexatar.readBlock(fileHandle: fileHandle, decoder: decoder)
            if let header = nodeHeader{
                print("FLX_INJECT found header : \(header.type)")
                if header.type == Self.DELIMITER{
                    partName = (try! decoder.decode(Delimiter.self, from: data)).type
                    self.dataDict[partName] = [String:[Data]]()
//                    print("FLX_INJECT found delimiter : \(String(data: data, encoding: .utf8)!)")
                }else{
                    if (self.dataDict[partName]![header.type] == nil){
                        self.dataDict[partName]![header.type] = []
                    }
                    self.dataDict[partName]![header.type]?.append(data)
                }
                
            }else{
                print("FLX_INJECT end of file")
                break
            }
        }
        self.mouth = UnpackMouth(dict: self.dataDict[Self.MOUTH_ENTRY]!)
        
        self.makeMouthKeyPoints()
        self.makeMandala()
        
    }
    private static let idxOfInterest = [88,97,50,43,54,46]
    private var mouthPoints:[[SIMD4<Float>]] = []
    
    public func calcMouthKeyPoints(interUnit:([Int32], [Float], simd_float4x4 ),viewModelMat:simd_float4x4,zRotMat:simd_float4x4,tx:Float,ty:Float,sc:Float,screenRatio:Float,speechBshKey:[Float]) -> [SIMD4<Float>]{
        var ret:[SIMD4<Float>] = []
        for (idx,mp) in mouthPoints.enumerated(){
            ret.append(calcKeyVtx(vtxBsh: mp, interUnit: interUnit,viewModelMat:viewModelMat,zRotMat:zRotMat,tx:tx,ty:ty,sc:sc,screenRatio:screenRatio,speechBshKey:speechBshKey,calcSpeech:idx==2))
        }
        return ret
        
    }
    public func calcKeyVtx(vtxBsh:[simd_float4], interUnit:([Int32], [Float], simd_float4x4), viewModelMat:simd_float4x4, zRotMat:simd_float4x4, tx:Float,ty:Float,sc:Float, screenRatio:Float, speechBshKey:[Float], calcSpeech:Bool)->SIMD4<Float>{
        var vtx = SIMD4<Float>(0,0,0,0)
        for i in 0..<3{
//            let weight = simd_float1(interUnit.1)
            let w = interUnit.1[i]
            vtx += vtxBsh[Int(interUnit.0[i])] * SIMD4<Float>(w,w,w,w)
        }
        if (calcSpeech){
            for i in 0..<5{
                vtx.y += speechBshKey[i] * SoundProcessing.speachAnimVector[i] * 0.3
            }
        }
        vtx = interUnit.2 * vtx
        vtx = viewModelMat * vtx
        vtx.x = atan(vtx.x/vtx.z)*5
        vtx.y = atan(vtx.y/vtx.z)*5
//        vtx.y *= -1
        vtx.y -= 4
        vtx = zRotMat * vtx
        vtx.y += 4
        vtx.x += tx
        vtx.y -= ty
        vtx.x *= 0.8 + sc
        vtx.y *= 0.8 + sc
        vtx.y *= screenRatio
//        print("FLX_INJECT vtx \(vtx)")
        return vtx
//        let rotated = simd_float4x4(interUnit.2) * simd_float4(vector)
    }
    private func makeMouthKeyPoints(){
        let blendhsapes = self.dataDict[Self.FACE_ENTRY]!["mandalaBlendshapes"]![0].toFloatArray()
        for _ in Self.idxOfInterest{
            mouthPoints.append([SIMD4<Float>]())
        }
        for i in 0..<5{
            for (j,idx) in Self.idxOfInterest.enumerated(){
                let pos = idx*5*4 + i*4
                let vtx = SIMD4<Float>(blendhsapes[pos+0],blendhsapes[pos+1],blendhsapes[pos+2],1)
//                let vtx:[Float] = [blendhsapes[pos+0],blendhsapes[pos+1],blendhsapes[pos+2],blendhsapes[pos+3]]
                mouthPoints[j].append(vtx)
            }
        }
        print("FLX_INJECT makeMouthKeyPoints \(mouthPoints)")
    }
    
    private func makeMandala(){
        let dataCheckpoints = self.dataDict[Self.FACE_ENTRY]!["mandalaCheckpoints"]![0]
        let count = dataCheckpoints.count / MemoryLayout<Float>.size
        let checkPoints =  dataCheckpoints.withUnsafeBytes {pointer in
                [Float](UnsafeBufferPointer(start: pointer.baseAddress!.assumingMemoryBound(to: Float.self), count: count))
            }
        
        let dataFaces = self.dataDict[Self.FACE_ENTRY]!["mandalaFaces"]![0]
        let countFaces = dataFaces.count / MemoryLayout<Int>.size
        let faceFalt =  dataFaces.withUnsafeBytes {pointer in
                [Int](UnsafeBufferPointer(start: pointer.baseAddress!.assumingMemoryBound(to: Int.self), count: countFaces))
            }
        var cnt = 0
        for i in 0..<countFaces/3{
            self.mandalaTriangles.append([CGPoint]())
            self.mandalaFaces.append([Int]())
            for _ in 0..<3{
                let currentIdx = faceFalt[cnt]
                let currentPoint = CGPoint(x: CGFloat(checkPoints[currentIdx*2]), y: CGFloat(checkPoints[currentIdx*2+1]))
                self.mandalaTriangles[i].append(currentPoint)
                self.mandalaFaces[i].append(currentIdx)
                cnt+=1
            }
        }
        
        let dataBorder = self.dataDict[Self.FACE_ENTRY]!["mandalaBorder"]![0]
        let countBorder = dataBorder.count / MemoryLayout<Int>.size
        let mandalaBorderIndex =  dataBorder.withUnsafeBytes {pointer in
                [Int](UnsafeBufferPointer(start: pointer.baseAddress!.assumingMemoryBound(to: Int.self), count: countBorder))
            }
        for idx in 0..<mandalaBorderIndex.count-1 {
            let i = mandalaBorderIndex[idx]
            let iNext = mandalaBorderIndex[idx+1]
            let currentPoint = CGPoint(x: CGFloat(checkPoints[i*2]), y: CGFloat(checkPoints[i*2+1]))
            let nextPoint = CGPoint(x: CGFloat(checkPoints[iNext*2]), y: CGFloat(checkPoints[iNext*2+1]))
            self.mandalaBorder.append((currentPoint, nextPoint))
        }
        let i = mandalaBorderIndex[mandalaBorderIndex.count-1]
        let iNext = mandalaBorderIndex[0]
        let currentPoint = CGPoint(x: CGFloat(checkPoints[i*2]), y: CGFloat(checkPoints[i*2+1]))
        let nextPoint = CGPoint(x: CGFloat(checkPoints[iNext*2]), y: CGFloat(checkPoints[iNext*2+1]))
        self.mandalaBorder.append((currentPoint, nextPoint))
        print("FLX_INJECT mandalaTriangles \(mandalaTriangles)")
        print("FLX_INJECT mandalaBorder \(mandalaBorder)")
        print("FLX_INJECT mandalaBorderIndex \(mandalaBorderIndex)")
   
    }
    private func makeTetxures(device:MTLDevice){
        let images = self.dataDict[Self.FACE_ENTRY]![Self.TEXTURE_KEY]!.map{UIImage(data:$0)!}
        self.faceTexture = RenderEngine.mkTextureArray(device: device, images: images)

    }
    private func makeBlendshapes(device:MTLDevice){
        let data = self.dataDict[Self.FACE_ENTRY]!["mandalaBlendshapes"]![0]
        mandalaBlendshapes = MetalResProviderFlx.makeMTLBuffer(device: device, buffer: data)
    }
    private func makeBlinkBlendshape(device:MTLDevice){
        let data = self.dataDict[Self.FACE_ENTRY]!["eyelidBlendshape"]![0]
        blinkBlendshape = MetalResProviderFlx.makeMTLBuffer(device: device, buffer: data)
    }
   
    public func prepareMetalRes(device:MTLDevice){
        makeTetxures(device: device)
        makeBlendshapes(device: device)
        makeBlinkBlendshape(device: device)
        mouth.prepare(device: device)
    }
    public func calcBshpCtrl(rx:Float,ry:Float)->([Int32],[Float],simd_float4x4){
        guard let interData = FlxAnimation.makeInterUint(point:CGPoint(x: CGFloat(rx), y: CGFloat(ry)), tiangles:self.mandalaTriangles, indices:self.mandalaFaces, border: self.mandalaBorder) else{
            let mat =  simd_float4x4(SCNMatrix4Identity)
            return ([0,1,2,3],[1,0,0,0],mat)
        }
        let xScale = 1*abs(Float(interData.2.x))/0.5
        let yScale = 1*abs(Float(interData.2.y))/0.5
        
//        let xScale = Float(1)
//        let yScale = Float(1)
        let extForce:Float = 0.5
        var xRot = -0.3*extForce*(1+yScale)*Float(interData.2.x)
        var yRot = -0.5*extForce*(1+xScale)*Float(interData.2.y)
        let xThr:Float = 0.05
        let yThr:Float = 0.04
        if xRot < -xThr {
            xRot = -xThr
        }
        if xRot > xThr{
            xRot = xThr
        }
        if yRot < -yThr {
            yRot = -yThr
        }
        if yRot > yThr{
            yRot = yThr
        }
//        print(xRot,yRot)
        let mat1 = SCNMatrix4MakeRotation(xRot,0,1,0)
        let mat2 = SCNMatrix4MakeRotation(yRot,1,0,0)
        
//        let mat1 = SCNMatrix4MakeRotation(-1*Float(interData.3.x),0,1,0)
//        let mat2 = SCNMatrix4MakeRotation(-1*Float(interData.3.y),1,0,0)

        
        let mat = SCNMatrix4Mult(mat2,mat1)

        let extraRotMatrix = simd_float4x4(mat)
        
        return (interData.0,interData.1,extraRotMatrix)
    }
}

struct FlxInfo:Codable{
    var camFovX:Double
    var camFovY:Double
    var bbox:[Double]
}
public class UnpackMouth{
    
    var mouthRatio:Float = 1.0
    var lipAnchores:[[SIMD2<Float>]]
    var lipSize:[Float]
    var teethGap:[Float]
    var mouthDict:[String:Data]
    public var idxBuffer: MTLBuffer?
    public var uvBuffer: MTLBuffer?
    public var mandalaBlendshapes: MTLBuffer?
    public var texture: MTLTexture?
    var idxCount: Int = 0
    private var dict:[String:[Data]]
    
    init(dict:[String:[Data]]){
        print("FLX_INJECT mouth flx info \(String(data:dict["FlxInfo"]![0],encoding: .utf8)!)")
        self.dict = dict
        let decoder = JSONDecoder()
        let flxInfo = (try! decoder.decode(FlxInfo.self, from: dict["FlxInfo"]![0]))
        print("FLX_INJECT mouth flx info \(flxInfo)")
        self.mouthRatio = Float(1) / Float(flxInfo.camFovX) / Float(flxInfo.camFovY) * Float(flxInfo.bbox[3]) / Float(flxInfo.bbox[2])
        
        let packs = Self.unpackDataWithLengthHeader(data:dict["mouthData"]![0])
        var mouthDict = [String:Data]()
        for i in 0..<packs.count/2{
            let key = String(data:packs[i*2],encoding: .utf8)!
            mouthDict[key] = packs[i*2+1]
        }
        self.mouthDict = mouthDict
        print("FLX_INJECT mouthDict keys \(mouthDict.keys)")
        self.lipAnchores = [[SIMD2<Float>]](repeating:[SIMD2<Float>](repeating: SIMD2<Float>(0,0), count: 2),count: 5)
        let lipAnchoresFlat = mouthDict["lip_anchors"]!.toFloatArray()
        for i in 0..<5 {
            for j in 0..<2 {
                let idx = i*4 + j*2
                self.lipAnchores[i][j].x = lipAnchoresFlat[idx]
                self.lipAnchores[i][j].y = lipAnchoresFlat[idx+1]
            }
        }
        self.lipSize = mouthDict["lip_size"]!.toFloatArray()
        let teethGapTmp = mouthDict["teeth_gap"]!.toFloatArray()
        self.teethGap = [
            1.0 - teethGapTmp[1],
            1.0 - (teethGapTmp[1] + teethGapTmp[3]),
        ]
       
    }
    
 
    private func prepareIndex(device:MTLDevice){
        let data = self.mouthDict["index"]!
        idxCount = data.count/2
        idxBuffer = MetalResProviderFlx.makeMTLBuffer(device: device, buffer: data)
    }
    private func prepareUv(device:MTLDevice){
        let data = self.mouthDict["uv"]!
        uvBuffer = MetalResProviderFlx.makeMTLBuffer(device: device, buffer: data)
    }
    private func prepareBlendshapes(device:MTLDevice){
        let data = self.dict["mandalaBlendshapes"]![0]
        mandalaBlendshapes = MetalResProviderFlx.makeMTLBuffer(device: device, buffer: data)
    }
    private func makeTetxures(device:MTLDevice){
        let images = self.dict["mandalaTexture"]!.map{UIImage(data:$0)!}
        texture = RenderEngine.mkTextureArray(device: device, images: images)

    }
    public func prepare(device:MTLDevice){
        prepareIndex(device:device)
        prepareUv(device:device)
        prepareBlendshapes(device:device)
        makeTetxures(device:device)
    }
    public func calcMouthPivots(idx:[Int32],weights:[Float]) ->(SIMD2<Float>,SIMD2<Float>,Float){
        var topPivot = SIMD2<Float>(repeating: 0)
        var botPivot = SIMD2<Float>(repeating: 0)
        var lipSizeLoc:Float = 0
        for i in 0..<3{
            let bshpIdx = Int(idx[i])
            let w = weights[i]
            topPivot += lipAnchores[bshpIdx][0] * SIMD2<Float>(repeating: w)
            botPivot += lipAnchores[bshpIdx][1] * SIMD2<Float>(repeating: w)
            lipSizeLoc += lipSize[bshpIdx] * w
        }
        return (topPivot,botPivot,lipSizeLoc)
    }
    
    private static func unpackDataWithLengthHeader(data: Data) -> [Data] {

        var outputData = [Data]()
        var offset = 0
        while offset < data.count {

            let imageLength = data.subdata(in: offset..<offset+8).withUnsafeBytes { $0.load(as: UInt64.self) }
            offset += 8

            if offset + Int(imageLength) <= data.count {
                let data = data.subdata(in: offset..<offset+Int(imageLength))

                outputData.append(data)
            }
            offset += Int(imageLength)

        }
        

        
        return outputData
    }
}

