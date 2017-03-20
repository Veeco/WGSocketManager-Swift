# WGSocketManager-Swift
iOS实现Socket长连接

#搭建环境
1. 将下载后的WGSocketManager文件夹拖进工程中
2. 导入libz库(用于压缩处理)
3. 创建与OC的桥接文件并导入头文件WGCompressManager.h即可(本来这一步不需要的, 压缩这一块用Swift真不知道该怎么写, 原谅我吧...)

#基本使用
1.设置WGSocketManager单例对象的代理并遵守WGSocketManagerProtocol协议
```swift
WGSocketManager.manager.delegate = self

class ViewController: UIViewController, WGSocketManagerDelegate
```
2.直接调用WGSocketManager单例对象的连接方法即可与服务器实现长连接
```swift
let host = "192.168.1.123"
let port = 6666
        
WGSocketManager.manager.connectToServerWith(IP: host, andPort: port)
```
3.实现WGSocketManager的代理方法1. 与服务器连接成功时会调用
```swift
/**
 * 代理方法1. 与服务器连接成功时会调用
 * 参数 socketManager 本管理者
 */
 func connectSucceededToServerWith(socketManager: WGSocketManager) {
        
     contentTextView.text = contentTextView.text + "\n" + "连接成功"
 }
```
4.此时可以调用WGSocketManager单例对象的发送方法向服务器发送数据(数据类型只能是`Array`或`Dictionary`)
```swift
let dic = ["name": "Veeco"]
        
WGSocketManager.manager.sendDataToServerWith(data: dic)
```
5.实现WGSocketManager的代理方法2. 收到服务器发出的数据时会调用
```swift
/**
 * 代理方法2. 接收到服务器发送的数据时会调用
 * 参数 socketManager 本管理者
 * 参数 data 所收到的数据(Array / Dictionary)
 * 参数 dataLength 所收到的数据长度(字节)
 */
 func socketManager(_ socketManager: WGSocketManager, receiveData data: Any?, dataLength: Int) {
        
     if let tempData = data {
         contentTextView.text = contentTextView.text + "\n" + "收到数据字节长度为" + String(dataLength) + "\n" + String(describing: tempData)
     }
 }
```
6.实现WGSocketManager的代理方法3. 与服务器连接失败时会调用(试图与不存在的服务器连接时也会调用)
```swift
/**
 * 代理方法3. 与服务器连接失败时会调用(试图与不存在的服务器连接时也会调用)
 * 参数 socketManager 本管理者
 */
 func connectFailedToServerWith(socketManager: WGSocketManager) {
        
         contentTextView.text = contentTextView.text + "\n" + "连接失败"
 }
```
7.调用WGSocketManager单例对象的中断方法即可与服务器断开长连接
```swift
// 断开连接
WGSocketManager.manager.disconnectToServer()
```
8.调用WGSocketManager单例对象的以下属性可以获取所消耗流量信息
```swift
// 总共发送数据量(单位:M)
var sentTotalData:Double = 0
// 总共接收数据量(单位:M)
var gotTotalData:Double = 0
```
#注意点
由于流的特性, 我们很难准确无误地获取服务器返回的数据(反之亦然), 特别是数据连发或网络不好的时候, 会出现多条数据连着一起收到的情况(当然也会有1条数据分成多段收到的情况), 所以我们必须在每一条数据前加上数据长度的信息, 这样接收方在接收到数据后就可以准确无误地截取并且解析了. 这里我是把每条数据的前7个字节用来放辅助信息的, 下面会作详细说明:
* 前4个字节合起来(即32位下的Int)表示每条数据的字节长度 `注意这里的长度是把前7个字节也一并算上的`
* 第5个字节表示数据类型, 暂时只支持一种类型 `1 -> JSON`
* 第6个字节表示加密类型(当然密钥也是需要的) `0 -> 无加密 1 -> 异或加密`
* 第7个字节表示压缩类型 `0 -> 无压缩 1 -> ZIP压缩`

>关于第5, 6, 7个字节的设置, 可以在WGSocketManager.swift顶部的常量中修改
```swift
// 数据类型 1 -> JSON
let kDataType = 1
// 加密类型 0 -> 无加密 1 -> 异或加密
let kEncodeType = 0
// 压缩类型 0 -> 无压缩 1 -> ZIP压缩
let kCompressType = 0
// 密钥
let kEncodeKey = "Veeco"
```

* 这里需要强调的是, 服务器也必须遵循这个`7个字节`原则才能进行正常交流(当时同事使用Java写的服务器, 用AIO)

##第一次做关于Socket的项目, 难免有幼嫩的地方, 请大家多多指点, 谢谢!
