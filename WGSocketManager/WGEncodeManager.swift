//
//  WGEncodeManager.swift
//  Demo
//
//  Created by VS on 23/01/2017.
//  Copyright © 2017 JianWei. All rights reserved.
//

import UIKit

class WGEncodeManager: NSObject {

    /**
     * 加密数据
     * 参数 data 要加密的数据
     * 参数 encodeType 加密类型 1 -> 异或加密
     * 返回 加密后的数据
     */
    static func write(data: Data, encodeType: UInt8, encodeKey: String) -> Data {
        
        var newData = data
        
        // 如果是异或加密
        if encodeType == 1 {
            
            // 把消息体转成字节数组
            let dataByteArr = [UInt8](data)
            
            // 把密钥转成字节数组
            let encodeKeyByteArr = [UInt8](encodeKey.utf8)
            
            // 开始加/解密
            var newDataByteArr = [UInt8]()
            for (index, beforeByte) in dataByteArr.enumerated() {
                let keyByte = encodeKeyByteArr[index % encodeKeyByteArr.count]
                let afterByte = beforeByte ^ keyByte
                newDataByteArr.append(afterByte)
            }
            // 把加密后的字节数组转回成消息体
            newData = Data(bytes: newDataByteArr)
        }
        return newData;
    }
    
    /**
     * 解密数据
     * 参数 data 要解密的数据
     * 参数 encodeType 加密类型 1 -> 异或加密
     * 返回 解密后的数据
     */
    static func read(data: Data, encodeType: UInt8, encodeKey: String) -> Data {
        
        var newData = data
        
        // 如果是异或加密
        if encodeType == 1 {
            
            newData = write(data: newData, encodeType: encodeType, encodeKey: encodeKey)
        }
        return newData
    }
}
