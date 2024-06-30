import Foundation
import AVFAudio

extension Data {
    func toFloatArray() -> [Float] {
        let capacity = self.count / MemoryLayout<Float>.size
        let result = [Float](unsafeUninitializedCapacity: capacity) {
                pointer, copied_count in
                let length_written = self.copyBytes(to: pointer)
                copied_count = length_written / MemoryLayout<Float>.size
                assert(copied_count == capacity)
            }
        return result
    }
    
    func toInt16Array() -> [Int16] {
        let capacity = self.count / MemoryLayout<Int16>.size
        let result = [Int16](unsafeUninitializedCapacity: capacity) {
                pointer, copied_count in
                let length_written = self.copyBytes(to: pointer)
                copied_count = length_written / MemoryLayout<Int16>.size
                assert(copied_count == capacity)
            }
        return result
    }
}

extension AVAudioPCMBuffer{

    convenience init?(data:Data,format:AVAudioFormat){

        if format.commonFormat == .pcmFormatFloat32 {
            let floatAudio = data.toFloatArray()
            self.init(pcmFormat: format, frameCapacity: AVAudioFrameCount(floatAudio.count ))
            for (frame,flaotValue) in floatAudio.enumerated(){
                
                let chanData = self.floatChannelData![0]
                chanData[frame] = flaotValue
                
            }
            self.frameLength = AVAudioFrameCount(floatAudio.count)
        }else{
            let intAudio = data.toInt16Array()
            self.init(pcmFormat: format, frameCapacity: AVAudioFrameCount(intAudio.count ))
            for (frame,intValue) in intAudio.enumerated(){
                
                let chanData = self.int16ChannelData![0]
                chanData[frame] = intValue
                
            }
            self.frameLength = AVAudioFrameCount(intAudio.count)
        }
    }
    func asData() -> Data {
        let channelCount = Int(format.channelCount)
        let channelLength = frameLength * UInt32(channelCount)

        if self.format.commonFormat == .pcmFormatInt16{
            let floatData = UnsafeBufferPointer(start: int16ChannelData?[0], count: Int(channelLength))
            let data = Data(bytes: floatData.baseAddress!, count: Int(channelLength * UInt32(MemoryLayout<Int16>.size)))
            return data
        }else  {
            let floatData = UnsafeBufferPointer(start: floatChannelData?[0], count: Int(channelLength))
            let data = Data(bytes: floatData.baseAddress!, count: Int(channelLength * UInt32(MemoryLayout<Float>.size)))
            return data
        }
        
       
    }
    
}


public class SoundProcessing{
    static var voiceInputFormat48:AVAudioFormat?
    public static var speachAnimVector:[Float] = [0,0,0,0,0]
    
    static let voiceProcessinFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                               sampleRate: 16000,
                               channels: 1,
                               interleaved: false)!
    
    static var formatConverterTransmitToFloat:AVAudioConverter?
    
    public static func printAudioData(_ data:Data){
        let capacity = data.count / MemoryLayout<Int16>.size
        let result = [Int16](unsafeUninitializedCapacity: capacity) {
                pointer, copied_count in
                let length_written = data.copyBytes(to: pointer)
                copied_count = length_written / MemoryLayout<Int16>.size
                assert(copied_count == capacity)
            }
        print("FLX_INJECT callback swift side",result)
    }
    
    public static func convertToFloat16000(_ data:Data) ->Data?{
//        print("FLX_INJECT input data size:",data.count)
        let sampleRate = data.count*100 / 2
        if (voiceInputFormat48 == nil){
            voiceInputFormat48 = AVAudioFormat( commonFormat: .pcmFormatInt16,
                                                sampleRate: Double(sampleRate),
                                                channels: 1,
                                                interleaved: false)
            formatConverterTransmitToFloat =  AVAudioConverter(from:voiceInputFormat48!, to: voiceProcessinFormat)
        }
//        print(sampleRate)
        
        let bufferSizeConverted = AVAudioFrameCount(160)
        
        guard let pcmBufferTransmit = AVAudioPCMBuffer(data: data, format: voiceInputFormat48!) else {return nil}
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: self.voiceProcessinFormat, frameCapacity: bufferSizeConverted)else{return nil}
        let inputBlock: AVAudioConverterInputBlock = {inNumPackets, outStatus in
            outStatus.pointee = AVAudioConverterInputStatus.haveData
            return pcmBufferTransmit
        }
        var error: NSError? = nil
        formatConverterTransmitToFloat?.convert(to: pcmBuffer, error: &error, withInputFrom: inputBlock)
        return pcmBuffer.asData()
        //        let convertedAudioSignal = pcmBuffer.asData()
