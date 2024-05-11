//
//  StorageFlx.swift
//  Flexatar
//
//  Created by Matey Vislouh on 29.04.2024.
//

import Foundation
public class StorageFlx{
    public static var list = Array(0...6).map{Bundle.main.path(forResource: "x00_char\($0 % 7 + 1)t", ofType: "flx")}
}
