//
//  WGSocketManager.swift
//  Demo
//
//  Created by VS on 23/01/2017.
//  Copyright © 2017 JianWei. All rights reserved.
//

import UIKit

// 数据类型             1 -> JSON
let kDataType = 1
// 加密类型 0 -> 无加密 1 -> 异或加密
let kEncodeType = 0
// 压缩类型 0 -> 无压缩 1 -> ZIP压缩
let kCompressType = 0
// 密钥
let kEncodeKey = "Veeco"

@objc protocol WGSocketManagerDelegate: NSObjectProtocol {
    
    /**
     * 代理方法1. 与服务器连接成功时会调用
     * 参数 socketManager 本管理者
     */
    @objc optional func connectSucceededToServerWith(socketManager: WGSocketManager)
    
    /**
     * 代理方法2. 接收到服务器发送的数据时会调用
     * 参数 socketManager 本管理者
     * 参数 data 所收到的数据(Array / Dictionary)
     * 参数 dataLength 所收到的数据长度(字节)
     */
    @objc optional func socketManager(_ socketManager: WGSocketManager, receiveData data: Any?, dataLength: Int)
    
    /**
     * 代理方法3. 与服务器连接失败时会调用(试图与不存在的服务器连接时也会调用)
     * 参数 socketManager 本管理者
     */
    @objc optional func connectFailedToServerWith(socketManager: WGSocketManager)
}

class WGSocketManager: NSObject, StreamDelegate {
    
    // MARK: - <属性>
    
    // .h

    // 类属性单例
    static let manager = WGSocketManager()
    private override init() {}
    // 代理
    weak var delegate: WGSocketManagerDelegate?
    // 总共发送数据量(单位:M)
    var sentTotalData:Double = 0
    // 总共接收数据量(单位:M)
    var gotTotalData:Double = 0
    
    // .m
    
    // 输入流
    private var inputStream: InputStream?
    // 输出流
    private var outputStream: OutputStream?
    // 未读取数据
    private var tempReadData = Data()
    // 单次接收数据长度(服务器告知)
    private var readDataLength = 0
    // 单次发送数据长度(告知服务器)
    private var writeDataLength = 0
    // 未成功发出数据
    private var tempWriteData: Data?
    // 串行子队列
    private lazy var sSubQueue: DispatchQueue = { DispatchQueue(label: "sSubQueue") }()
    // 是否已连接成功
    private var connected = false
    
    // MARK: - <方法>
    
    // .h
    
    /**
     * 与服务器连接
     * 参数 IP 服务器地址
     * 参数 port 服务器端口
     */
    func connectToServerWith(IP: String, andPort port: Int) {

        // 每次连接前先断开与服务器的连接
        disconnectToServer()
        
        // 异步到串行子队列操作
        sSubQueue.async {

            // 过滤
            if IP.lengthOfBytes(using: .utf8) == 0 || port == 0 { return }
            
            // 定义C语言输入输出流
            var readStream:Unmanaged<CFReadStream>?
            var writeStream:Unmanaged<CFWriteStream>?
            
            // 创建连接
            CFStreamCreatePairWithSocketToHost(nil, IP as CFString!, UInt32(port), &readStream, &writeStream)
            
            // 把C语言的输入输出流转化成Swift对象
            self.inputStream = readStream?.takeRetainedValue()
            self.outputStream = writeStream?.takeRetainedValue()
            
            if self.inputStream != nil && self.outputStream != nil {
            
                // 设置代理
                self.inputStream?.delegate = self
                self.outputStream?.delegate = self
                
                // 把输入输入流添加到主运行循环(不添加主运行循环, 代理有可能不工作)
                self.inputStream?.schedule(in: .main, forMode: .defaultRunLoopMode)
                self.outputStream?.schedule(in: .main, forMode: .defaultRunLoopMode)
                
                // 打开输入输出流
                self.inputStream?.open()
                self.outputStream?.open()
            }
        }
    }
    
