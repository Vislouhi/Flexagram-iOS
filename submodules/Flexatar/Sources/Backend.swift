//
//  Backend.swift
//  Flexatar
//
//  Created by Matey Vislouh on 10.06.2024.
//

import Foundation

public enum ContentType:String{
    case json = "application/json"
    case data = "application/octet-stream"
}
public struct ApigwResponse:Codable{
    public var result:String
    public var interval:Int?
    public var route:String?
    public var token:String?
    
}

public class Backend{
    public static let tempToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NDk1NTYyMTIsIm5iZiI6MTcxODAyMDIxMiwidGFnIjoidGciLCJ1c2VyIjoiNjM1MDQxMzcxMSIsImFwcCI6InRnIiwidmVyIjoiYW5kcm9pZC00NDgwIiwiY291bnRyeSI6IktaIn0.A3ep7yknox6cQC6kQOHYXNZdDyUhV5A1xWoMP2RjlI4"
    public static let tempRoute = "https://mhpblvwwrb.execute-api.us-east-1.amazonaws.com/test1"
    
    public static func request( accountId: Int64, endpoint:String, completion:@escaping(Data,Bool)->(), fail:@escaping()->(), method:String = "POST", body:Data? = nil, contentType:ContentType? = nil, accept:ContentType? = nil){
        if let route = route(for: accountId),let token = token(for:accountId){
            request(route: route, endpoint: endpoint, token: token, completion: completion, fail: fail, method:method, body:body, contentType:contentType, accept:accept)
        } else{
            DispatchQueue.global().async {
                fail()
            }
        }
        
    }
    
    public static func request(route:String,endpoint:String,token:String, completion:@escaping(Data,Bool)->(), fail:@escaping()->(), method:String = "POST", body:Data? = nil, contentType:ContentType? = nil, accept:ContentType? = nil){
        let urlString = "\(route)/\(endpoint)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body = body {
            request.httpBody = body
        }
        if let contentType = contentType {
            request.setValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")
        }
        if let accept = accept {
            request.setValue(accept.rawValue, forHTTPHeaderField: "Accept")
        }
//        request.httpBody
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error making request: \(error)")
                fail()
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (httpResponse.statusCode == 200 || httpResponse.statusCode == 206) else {
                print("Unexpected response: \(String(describing: response))")
                fail()
                return
            }

            guard let data = data else {
                print("No data received")
                fail()
                return
            }
            completion(data,httpResponse.statusCode == 200)
            
