import Foundation

import TelegramApi
public struct PhotoAccessData{
    public var id:Int64
    public var accessHash:Int64
    public var dcId:Int32
    public var fileReference:Data
    public var size:[String]
    
}
//import Flexatar

public class BotListener{
    public static func unpackEntities(entities:[MessageTextEntity]) -> [String : String]?{
entityLoop:for entity in entities{
//    print(entity)
    switch entity.type{
           case let .TextUrl(urlString):
               guard let url = URL(string: urlString) else { break }
               guard let comp = URLComponents(url: url, resolvingAgainstBaseURL: false) else {break}
               guard let queryItems = comp.queryItems else {break}
               var botMessage: [String : String] = [:]
               for queryItem in queryItems {
                   if let val = queryItem.value{
                       botMessage[queryItem.name] = val
                       
                   }
               }
               return botMessage

              
               
           default:
               break
           }
       }
        return nil
    }
    public static var botEvent:((Int64,[String:String],PhotoAccessData?)->())?
    public static func event(accountPeerId:Int64,message: Api.Message,isShare:Bool = false){
//        print("FLX_INJECT bot accountPeerId \(accountPeerId)")
//        print("FLX_INJECT bot message event \(message)")
       
        switch message {
        case let .message(_, _, _, _, _, _, _, _, _, _, _, _, msg, media, _, entities, _, _, _, _, _, _, _, _, _, _):
            guard let entities = entities else {break}
 entityLoop:for entity in entities{
                switch entity{
                case let .messageEntityTextUrl(_, _, urlString):
                    guard let url = URL(string: urlString) else { break }
                    guard let comp = URLComponents(url: url, resolvingAgainstBaseURL: false) else {break}
                    guard let queryItems = comp.queryItems else {break}
                    var botMessage: [String : String] = [:]
                    for queryItem in queryItems {
                        if let val = queryItem.value{
                            botMessage[queryItem.name] = val
//                            print("FLX_INJECT bot query name \(queryItem.name) val \(val)")
                        }
                    }
                    var photoAccessData:PhotoAccessData?
                    if isShare{
                        botMessage["is_share"] = "true"
                        botMessage["flexatar_name"] = msg
                        switch media {
                        case let .messageMediaPhoto(_, photo, _):
                            
                            

                            switch photo{
                            case let .photo(_, id, accessHash, fileReference, _, sizes, _, dcId):
                                photoAccessData = PhotoAccessData(id: id, accessHash: accessHash, dcId: dcId, fileReference: fileReference.makeData(), size: [])
                                for size in sizes{
                                    switch size{
                                    case let .photoSize(type, _, _, _):
                                        photoAccessData!.size.append(type)
                                        break
                                    default:
                                        break
                                    }
                                }
                                break
                            default:
                                break
                            }
                            break
                        default:
                            break
                        }
                    }
                    botEvent?(accountPeerId,botMessage,photoAccessData)
//                    BotEvents.event(accountPeerId: accountPeerId, message: botMessage)
//                    print("FLX_INJECT bot message event url found \(url)")
                    break entityLoop
                    
                default:
                    break
                }
            }
            break
            
        default:
            break
        }
        
    }
    public static func checkIfBot(peerId:Int64) -> Bool{
        return peerId == 6818271084
    }
    
}