    /**
     * 断开与服务器的连接
     */
    func disconnectToServer() {
        
        // 异步到串行子队列操作
        sSubQueue.async {
            
            // 过滤
            if !self.connected { return }
            
            // 清空缓存数据
            self.tempReadData = Data()
            self.tempWriteData = nil
            self.readDataLength = 0
            
            // 关闭输入输出流
            self.inputStream?.close()
            self.outputStream?.close()
            
            // 从主运行循环移除
            self.inputStream?.remove(from: .main, forMode: .defaultRunLoopMode)
            self.outputStream?.remove(from: .main, forMode: .defaultRunLoopMode)
            
            // 重置状态
            self.connected = false
        }
    }
    
    /**
     * 向服务器发送数据
     * 参数 data 要发送的内容数据(Array / Dictionary)
     */
    func sendDataToServerWith(data: Any) {
        
        // 异步到串行子队列操作
        sSubQueue.async {

            // 过滤
            if !self.connected { return }

            // 获取要发送的二进制数据
            let sendData = self.getSendDataFrom(originData: data)
            
            // sendData 不为空时才往下执行
            if let newSendData = sendData {
            
                // 发送数据
                self.sendDataToServerWith(data: newSendData)
            }
        }
    }
    
    // .m
    
    // MARK: - <转换相关处理>
    
    /**
     * int类型 -> Byte类型数组
     * 参数 intValue int类型
     * 返回 转换后的Byte类型数组
     */
    private func convertToByteFrom(intValue: Int) -> [UInt8] {
        
        let byte1 = UInt8((intValue >> 24) & 255)
        let byte2 = UInt8((intValue >> 16) & 255)
        let byte3 = UInt8((intValue >> 8) & 255)
        let byte4 = UInt8(intValue & 255)
        
        return[byte1, byte2, byte3, byte4]
    }
    
    /**
     * Byte类型数组 -> int类型
     * 参数 byteArr Byte类型数组
     * 返回 int类型
     */
    private func convertToIntFromByteArr(byteArr: [UInt8]) -> Int {
        
        let byte1 = Int(byteArr[0])
        let byte2 = Int(byteArr[1])
        let byte3 = Int(byteArr[2])
        let byte4 = Int(byteArr[3])
        
        return byte1 << 8 | byte2 << 8 | byte3 << 8 | byte4
    }
    
    // MARK: - <发送相关处理>
    
    /**
     * 根据要发送的内容数据获取要发送的二进制数据
     * 参数 data 要发送的内容数据(Array / Dictionary)
     * 返回 要发送的二进制数据
     */
    private func getSendDataFrom(originData: Any) -> Data? {
    
        // 设置数据类型
        let dataType = UInt8(kDataType);
        
        // 设置加密方式
        let encodeType = UInt8(kEncodeType);
        
        // 设置压缩方式
        let compressType = UInt8(kCompressType);
        
        // 获取要发送的主体二进制数据
        let bodyData = getDataWith(dataType: dataType, encodeType: encodeType, compressType: compressType, data: originData)
        
        // bodyData 不为空时才往下执行
        if let newBodyData = bodyData {
        
            // 把要发送的主体信息数据长度转成字节数组
            var headArr = convertToByteFrom(intValue: newBodyData.count + 7)
            
            // 以字节数组形式设置头部数据
            headArr += [dataType, encodeType, compressType]
            
            // 转换成头部数据
            var headData = Data(bytes: headArr)
            
            // 拼接数据
            headData.append(newBodyData)
            
            return headData
        }
        return nil
    }
    
    /**
     * 根据一系列参数获取要发送的主体二进制数据
     * 参数 dataType 数据类型
     * 参数 encodeType 加密类型
     * 参数 compressType 回缩类型
     * 参数 data 要发送的内容数据(Array / Dictionary)
     * 返回 要发送的主体二进制数据
     */
    private func getDataWith(dataType: UInt8, encodeType: UInt8, compressType: UInt8, data: Any) -> Data? {
    
        var newData: Data?
        
        // 1. 转换格式
        newData = WGDataManager.write(data: data, dataType: dataType)

        // 2. 加密处理
        if let tempData = newData {
            newData = WGEncodeManager.write(data: tempData, encodeType: encodeType, encodeKey: kEncodeKey)
        }
        // 3. 压缩处理
        if let tempData = newData {
            newData = WGCompressManager.write(with: tempData, andCompressType: compressType)
        }
        return newData;
    }
    
