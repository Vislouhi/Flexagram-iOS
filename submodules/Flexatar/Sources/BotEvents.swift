//
//  BotEvents.swift
//  Flexatar
//
//  Created by Matey Vislouh on 06.06.2024.
//

import Foundation
import TelegramCore
public class TgFileId {
    private static func rleEncode(_ binary: Data) -> Data {
        var new = Data()
        var count = 0

        for cur in binary {
            if cur == 0 {
                count += 1
            } else {
                if count > 0 {
                    new.append(0)
                    new.append(UInt8(count))
                    count = 0
                }
                new.append(cur)
            }
        }

        if count > 0 {
            new.append(0)
            new.append(UInt8(count))
        }

        return new
    }
    private static func posMod(_ a:Int, _ b:Int) -> Int{
        let rest = a%b
        return rest<0 ? rest + abs(b) : rest
    }
    private static func packTLString(_ stringData: Data) -> Data {

        
                
        let length = stringData.count
        var concat = Data()
        
        if length <= 253 {
            concat.append(UInt8(length))
            let fill = posMod(-(length + 1), 4)
            concat.append(stringData)
            concat.append(Data(repeating: 0, count: fill))
        } else {
            concat.append(254)
            var lengthBytes = withUnsafeBytes(of: UInt32(length).littleEndian) { Data($0) }
            lengthBytes.removeLast()  // Take only the first 3 bytes
            concat.append(lengthBytes)
            
            let fill = posMod(-length, 4)
            concat.append(stringData)
            concat.append(Data(repeating: 0, count: fill))
        }
        
        return concat
    }
    private static func packUnsignedLong(_ value: UInt32) -> Data {
        var littleEndianValue = value.littleEndian
        return Data(bytes: &littleEndianValue, count: MemoryLayout<UInt32>.size)
    }
    private static func packSignedLong(_ value: Int64) -> Data {
        var littleEndianValue = value.littleEndian
        return Data(bytes: &littleEndianValue, count: MemoryLayout<Int64>.size)
    }

    private static func toUnicode(_ x: Any) -> String {
        if let binary = x as? Data {
            return String(data: binary, encoding: .utf8) ?? ""
        } else if let text = x as? String {
            return text
        } else {
            return toUnicode(String(describing: x))
        }
    }
    public static func make(dcId:Int32,fileReference:Data,id:Int64,accessHash:Int64) -> String{
//        let subVersion:UInt8 = 53
//        let version:UInt8 = 4
        let vesions : [UInt8] = [53, 4]
        let sizeType: [UInt8] = [0x6d, 0x00, 0x00, 0x00]
        let fileRefFlag:UInt32 = 1 << 25
        let typeId:UInt32 = 2
        let typeIdP = typeId | fileRefFlag
        var result = Data()
        result += packUnsignedLong(typeIdP)
        result += packUnsignedLong(UInt32(dcId))
        result += packTLString(fileReference)
        result += packSignedLong(id)
        result += packSignedLong(accessHash)
        result += packUnsignedLong(UInt32(1))
        result += packUnsignedLong(typeId)
        result += Data(sizeType)
        result += Data(vesions)
        
//        result += String(subVersion).data(using: .utf8)!
//        result += String(version).data(using: .utf8)!
        
        
        result = rleEncode(result)
        let fileId = result.base64EncodedString(options: [.endLineWithLineFeed])
        let base64urlEncoded = fileId
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        return base64urlEncoded
//        print("FLX_INJECT fileId : \(base64urlEncoded)")
        
    }
}
//import LegacyComponents
public class BotEvents{
    public static func extractSubstringAfterLastSlash(from input: String) -> String {
        
        guard let range = input.range(of: "/", options: .backwards) else {
            return input
        }
        return String(input[range.upperBound...])
    }
    
    private static func updateDownload(endpoint:String)->String{
        let fid = extractSubstringAfterLastSlash(from:endpoint)
        return "\(endpoint)/\(fid).p"
    }
    private static func forwardEndpoint(ftar:String)->String{
        let parts = ftar.split(separator: "/").map{String($0)}
//        let type,ver,tag,owner,flxId = parts[0],parts[1],parts[2],parts[3],parts[4]
        let ver:String = parts[1]
        let tag:String
        let owner:String
        let flxId:String
        if parts[0] == "private"{
            tag = parts[2]
            owner = parts[3]
            flxId = parts[4]
        }else{
            tag = "tg"
            owner = "0"
            flxId = parts[2]
        }
        return ["forward",parts[0],ver,tag,owner,flxId].joined(separator: "/")
        
    }
    public static func subscribe(){
//        let numbers: [UInt8] = [1,0,0,12,108,102,68,206,73,141,149,117,202,162,132,157,190,84,208,104,16,37,42,70,179]
//        let fileReference = Data(numbers)
//        let photo_id:Int64 = 5339115103569697558
//        let dc_id:Int32 = 2
//        let access_hash:Int64 = 3234066006077291991
//        Backend.verify()
        BotListener.botEvent = {accountPeerId, message, photoAcess in
            print("FLX_INJECT bot message account \(accountPeerId) val \(message) photoAcess \(String(describing: photoAcess))")
            if let photoAcess = photoAcess, let flexatarName = message["flexatar_name"], let ftar = message["ftar"]{
                let fileId = TgFileId.make(dcId: photoAcess.dcId,fileReference: photoAcess.fileReference,id:photoAcess.id,accessHash: photoAcess.accessHash)
                
                struct SendFlxFwd:Codable{
                    var name:String
                    var photoid:String
                }
                let send = SendFlxFwd(name: flexatarName, photoid: fileId)
                guard let sendData = try? JSONEncoder().encode(send) else { return }
                let endpoint = forwardEndpoint(ftar: ftar)
                Backend.request(accountId: accountPeerId, endpoint: endpoint, completion: {_,_ in
                    print("FLX_INJECT forward request sucess")
                }, fail: {
                    print("FLX_INJECT forward request fail")
                },body:sendData)
                print("FLX_INJECT fileId : \(fileId)")
                return
            }
            if let ftar = message["ftar"], let active = message["active"]{
                let ftarEndpoint = updateDownload(endpoint:ftar)
                if active == "true"{
                    
                    StorageFlx.addTask(task: StorageTask(peerId: accountPeerId, endpoint: ftarEndpoint, type: .add))

                }else{
                    StorageFlx.addTask(task: StorageTask(peerId: accountPeerId, endpoint: ftarEndpoint, type: .remove))
                }
                return
            }
            if let token = message["verify"]{
                let defaults = UserDefaults.standard
                defaults.set(token,forKey: "bot_token_for_\(accountPeerId)")
                Backend.getToken(tempTocken:token,accountId: accountPeerId)
            }
            
            
        }
    }
//    public static func event(accountPeerId:Int64,message:[String:String]){
//        print("FLX_INJECT bot message account \(accountPeerId) val \(message)")
//    }
    
}
