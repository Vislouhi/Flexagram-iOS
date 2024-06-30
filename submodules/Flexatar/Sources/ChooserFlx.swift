//
//  ChooserFlx.swift
//  Flexatar
//
//  Created by Matey Vislouh on 26.04.2024.
//

import Foundation
import UIKit
public protocol FlexatarEngine {
    var effectCtrl:RenderEngine.EffectCtrlProvider { get set}
    
    func loadFlexatar(path:String,effectPath:String?)
}
public class ChooserFlx{
//    public static var photoFlexatarChooser = ChooserFlx()
    public var renderEngine:FlexatarEngine?
    private var _path1: String
    private var _path2: String
    private var _videoPath: String
    public var imageDidSelected:((UIImage)->())?

    
    public var path1: String {
        get {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: _path1){
                return _path1
            }else{
                
                let keyPhoto = "\(userStorageFolder)_photo"
                let filesFolderPhoto = StorageFlx.getStorageFolder(folderName: userStorageFolder, flxType: .photo)
                let defaults = UserDefaults.standard
                let flxIds = defaults.stringArray(forKey: keyPhoto)!
                
                _path1 = Self.concatPath(filesFolderPhoto, "\(flxIds[0]).flx")
                if _path1 == _path2 {
                    _path1 = Self.concatPath(filesFolderPhoto, "\(flxIds[1]).flx")
                }
                let fileName1 = URL(string: _path1)!.lastPathComponent
                defaults.set(fileName1, forKey: "\(key)_path1")
               
                return _path1
            }
        }
        set(newValue) {
            print("FLX_INJECT path1 \(_path1)")
            print("FLX_INJECT path1 \(newValue)")
            let defaults = UserDefaults.standard
            if newValue != _path1{
                _path2 = _path1
                _path1 = newValue
                
                let fileName1 = URL(string: _path1)!.lastPathComponent
                let fileName2 = URL(string: _path2)!.lastPathComponent
                defaults.set(fileName1, forKey: "\(key)_path1")
                defaults.set(fileName2, forKey: "\(key)_path2")
                _currentTypeIdx = 1
                defaults.set(_currentTypeIdx, forKey: "\(key)_currentTypeIdx")
                renderEngine?.loadFlexatar(path: _path1,effectPath: _path2)
//                FrameProvider.renderEngine?.loadFlexatar(path: _path1,effectPath: _path2)
            }else{
                if _currentTypeIdx == 0 {
                    _currentTypeIdx = 1
                    defaults.set(_currentTypeIdx, forKey: "\(key)_currentTypeIdx")
                    renderEngine?.loadFlexatar(path: _path1,effectPath: _path2)
//                    FrameProvider.renderEngine?.loadFlexatar(path: _path1,effectPath: _path2)
                }
            }
            
            
//            print("FLX_INJECT path1 \(_path1)")
//            print("FLX_INJECT path2 \(_path2)")
        }
    }

    public var path2: String {
        get {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: _path2){
                return _path2
            }else{
                
                let keyPhoto = "\(userStorageFolder)_photo"
                let filesFolderPhoto = StorageFlx.getStorageFolder(folderName: userStorageFolder, flxType: .photo)
                let defaults = UserDefaults.standard
                let flxIds = defaults.stringArray(forKey: keyPhoto)!
                
                _path2 = Self.concatPath(filesFolderPhoto, "\(flxIds[0]).flx")
                if _path2 == _path1 {
                    _path2 = Self.concatPath(filesFolderPhoto, "\(flxIds[1]).flx")
                }
                let fileName1 = URL(string: _path2)!.lastPathComponent
                defaults.set(fileName1, forKey: "\(key)_path2")
                return _path2
            }
        }
        set(newValue) {
            _path2 = newValue
            
        }
    }
    
    public var videoPath: String {
        get {
            return _videoPath
        }
        set(newValue) {
            _videoPath = newValue
            let fileName = URL(string: _videoPath)!.lastPathComponent
            
            let defaults = UserDefaults.standard
            defaults.set(fileName, forKey: "\(key)_videoPath")
            _currentTypeIdx = 0
            defaults.set(_currentTypeIdx, forKey: "\(key)_currentTypeIdx")
            renderEngine?.loadFlexatar(path: _videoPath,effectPath: nil)
//            FrameProvider.renderEngine?.loadFlexatar(path: _videoPath)
        }
    }
    
    private var _tabIdx:Int
    public var tabIdx:Int{
        get{
            return _tabIdx
        }
        set{
            _tabIdx = newValue
            let defaults = UserDefaults.standard
            defaults.set(_tabIdx, forKey: "\(key)_tabIdx")
        }
    }
    
    private var _effectIdx:Int
    private var _currentTypeIdx:Int
    public var effectIdx:Int {
        get{
            return _effectIdx
        }
        set{
            _effectIdx = newValue
            renderEngine?.effectCtrl.effectIdx = _effectIdx
//            FrameProvider.renderEngine?.effectIdx = _effectIdx
            let defaults = UserDefaults.standard
            defaults.set(_effectIdx, forKey: "\(key)_effectIdx")
            let effectIdx = defaults.integer(forKey: "\(key)_effectIdx")
            print("FLX_INJECT effect idx \(effectIdx)")
        }
    }
    
    private var _mixWeight:Float
    public var mixWeight:Float {
        get{
            return _mixWeight
        }
        set{
            _mixWeight = newValue
            renderEngine?.effectCtrl.mixWeight =  1 - _mixWeight
//            FrameProvider.renderEngine?.mixWeight =  1 - _mixWeight
            let defaults = UserDefaults.standard
            defaults.set(_mixWeight, forKey: "\(key)_mixWeight")
        }
    }
    public func updateRenderEngine(){
        renderEngine?.effectCtrl.mixWeight =  1 - _mixWeight
        renderEngine?.effectCtrl.effectIdx = _effectIdx
    }
    
    private static var instances:[String:ChooserFlx] = [:]
    
    public static func inst(tag:String,peerId:Int64) -> ChooserFlx{
        let key = "\(tag)_\(peerId)"
        if let val = instances[key]{
            return val
        }else{
            let chooser = ChooserFlx(tag: tag, peerId: peerId)
            instances[key] = chooser
            return chooser
        }
    }
    
    public var currentPath:String{
        if _currentTypeIdx == 0 {
            return videoPath
        }else{
            return path1
        }
    }
    public var currentType: FlxContentType{
        
        return _currentTypeIdx == 0 ? .video : .photo
    }
