//
//  WGDataManager.swift
//  Demo
//
//  Created by VS on 23/01/2017.
//  Copyright © 2017 JianWei. All rights reserved.
//

import UIKit

class WGDataManager: NSObject {

    /**
     * 数据 -> 二进制数据
     * 参数 data 要转换的数据(Array / Dictionary)
     * 参数 dataType 数据类型 1 -> JSON
     * 返回 二进制数据
     */
    static func write(data: Any, dataType: UInt8) -> Data? {
    
        var newData: Data?
        
        // 如果是JSON格式
        if dataType == 1 && (data is [Any] || data is [String: Any]) {
            
            newData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        }
        return newData
    }
    
    /**
     * 二进制数据 -> 数据
     * 参数 data 二进制数据
     * 参数 dataType 数据类型 1 -> JSON
     * 返回 数据(Array / Dictionary)
     */
    static func read(data: Data, dataType: UInt8) -> Any? {
    
        var newData: Any?
        
        // 如果是JSON格式
        if dataType == 1 {
            
            newData = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
        }
        return newData;
    }
}