//        print(convertedAudioSignal.toFloatArray())
    }
    public static func convertToFloat16000CustomLength(_ data:Data) ->Data?{
//        print("FLX_INJECT input data size:",data.count)
        let frameCount = data.count / 2
        let sampleRate = 48000
        if (voiceInputFormat48 == nil){
            voiceInputFormat48 = AVAudioFormat( commonFormat: .pcmFormatInt16,
                                                sampleRate: Double(sampleRate),
                                                channels: 1,
                                                interleaved: false)
            formatConverterTransmitToFloat =  AVAudioConverter(from:voiceInputFormat48!, to: voiceProcessinFormat)
        }
//        print(sampleRate)
        
        let bufferSizeConverted = AVAudioFrameCount(frameCount * 16 / 48)
        
        guard let pcmBufferTransmit = AVAudioPCMBuffer(data: data, format: voiceInputFormat48!) else {return nil}
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: self.voiceProcessinFormat, frameCapacity: bufferSizeConverted)else{return nil}
        let inputBlock: AVAudioConverterInputBlock = {inNumPackets, outStatus in
            outStatus.pointee = AVAudioConverterInputStatus.haveData
            return pcmBufferTransmit
        }
        var error: NSError? = nil
        formatConverterTransmitToFloat?.convert(to: pcmBuffer, error: &error, withInputFrom: inputBlock)
        return pcmBuffer.asData()
        //        let convertedAudioSignal = pcmBuffer.asData()
//        print(convertedAudioSignal.toFloatArray())
    }
    public static var audiPacketsCollector:[Data] = []
    public static func collectPackets(_ data :Data)->Data?{
        audiPacketsCollector.append(data)
        if audiPacketsCollector.count == 5{
            var result = Data()
            for d in audiPacketsCollector{
                result += d
            }
            audiPacketsCollector = []
            return result
           
        }
        return nil
        
    }
    public static let soundQueue =  DispatchQueue(label: "soundProc",qos:.userInitiated)
    public static let nnQueue =  DispatchQueue(label: "nnProc",qos:.userInitiated)
    private static var soundQueueFree = true
    private static var nnQueueFree = true
    
    private static func splitData(data: Data, partSize: Int) -> [Data] {
        // Ensure partSize is positive
        guard partSize > 0 else { return [] }
        
        var result = [Data]()
        var startIndex = 0
        
        while startIndex < data.count {
            let endIndex = min(startIndex + partSize, data.count)
            let subData = data.subdata(in: startIndex..<endIndex)
            result.append(subData)
            startIndex += partSize
        }
        
        return result
    }

    public static func animForRoundVideo()->[[Float]]{
        let fileName = "flx_auido.bin"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        if var data = try? Data(contentsOf: fileURL){
            data += Data(repeating: 0, count: 48000/2*4)
            if let audioPacket = convertToFloat16000CustomLength(data){
                
                let packets = splitData(data: audioPacket, partSize: 800 * 4)
                AnimationNN.loadModels()
                AnimationNN.reset()
                return Array((packets.map{AnimationNN.submitAudioPacket(data: $0)}).dropFirst(10))
            }
        }
        return []
    }
    public static func makeAnimVector(_ data :Data){
        let data1 = Data(data)
        if soundQueueFree {
            soundQueueFree = false
            soundQueue.async {
                
                if let smallAudioPacket = convertToFloat16000(data1){
                    
                    if let nnReadyPacket = collectPackets(smallAudioPacket){
                        if nnQueueFree {
                            nnQueueFree = false
                            nnQueue.async {
                                let animVector = AnimationNN.submitAudioPacket(data: nnReadyPacket)
                                speachAnimVector = animVector
                                nnQueueFree = true
                            }
                        }
                        
                        // print(animVector)
                    }
                }
                soundQueueFree = true
                
            }
        }
        
    }
    
}
public  func printAudioData(_ data:Data){
    let capacity = data.count / MemoryLayout<Int16>.size
    let result = [Int16](unsafeUninitializedCapacity: capacity) {
            pointer, copied_count in
            let length_written = data.copyBytes(to: pointer)
            copied_count = length_written / MemoryLayout<Int16>.size
            assert(copied_count == capacity)
        }
    print("FLX_INJECT callback swift side",result)
}



