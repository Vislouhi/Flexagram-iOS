//
//  StorageFlx.swift
//  Flexatar
//
//  Created by Matey Vislouh on 29.04.2024.
//

import Foundation
public enum TaskType{
    case add
    case remove
}
public struct StorageTask{
    public var peerId:Int64
    public var endpoint:String
    public var type:TaskType
}
public enum FlxContentType:String{
    case video = "video"
    case photo = "photo"
}
public class StorageFlx{
    
    
    public static func getFilePath(name:String)->String?{
   
        let mainBundle = Bundle(for: MetalResProviderFlx.self)
        guard let path = mainBundle.path(forResource: "FlexatarMetalSourcesBundle", ofType: "bundle") else {
 
            fatalError("FLX_INJECT flexatar metal source bundle not found")
           
        }
        guard let bundle = Bundle(path: path) else {

            fatalError("FLX_INJECT bundle at path not found")
        }
        let fileUrl = bundle.path(forResource: name, ofType: "dat")
        return fileUrl
    }
    
    public static var listPhotoBuiltin =  Array(5...6).map({Bundle.main.path(forResource: "x00_char\($0 % 7 + 1)t", ofType: "flx")})
        
    public static let listVideoBuiltin = [0].map{getFilePath(name: "built_in_video\($0)")}
    
    public static func folderExists(folderName:String) -> Bool{
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = documentsURL.appendingPathComponent(folderName)
        let fileManager = FileManager.default
        let path:String
        if #available(iOS 16.0, *) {
            path = folderURL.path()
        } else {
            path = folderURL.path

        }
        
        return fileManager.fileExists(atPath: path)
    }
    
    public static func getStorageFolder(folderName:String,flxType:FlxContentType) -> String{
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        let folderURL = documentsURL.appendingPathComponent(folderName).appendingPathComponent(flxType.rawValue)
        let fileManager = FileManager.default
        let path:String
        if #available(iOS 16.0, *) {
            path = folderURL.path()
        } else {
            path = folderURL.path

        }
        
        let defaults = UserDefaults.standard