    /**
     * 向服务器发送数据
     * 参数 data 要发送的二进制数据
     */
    private func sendDataToServerWith(data: Data) {
    
        // 如果要发送的数据长度为0 直接return
        if data.count == 0 {return}
        
        // 记录要发送的数据长度
        writeDataLength = data.count
        
        // 发送数据 并获取实际发送数据字节长度
        var writedDataLength: Int?
        _ = data.withUnsafeBytes {
            
            writedDataLength = self.outputStream?.write($0, maxLength: data.count)
        }
        // 增加判断以防异常崩溃
        if (writedDataLength == -1) { return }
        
        // 如果未能完全发出 缓存未发送数据
        if writedDataLength != nil && writedDataLength != data.count {
            
            tempWriteData = data.subdata(in: writedDataLength!..<data.count)
        }
        // 否则清空缓存未发送数据
        else {
            
            self.tempWriteData = nil;
        }
    }
    
    // MARK: - <接收相关处理>
    
    /**
     * 读取服务器发出的数据
     */
    private func readData() {
        
        // 建立一个缓冲区 可以放1024个字节
        var buffer = [UInt8](repeating: 0, count: 1024)
        
        // 接收数据 并获取实际获取数据字节长度
        let readDataLength = inputStream?.read(&buffer, maxLength: buffer.count)
        
        // 增加判断以防异常崩溃
        if (readDataLength == -1) { return }
        
        if let newReadDataLength = readDataLength {
        
            // 从缓冲区中抽出数据并叠加
            let data = Data(bytes: buffer, count: newReadDataLength)
            tempReadData.append(data)
            
            // 分析数据
            analyseData()
        }
    }
    
    /**
     * 分析数据
     */
    private func analyseData() {
    
        // 未处理数据不为空时才往下进行
        if tempReadData.count != 0 {
        
            // 数据字节长度小于4则返回
            if tempReadData.count < 4 { return }
        
            // 1. 获取数据真实字节长度
            if readDataLength == 0 {
                
                var byteArr = [UInt8](repeating: 0, count: 4)
                tempReadData.copyBytes(to: &byteArr, count: byteArr.count)
                readDataLength = convertToIntFromByteArr(byteArr: byteArr)
            }
            // 如果还没接收完全或者被告知长度不大于7则返回(注意:不能把 < 换成 != 因为有可能会把下一条数据也读进来)
            if tempReadData.count < readDataLength || readDataLength <= 7 { return }
            
            // 解析辅助信息
            var assistantArr = [UInt8](repeating: 0, count: 3)
            tempReadData.copyBytes(to: &assistantArr, from: 4..<4 + assistantArr.count)
            
            // 2. 获取数据类型
            let dataType = assistantArr[0]
            
            // 3. 获取加密方式
            let encodeType = assistantArr[1]
            
            // 4. 获取压缩方式
            let compressType = assistantArr[2]
            
            // 5. 解析正式数据
            let regularData = tempReadData.subdata(in: 7..<readDataLength)
            disposeDataWith(dataType: dataType, encodeType: encodeType, compressType: compressType, bodyData: regularData)
            
            // 6. 处理有可能接收到的下一条数据
            if tempReadData.count > readDataLength {
                
                // 缓存下一条数据
                tempReadData = tempReadData.subdata(in: readDataLength..<tempReadData.count)
            
                readDataLength = 0
                
                // 递归分析数据
                analyseData()
            }
            // 清空缓存数据
            else {
            
                tempReadData = Data()
                readDataLength = 0
            }
        }
    }
    
