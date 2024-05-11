//
//  ChooserFlx.swift
//  Flexatar
//
//  Created by Matey Vislouh on 26.04.2024.
//

import Foundation

public class ChooserFlx{
    public static var photoFlexatarChooser = ChooserFlx()
    
    private var _path1: String
    private var _path2: String

    public var path1: String {
        get {
            return _path1
        }
        set(newValue) {
            if newValue != _path1{
                _path2 = _path1
                _path1 = newValue
                FrameProvider.renderEngine?.loadFlexatar(path: _path1)
            }
            print("FLX_INJECT path1 \(_path1)")
            print("FLX_INJECT path2 \(_path2)")
        }
    }

    public var path2: String {
        get {
            return _path2
        }
        set(newValue) {
            _path2 = newValue
        }
    }
    
    init(){
        _path1 = Bundle.main.path(forResource: "x00_char6t", ofType: "flx")!
        _path2 = Bundle.main.path(forResource: "x00_char7t", ofType: "flx")!
    }
    
}