//    init(){
    private let key:String
    private let userStorageFolder:String
    public var photoList:[String]{
        let photoFolder = StorageFlx.getStorageFolder(folderName: userStorageFolder, flxType: .photo)
        return StorageFlx.getFileList(folderName: userStorageFolder, flxType: .photo,accoiuntPeerId: accountPeerId).map{Self.concatPath(photoFolder, $0)}
    }
    public var videoList:[String]{
        let videoFolder = StorageFlx.getStorageFolder(folderName: userStorageFolder, flxType: .video)
        return StorageFlx.getFileList(folderName: userStorageFolder, flxType: .video,accoiuntPeerId: accountPeerId).map{Self.concatPath(videoFolder, $0)}
    }
    private let accountPeerId:Int64
    init(tag:String,peerId:Int64){
        accountPeerId = peerId
        userStorageFolder = "flx_storage_\(peerId)"
        let photoFolder = StorageFlx.getStorageFolder(folderName: userStorageFolder, flxType: .photo)
        let videoFolder = StorageFlx.getStorageFolder(folderName: userStorageFolder, flxType: .video)
       
        let photoPaths = StorageFlx.getFileList(folderName: userStorageFolder, flxType: .photo,accoiuntPeerId: accountPeerId).map{Self.concatPath(photoFolder, $0)}
        let videoPaths = StorageFlx.getFileList(folderName: userStorageFolder, flxType: .video,accoiuntPeerId: accountPeerId).map{Self.concatPath(videoFolder, $0)}
        
        self.key = "\(tag)_\(peerId)"

        let defaults = UserDefaults.standard
        if let p1 = defaults.string(forKey: "\(key)_path1"){
            _path1 = Self.concatPath(photoFolder, p1)
            print("FLX_INJECT paths \(photoPaths)")
            print("FLX_INJECT _path1 \(_path1)")
            if !photoPaths.contains(_path1){
                _path1 = photoPaths[0]
            }
        }else{
            print("FLX_INJECT not _path1 stored")
            _path1 = photoPaths[0]
//            _path1 = Bundle.main.path(forResource: "x00_char6t", ofType: "flx")!
        }
        if let p2 = defaults.string(forKey: "\(key)_path2"){
            _path2 = Self.concatPath(photoFolder, p2)
            if !photoPaths.contains(_path2){
                _path2 = photoPaths[1]
            }
            
        }else{
            _path2 = photoPaths[1]
        }
        if let vp = defaults.string(forKey: "\(key)_videoPath"){
            _videoPath = Self.concatPath(videoFolder, vp)
            if !videoPaths.contains(_videoPath){
                _videoPath = videoPaths[0]
            }
           
        }else{
            _videoPath = videoPaths[0]
        }
        _tabIdx = defaults.integer(forKey: "\(key)_tabIdx")
        _effectIdx = defaults.integer(forKey: "\(key)_effectIdx")
        _mixWeight = defaults.float(forKey: "\(key)_mixWeight")
        _currentTypeIdx = defaults.integer(forKey: "\(key)_currentTypeIdx")
        print("FLX_INJECT values _tabIdx \(_tabIdx) _effectIdx \(_effectIdx) _mixWeight \(_mixWeight) _currentTypeIdx \(_currentTypeIdx)")
        if _mixWeight == 0 {_mixWeight = 0.5}
        
       
    }
    public static func concatPath(_ p1:String,_ p2:String) -> String{
        return URL(fileURLWithPath: p1).appendingPathComponent(p2).getPath()
    }
    
}
