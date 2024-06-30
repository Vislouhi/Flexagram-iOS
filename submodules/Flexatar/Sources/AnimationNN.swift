//
//  AnimationNN.swift
//  Telegram
//
//  Created by Matey Vislouh on 20.04.2024.
//

import Foundation
import CoreML

class WavToMelFeatureProvider : MLFeatureProvider{
    var input:MLMultiArray
    var featureNames: Set<String>{
        get {
            return ["input_1"]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "input_1") {
            return MLFeatureValue(multiArray: input)
        }
        return nil
    }
    init(multiArray input: MLMultiArray) {
            self.input = input
    }
    
}
public class AnimationNN {
    
    private static func getWavToMelUrl() -> URL{
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .documentDirectory,
                                             in: .userDomainMask).first!
        return appSupportURL.appendingPathComponent("wav_to_mel_good.mlmodelc")
    }
    private static func getModelUrl(name:String) -> URL{
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .documentDirectory,
                                             in: .userDomainMask).first!
        return appSupportURL.appendingPathComponent(name + ".mlmodelc")
    }
    public static func wav2melCalc(data:Data) -> MLMultiArray?{
        let ptr = UnsafeMutableRawPointer(mutating: (data as NSData).bytes)
        guard let inputArray = try? MLMultiArray(dataPointer: ptr,
                                 shape: [1, 800],
                                 dataType: MLMultiArrayDataType.float32,
                                 strides: [1, 1]) else {
            fatalError("Unexpected runtime error.")
        }
        if let mel_out = try? wav2mel?.prediction(from:WavToMelFeatureProvider(multiArray: inputArray))  {
//            print("FLX_INJECT featureNames: " , mel_out.featureNames)
            if let result = mel_out.featureValue(for: "Identity")?.multiArrayValue{
               return result
            }

        }else{
            fatalError("Unexpected runtime error.")
        }
        return nil
    }
    public static func testWavToMelModel(model:MLModel){
        let dataType = MLMultiArrayDataType.float32
//        let data = Data()
        
        let floatArray = [Float](repeating: 0.0, count: 800)
        let data = floatArray.withUnsafeBufferPointer {Data(buffer: $0)}
        // Convert the float array to Data
//        let data = Data(buffer: UnsafeBufferPointer(start: &floatArray, count: floatArray.count))

        
        let ptr = UnsafeMutableRawPointer(mutating: (data as NSData).bytes)
        guard let inputArray = try? MLMultiArray(dataPointer: ptr,
                                 shape: [1, 800],
                                 dataType: dataType,
                                 strides: [1, 1]) else {
            fatalError("Unexpected runtime error.")
        }

//        let mlFeature = try! MLDictionaryFeatureProvider(dictionary: ["input_1": inputArray])
//        try? model.predict()
        if let mel_out = try? model.prediction(from:WavToMelFeatureProvider(multiArray: inputArray))  {
            print("FLX_INJECT featureNames: " , mel_out.featureNames)
            if let result = mel_out.featureValue(for: "Identity")?.multiArrayValue{
                print("FLX_INJECT multiarray obtained of shape: " , result.shape)
            }

        }else{
            fatalError("Unexpected runtime error.")
        }
    }
    
    static let animationAmp:Float = 7
    public static func extractCollumnFrom(mlArray:MLMultiArray,pos:Int) -> [Float]{
        
        let aVecFloat:[Float] = [
            -animationAmp*(Float(truncating: mlArray[[0,pos,0,0] as [NSNumber]])-0.5),
            -animationAmp*(Float(truncating: mlArray[[0,pos,1,0] as [NSNumber]])-0.48),
            -animationAmp*(Float(truncating: mlArray[[0,pos,2,0] as [NSNumber]])-0.52),
            -animationAmp*(Float(truncating: mlArray[[0,pos,3,0] as [NSNumber]])-0.43),
            -animationAmp*(Float(truncating: mlArray[[0,pos,4,0] as [NSNumber]])-0.46),

        ]
       return aVecFloat
    }
    static var modelsNotLoaded:Bool = true
    static var modelsAreNotLoading:Bool = true
    static var  wav2mel:MLModel?
    static var  mel2phon:MLModel?
    static var  phon2avec:MLModel?
    
    static var  melList:[MLMultiArray] = []
    public static func reset(){
        melList.removeAll()
    }
    static func loadModels(){
        if modelsNotLoaded{
            wav2mel = try? MLModel(contentsOf: getModelUrl(name:"wav_to_mel_good"))
            mel2phon = try? MLModel(contentsOf: getModelUrl(name:"wmel_to_phoneme"))
            phon2avec = try? MLModel(contentsOf: getModelUrl(name:"wphoneme_to_avec"))
            modelsNotLoaded = false
        }
    }
    static func submitAudioPacket(data:Data)->[Float]{
        if modelsNotLoaded{
            if modelsAreNotLoading{
                modelsAreNotLoading = false
                DispatchQueue(label: "org.flexatar.loadAnimNN").async{
                    wav2mel = try? MLModel(contentsOf: getModelUrl(name:"wav_to_mel_good"))
                    mel2phon = try? MLModel(contentsOf: getModelUrl(name:"wmel_to_phoneme"))
                    phon2avec = try? MLModel(contentsOf: getModelUrl(name:"wphoneme_to_avec"))
                    modelsNotLoaded = false
                }
            }
            
                
            return [0.0,0.0,0.0,0.0,0.0]
        }
        if let mel = wav2melCalc(data: data){
            melList.append(mel)
        }
        
        let windowLen = 20
        while melList.count>windowLen{
            melList.remove(at: 0)
        }
        if (melList.count == windowLen){
            let melGroup = concatMelsInGroup(mels:melList)
            let aVec = aVecBy(mel: melGroup)
            return extractCollumnFrom(mlArray: aVec, pos: 9).map { $0.isNaN ? 0 : $0 }
        }
        return [0.0,0.0,0.0,0.0,0.0]
    }
    static func aVecBy(mel:MLMultiArray) -> MLMultiArray{
        guard let phoneme = (try? mel2phon?.prediction(from:WavToMelFeatureProvider(multiArray: mel) ))?.featureValue(for: "Identity")?.multiArrayValue else {
            fatalError("Unexpected runtime error.")

        }
        
        guard let shortendArray = try? MLMultiArray(shape: [1,20,7,1], dataType: .float32) else {
                    fatalError("Unexpected runtime error.")
        
                }
        for i in 0..<20{
            for j in 0..<7{
                var phonVal = phoneme[[0,i,j,0] as [NSNumber]]
                if Float(truncating: phonVal)<0{
                    phonVal = 0
                }
                if Float(truncating: phonVal)>1 {
                    phonVal = 1
                }
                shortendArray[[0,i,j,0] as [NSNumber]] = phonVal
            }
        }
        
        guard let aVec = try? phon2avec?.prediction(from:WavToMelFeatureProvider(multiArray: shortendArray) ).featureValue(for: "Identity")?.multiArrayValue else {
            fatalError("Unexpected runtime error.")
            
        }

        return aVec
   
    }
    static func concatMelsInGroup(mels:[MLMultiArray]) -> MLMultiArray{
        guard let outputArray = try? MLMultiArray(shape: [1,(5*mels.count) as NSNumber, 80 ,1], dataType: .float32) else {
            fatalError("Unexpected runtime error.")
            
        }
       
        
        for (melIdx,mel) in mels.enumerated(){
            for i in 0..<5{
                for j in 0..<80{
                    outputArray[[0,5*melIdx+i,j,0] as [NSNumber]] = mel[[0,i,j,0] as [NSNumber]]
                }
                
            }
        }
        return outputArray
    }
    
    private static func compileModels(){
        let modelNames = ["wav_to_mel_good","wmel_to_phoneme","wphoneme_to_avec"]
        for modelName in modelNames{
            let modelUrl = getModelUrl(name:modelName)
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: modelUrl.path){
                print("FLX_INJECT model ready: "+modelName)
                continue
            }
            if let modelDescriptionURL = Bundle.main.url(forResource: modelName, withExtension: "mlm"){
                if let compiledModelURL = try? MLModel.compileModel(at: modelDescriptionURL){
                    if let res = try? fileManager.replaceItemAt(modelUrl,
                                                                withItemAt: compiledModelURL){
                        
                        print("FLX_INJECT compiled and saved:",modelName,res)
                    }else{continue}
                        
                }else{
                    print("FLX_INJECT compile failed:",modelName)
                    continue
                }
            }else{
                print("FLX_INJECT model not found:",modelName)
                continue
            }
                
        }
    }
    public static func prepare(){
        compileModels()
        /*if #available(iOS 14.0, *) {
            AppAttest.start()
        } else {
            // Fallback on earlier versions
        }*/
        
       /*if let flxFileUrl = Bundle.main.path(forResource: "x00_char1t", ofType: "flx"){
           _ = UnpackFlexatarFile(path: flxFileUrl)
//            let metaData = MetaDataFlexatar(withPreviewImage: true,atPath: flxFileUrl)
//            print("FLX_INJECT meatadata name:\(metaData.flxInfo!.name)")
        }else{
            print("FLX_INJECT can not find flexatar file")
        }*/
        
    }
    
}