//        try! fileManager.removeItem(at: folderURL)
        
        if !fileManager.fileExists(atPath: path) {
            print("FLX_INJECT path not exists \(path)")
            try! fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            let paths = flxType  == .photo ? listPhotoBuiltin : listVideoBuiltin
           
            var idList:[String] = []
            for (idx,path) in paths.enumerated(){
                let flxId = "builtin_\(idx)"
                
                let srcUrl = URL(fileURLWithPath: path!)
                let dstUrl = folderURL.appendingPathComponent("\(flxId).flx")
                try! fileManager.copyItem(at: srcUrl, to: dstUrl)
                idList.append(flxId)
            }
            let key = "\(folderName)_\(flxType.rawValue)"
//            let idListReversed:[String] = idList.reversed()
            defaults.set(idList, forKey: key)
//            if let strArr = defaults.stringArray(forKey: key){
//                print("FLX_INJECT string array \(strArr)")
//            }else{
//                print("FLX_INJECT string array not found")
//            }
            
        }else{
            print("FLX_INJECT path exists \(path)")
        }
        return path
        
    }
    
    public static func getFileList(folderName:String,flxType:FlxContentType,accoiuntPeerId:Int64) -> [String]{
        let defaults = UserDefaults.standard
        let key = "\(folderName)_\(flxType.rawValue)"
        let files = defaults.stringArray(forKey: key)!
        if let result = Backend.result(for: accoiuntPeerId), result == "FAIL"{
            return files.filter{$0.hasPrefix("built")}.map{"\($0).flx"}
        }
        return files.map{"\($0).flx"}
        
    }
    public static var storageDidChange:((TaskType,FlxContentType,String)->())?
    
    public static func removeFromStorage(fid:String,peerId:Int64){
        print("FLX_INJECT removing \(fid)")
        let userStorageFolder = "flx_storage_\(peerId)"
        let keyVideo = "\(userStorageFolder)_video"
        let keyPhoto = "\(userStorageFolder)_photo"
        let filesFolderPhoto = StorageFlx.getStorageFolder(folderName: userStorageFolder, flxType: .photo)
        let filesFolderVideo = StorageFlx.getStorageFolder(folderName: userStorageFolder, flxType: .video)
        
        let defaults = UserDefaults.standard
        var filesFolder = filesFolderVideo
        var fidFound = false
        var flxType = FlxContentType.video
keyLoop:for key in [keyVideo,keyPhoto]{
            var flxIds = defaults.stringArray(forKey: key)!
            if flxIds.contains(fid) {
                if key == keyPhoto{
                    filesFolder = filesFolderPhoto
                    flxType = .photo
                }
                fidFound = true
                flxIds.removeAll(where: {$0 == fid})
                defaults.set(flxIds, forKey: key)
                break keyLoop
            }
        }
        if !fidFound {return}
        
        let fileManager = FileManager.default
        let dstUrl = URL(fileURLWithPath: filesFolder, isDirectory: true).appendingPathComponent("\(fid).flx")
        try? fileManager.removeItem(at: dstUrl)
        storageDidChange?(.remove,flxType,dstUrl.getPath())
        
    }
    public static func addToStorage(url:URL,peerId:Int64){
        let userStorageFolder = "flx_storage_\(peerId)"
        print("FLX_INJECT userStorageFolder \(userStorageFolder)")
        let filesFolderPhoto = StorageFlx.getStorageFolder(folderName: userStorageFolder, flxType: .photo)
        let filesFolderVideo = StorageFlx.getStorageFolder(folderName: userStorageFolder, flxType: .video)
        
//        let userDefaultsDict = UserDefaults.standard.dictionaryRepresentation()
            

//        for (key, value) in userDefaultsDict {
//            if let array = value as? [String] {
//                print("FLX_INJECT avalabale keys \(key), val \(array)")
//            }
//        }
        
        let keyVideo = "\(userStorageFolder)_video"
        let keyPhoto = "\(userStorageFolder)_photo"
        let defaults = UserDefaults.standard
        let fid = String(url.lastPathComponent.split(separator: ".")[0])
        
        for key in [keyVideo,keyPhoto]{
            let flxIds = defaults.stringArray(forKey: key)!
            if flxIds.contains(fid) {
                return
            }
        }

        
        let meta = MetaDataFlexatar(withPreviewImage: false, atPath: url.getPath())
        let flxType:FlxContentType
        let filesFolder:String
        if let type = meta.flxInfo?.type, type == "video"{
            flxType = .video
            filesFolder = filesFolderVideo
        }else{
            flxType = .photo
            filesFolder = filesFolderPhoto
            
        }
        
        
        let key = "\(userStorageFolder)_\(flxType.rawValue)"
        
        let fileManager = FileManager.default
   
        
        let srcUrl = url
        let dstUrl = URL(fileURLWithPath: filesFolder, isDirectory: true).appendingPathComponent("\(fid).flx")
        try! fileManager.moveItem(at: srcUrl, to: dstUrl)
        let flxIds = [fid] + defaults.stringArray(forKey: key)!
        defaults.set(flxIds, forKey: key)
        storageDidChange?(.add,flxType,dstUrl.getPath())
        
    }
    
    private static let storageQueue = DispatchQueue(label: "com.flexatar.storage")
    private static let storageAsyncQueue = DispatchQueue(label: "com.flexatar.storageasync")
    private static var taskList:[StorageTask] = []
    public static func addTask(task:StorageTask){
        storageQueue.sync {
            taskList.append(task)
            if taskList.count == 1 {
                
                fulfillTasks()
            }
        }
    }
    
    private static func fulfillTasks(){
        if taskList.count == 0 {return}
        let currentTask = taskList[0]
        if currentTask.type == .add {
            Backend.addDownloadTask(currentTask)
        }else if currentTask.type == .remove {
            taskList.remove(at: 0)
            let fid = String(BotEvents.extractSubstringAfterLastSlash(from: currentTask.endpoint).split(separator: ".")[0])
            removeFromStorage(fid: fid, peerId: currentTask.peerId)
            fulfillTasks()
        }
        
    }
    public static func downloadFinished(url:URL?,task:StorageTask){
        storageQueue.sync {
            taskList.remove(at: 0)
            if let url = url {
                addToStorage(url: url, peerId: task.peerId)
            }
            fulfillTasks()
            print("FLX_INJECT download finished")
        }
        
        
        
    }
}

extension URL{
    public func getPath()->String{
        if #available(iOS 16.0, *) {
            return self.path()
        } else {
            return self.path

        }
    }
}