    /**
     * 处理收到的数据
     * 参数 dataType 数据类型
     * 参数 encodeType 加密方式
     * 参数 compressType 压缩方式
     * 参数 bodyData 接收到的主体数据
     */
    private func disposeDataWith(dataType: UInt8, encodeType: UInt8, compressType: UInt8 , bodyData: Data) {
    
        var newBodyData = bodyData
        
        // 1. 解压
        newBodyData = WGCompressManager.read(with: newBodyData, andCompressType: compressType)
        
        // 2. 解密
        newBodyData = WGEncodeManager.read(data: newBodyData, encodeType: encodeType, encodeKey: kEncodeKey)
        
        // 3. 转换格式
        let result = WGDataManager.read(data: newBodyData, dataType: dataType)
        
        // 更新接收流量统计
        gotTotalData += Double(readDataLength) / 1024 / 1024
        
        // 同步回主队列操作
        DispatchQueue.main.sync {
            
            // 调用代理方法2. 接收到服务器发送的数据时会调用
            if delegate != nil && delegate!.responds(to: #selector(WGSocketManagerDelegate.socketManager(_:receiveData:dataLength:))) {
            
                delegate?.socketManager?(self, receiveData: result, dataLength: readDataLength)
            }
        }
    }
    
// MARK: - <StreamDelegate>
    
    /**
     * 代理方法:监听与服务器的连接状态
     * 参数 aStream 输入输出流
     * 参数 eventCode 状态参数
     */
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        
        /*
         public static var openCompleted: Stream.Event { get }     输入输出流打开完成
         public static var hasBytesAvailable: Stream.Event { get } 有字节可读
         public static var hasSpaceAvailable: Stream.Event { get } 可以发送字节
         public static var errorOccurred: Stream.Event { get }     连接出现错误
         public static var endEncountered: Stream.Event { get }    连接结束
         */
        
        switch eventCode {
            
        // 1. 输入输出流打开完成
        case Stream.Event.openCompleted: break
            
        // 2. 有字节可读
        case Stream.Event.hasBytesAvailable:
            
            // 异步到串行子队列中读取服务器发出的数据
            sSubQueue.async {

                self.readData()
            }
            
        // 3. 可以发送字节
        case Stream.Event.hasSpaceAvailable:
            
            if !connected {
            
                // 修改连接状态
                connected = true
                
                // 调用代理方法1. 与服务器连接成功时会调用
                if delegate != nil && delegate!.responds(to: #selector(WGSocketManagerDelegate.connectSucceededToServerWith(socketManager:))) {
                    
                    delegate!.connectSucceededToServerWith!(socketManager: self)
                }
            }
            
            // 异步到串行子队列中补发未发送数据
            if tempWriteData != nil {
            
                sSubQueue.async {
                    
                    self.sendDataToServerWith(data: self.tempWriteData!)
                }
            }
                // 更新发送流量统计
            else {
            
                sentTotalData += Double(writeDataLength) / 1024 / 1024
                writeDataLength = 0
            }
            
        // 4. 连接出现错误
        case Stream.Event.errorOccurred:
            
            // 断开与服务器的长连接
            disconnectToServer()
            
            // 调用代理方法3. 与服务器连接失败时会调用(试图与不存在的服务器连接时也会调用)
            if delegate != nil && delegate!.responds(to: #selector(WGSocketManagerDelegate.connectFailedToServerWith(socketManager:))) {
                
                delegate!.connectFailedToServerWith!(socketManager: self)
            }
            
        // 5. 连接结束
        case Stream.Event.endEncountered:
            
            // 断开与服务器的长连接
            disconnectToServer()
            
            // 调用代理方法3. 与服务器连接失败时会调用(试图与不存在的服务器连接时也会调用)
            if delegate != nil && delegate!.responds(to: #selector(WGSocketManagerDelegate.connectFailedToServerWith(socketManager:))) {
                
                delegate!.connectFailedToServerWith!(socketManager: self)
            }
            
        default:
            break
        }
    }
}
