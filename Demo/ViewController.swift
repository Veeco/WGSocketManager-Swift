//
//  ViewController.swift
//  Demo
//
//  Created by VS on 23/01/2017.
//  Copyright © 2017 JianWei. All rights reserved.
//

import UIKit

class ViewController: UIViewController, WGSocketManagerDelegate {

    // 内容输出控件
    @IBOutlet weak var contentTextView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        WGSocketManager.manager.delegate = self
    }

    /**
     * 监听link按钮点击
     */
    @IBAction func link() {
        
        let host = "192.168.1.123"
        let port = 6666
        
        WGSocketManager.manager.connectToServerWith(IP: host, andPort: port)
    }

    /**
     * 监听send按钮点击
     */
    @IBAction func send() {
        
        let dic = ["name": "Veeco"]
        
        WGSocketManager.manager.sendDataToServerWith(data: dic)
    }
    
    /**
     * 监听cut按钮点击
     */
    @IBAction func cut() {
        
        WGSocketManager.manager.disconnectToServer()
    }
    
    /**
     * 监听clear按钮点击
     */
    @IBAction func clear() {
        
        contentTextView.text = nil
    }
}

extension ViewController {
    
    // MARK: - <WGSocketManagerDelegate>
    
    /**
     * 代理方法1. 与服务器连接成功时会调用
     * 参数 socketManager 本管理者
     */
    func connectSucceededToServerWith(socketManager: WGSocketManager) {
        
        contentTextView.text = contentTextView.text + "\n" + "连接成功"
    }
    
    /**
     * 代理方法2. 接收到服务器发送的数据时会调用
     * 参数 socketManager 本管理者
     * 参数 data 所收到的数据(NSArray / NSDictionary)
     * 参数 dataLength 所收到的数据长度(字节)
     */
    func socketManager(_ socketManager: WGSocketManager, receiveData data: Any?, dataLength: Int) {
        
        if let dic = data {
            contentTextView.text = contentTextView.text + "\n" + "收到数据字节长度为" + String(dataLength) + "\n" + String(describing: dic)
        }
    }
    
    /**
     * 代理方法3. 与服务器连接失败时会调用(试图与不存在的服务器连接时也会调用)
     * 参数 socketManager 本管理者
     */
    func connectFailedToServerWith(socketManager: WGSocketManager) {
        
        contentTextView.text = contentTextView.text + "\n" + "连接失败"
    }
}