            // Handle the response data
//            do {
//                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
//                    print("Response JSON: \(jsonResponse)")
//                }
//            } catch {
//                print("Error parsing JSON: \(error)")
//            }
        }
        task.resume()
    }
    
    public static func token(for accountId:Int64) -> String?{
        let defaults = UserDefaults.standard
        return defaults.string(forKey: "flexatar_token_for_\(accountId)")
    }
    public static func botToken(for accountId:Int64) -> String?{
        let defaults = UserDefaults.standard
        return defaults.string(forKey: "bot_token_for_\(accountId)")
    }
    public static func result(for accountId:Int64) -> String?{
        let defaults = UserDefaults.standard
        return defaults.string(forKey: "flexatar_result_for_\(accountId)")
    }
    
    public static func route(for accountId:Int64) -> String?{
        let defaults = UserDefaults.standard
        return defaults.string(forKey: "flexatar_route_for_\(accountId)")
    }
    public static func interval(for accountId:Int64) -> Int?{
        let defaults = UserDefaults.standard
        return defaults.integer(forKey: "flexatar_interval_for_\(accountId)")
    }
    private static func saveApigwResponse(accountId:Int64,response:ApigwResponse){
        let defaults = UserDefaults.standard
        if response.result != "FAIL" {
            defaults.set(response.result, forKey: "flexatar_result_for_\(accountId)")
            
            if let token = response.token {
                defaults.set(token,forKey: "flexatar_token_for_\(accountId)")
            }
            if let route = response.route {
                defaults.set(route,forKey: "flexatar_route_for_\(accountId)")
            }
            if let interval = response.interval {
                defaults.set(interval,forKey: "flexatar_interval_for_\(accountId)")
            }

        }else{
            defaults.set(response.result, forKey: "flexatar_result_for_\(accountId)")
        }
    }
    
    public static let forcedAuth = false
    public static var flexatarTokenReady : (()->())?
    public static func getToken(tempTocken:String,accountId:Int64,completion:((Bool)->())?=nil){
        if #available(iOS 14.0, *) {
            let verifyUrl = "https://wq4zud6mobacgs4wvkpf4gc5bi0utlta.lambda-url.us-east-1.on.aws"
//            let challenge = UUID().uuidString
            AppAttest.start(challenge: tempTocken, completion:{ attestation, keyId in
//                print("FLX_INJECT attestation : \(attestation)")
//                print("FLX_INJECT tempTocken : \(tempTocken)")
                struct Send:Codable{
                    var key_id:String
                    var attestation:String
                    var version:Int
                }
                let send = Send(key_id: keyId, attestation: attestation, version: VersionControl.currentVersion)
                guard let sendData = try? JSONEncoder().encode(send) else { return }
                
                request(route: verifyUrl, endpoint: "", token: tempTocken, completion: { data, _ in
                    
                    let decoder = JSONDecoder()
                    if let response = try? decoder.decode(ApigwResponse.self, from: data){
                        
                        var firstVerify = false
                        if let _ = token(for: accountId){}else{firstVerify=true}
                        saveApigwResponse(accountId: accountId, response: response)
                        print("FLX_INJECT token ApigwResponse \(response)")
                        print("FLX_INJECT token result \(result(for: accountId)!)")
                        if let result = result(for: accountId), result == "RETRY"{
                            print("FLX_INJECT request verify ")
                            verify(accountId: accountId,completion: {isOk, _ in
                                print("FLX_INJECT verify finished \(isOk)")
                                if firstVerify {
                                    flexatarTokenReady?()
                                }
                                completion?(isOk)
                            })
                        }else{
                            completion?(false)
                        }
                    }else{
                        completion?(false)
                    }
                    print("FLX_INJECT received token \(String(data: data, encoding: .utf8)!)")
                }, fail: {completion?(false)},body: sendData,contentType:.json)
            } ,error:{completion?(false)})
        }
    }
    public static func verify(accountId:Int64,completion:((Bool,String?)->())?=nil){
        request(accountId:accountId,endpoint: "verify", completion: { data, lastPart in
            print("FLX_INJECT data len \(data.count) last part \(lastPart)")
//            do {
//                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
//                        print("Response JSON: \(jsonResponse)")
//                    }
//                } catch {
//                    print("Error parsing JSON: \(error)")
//                }
            let decoder = JSONDecoder()
            if let apigwResponce = try? decoder.decode(ApigwResponse.self, from: data){
                saveApigwResponse(accountId: accountId, response: apigwResponce)
                print("FLX_INJECT verify responce \(apigwResponce)")
                completion?(true,apigwResponce.result)
            }else{
                print("FLX_INJECT decoder failed")
                completion?(false,nil)
            }
        }, fail: {completion?(false,nil)})
    }
    public static func download(accountId:Int64,endpoint:String, completion:@escaping(URL)->(), fail:@escaping()->(), part:Int=0, data:Data = Data()){
        let fid = BotEvents.extractSubstringAfterLastSlash(from: endpoint).split(separator: ".")[0]
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent("\(fid).flx")
        
        request(accountId:accountId,endpoint: "\(endpoint)?part=\(part)",
                completion: { currentData, lastPart in
            let newData = data + currentData
            if lastPart {
                do {
                    try newData.write(to: fileURL)
                    print("FLX_INJECT download complete data len \(newData.count)")
                    completion(fileURL)
                } catch {
                    fail()
                }
                
            }else{
                download(accountId:accountId,endpoint: endpoint, completion: completion, fail: fail,part:part+1,data: newData)
                
            }
            
        }, fail: {
            fail()
        },method:"GET",accept: .data)
    }
    
    public static let downloatTaskQueue = DispatchQueue(label: "com.flexatar.downloadtask")
    public static var downloatTasks:[StorageTask] = []
   
    
    public static func addDownloadTask(_ task:StorageTask){
        
        downloatTaskQueue.sync{
            let endpoint = task.endpoint
            if downloatTasks.contains(where: {$0.endpoint == endpoint}){
                return
            }
            let fid = BotEvents.extractSubstringAfterLastSlash(from: endpoint).split(separator: ".")[0]
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileURL = tempDirectory.appendingPathComponent("\(fid).flx")
            if FileManager.default.fileExists(atPath: fileURL.getPath()){
                print("FLX_INJECT file already exists at url: \(fileURL)")
                DispatchQueue.global().async {
                    StorageFlx.downloadFinished(url: fileURL,task:task)
                }
                
                return
            }
            downloatTasks.append(task)
            if downloatTasks.count == 1 {
                initiateDownload()
            }
        }
    }
    private static func initiateDownload(){
        if downloatTasks.count == 0 {return}
        let currentTask = downloatTasks[0]
        let currentEndpoint = currentTask.endpoint
        
   
        Backend.download(accountId:currentTask.peerId, endpoint: currentEndpoint, completion: {url in
            print("FLX_INJECT download file saved to url: \(url)")
            StorageFlx.downloadFinished(url: url,task:currentTask)
            downloatTaskQueue.sync{
                downloatTasks.remove(at: 0)
                initiateDownload()
            }
        }, fail: {
            print("FLX_INJECT download fail")
            StorageFlx.downloadFinished(url: nil,task:currentTask)
            downloatTaskQueue.sync{
                downloatTasks.remove(at: 0)
                initiateDownload()
            }
        })
    }
}
