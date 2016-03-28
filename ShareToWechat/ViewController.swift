//
//  ViewController.swift
//  ShareToWechat
//
//  Created by tutujiaw on 16/3/28.
//  Copyright © 2016年 tujiaw. All rights reserved.
//

import UIKit

class ViewController: UITableViewController,
                    UITextFieldDelegate,
                    UINavigationControllerDelegate,
                    UIImagePickerControllerDelegate,
                    NSURLConnectionDataDelegate
{
    @IBOutlet weak var inputWebAddress: UITextField!
    @IBOutlet weak var webImage: UIImageView!
    @IBOutlet weak var webTitle: UITextField!
    var url: NSURL! = NSURL()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        inputWebAddress.delegate = self
        webTitle.delegate = self
        
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 20))
        header.backgroundColor = UIColor.clearColor()
        tableView.tableHeaderView = header
        
        webImage.userInteractionEnabled = true
        let singleTap = UITapGestureRecognizer(target: self, action: "webImageClicked")
        webImage.addGestureRecognizer(singleTap)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func recognizeClicked(sender: UIButton) {
        var text: String! = inputWebAddress.text
        guard text != nil else { return }
        text = text.trimmed()
        guard !text.isEmpty() else { return }

        if text.indexOf("http") == nil {
            text = "http://" + text
        }
        inputWebAddress.text = text
        url = NSURL(string: text)!
        let request = NSURLRequest(URL: url)
        let conn = NSURLConnection(request: request, delegate: self)
        if (conn != nil) {
            print("connect success")
        } else {
            print("connect failed")
        }
    }
    
    func setTitleImage(url: NSURL) -> Bool {
        let nsData = NSData(contentsOfURL: url)
        if let data = nsData {
            let faviconImage = UIImage(data: data)
            let newSize = CGSize(width: 50, height: 50)
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
            faviconImage?.drawInRect(CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            webImage.image = newImage
            return true
        }
        return false
    }
    
    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        let html = String(data: data, encoding: NSUTF8StringEncoding)?.lowercaseString
        print(html)
        let start = html?.indexOf("<title>")
        let end = html?.indexOf("</title>")
        if let start = start, end = end {
            let title = html?.substring(start + 7, length: end - start - 7)
            webTitle.text = title
        }
        
        var startIndex = 0
        var linkList = [String]()
        repeat {
            if let start = html?.indexOf("<link", fromIndex: startIndex) {
                startIndex = start
                if let end = html?.indexOf(">", fromIndex: startIndex) {
                    startIndex = end
                    var link: String! = html?.substring(start + 5, length: end - start - 5)
                    if link == nil {
                        break
                    }
                    link = link.trimmed()
                    if !link.isEmpty() {
                        linkList.append(link!)
                    }
                } else {
                    break
                }
            } else {
                break
            }
        } while(true)
        
        var faviconList = [String]()
        let addFaviconPath = { (path: String) -> Void in
            let urlComp = NSURLComponents()
            urlComp.scheme = self.url?.scheme
            urlComp.host = self.url?.host
            urlComp.path = path
            if let faviconUrl = urlComp.URL {
                faviconList.append(faviconUrl.absoluteString)
            }
        }
        
        for link in linkList {
            if link.indexOf("rel=\"shortcut icon\"") == nil && link.indexOf("rel=\"icon\"") == nil {
                continue
            }
            
            if let start = link.indexOf("href=\"") {
                if let end = link.indexOf("\"", fromIndex: start + 6) {
                    let favicon = link.substring(start + 6, length: end - start - 6)
                    if !favicon.isEmpty() {
                        if favicon.indexOf("http") == nil {
                            addFaviconPath(favicon)
                        } else {
                            faviconList.append(favicon)
                        }
                    }
                }
            }
        }
        addFaviconPath("/favicon.ico")
        for favicon in faviconList {
            if setTitleImage(NSURL(string: favicon)!) {
                break;
            }
        }
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func webImageClicked() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .PhotoLibrary
        imagePicker.delegate = self
        self.presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?) {
        webImage.image = image
    }
    
    @IBAction func detailClicked(sender: UIButton) {
        inputWebAddress.resignFirstResponder()
        webTitle.resignFirstResponder()
        
        let sheet = UIAlertController(title: "文章 ", message: "分享到微信", preferredStyle: .ActionSheet)
        let cancelAction = UIAlertAction(title: "取消", style: .Cancel, handler: {(action) -> Void in
            print("cancel share")
        })
        let shareToFriend = UIAlertAction(title: "好朋友", style: .Destructive, handler: {(action) -> Void in
            self.shareToWChat(WXSceneSession)
        })
        let shareToGroupsFriends = UIAlertAction(title: "朋友圈", style: .Destructive, handler: {(action) -> Void in
            self.shareToWChat(WXSceneTimeline)
        })
        let favorite = UIAlertAction(title: "收藏", style: .Default, handler: {(action) -> Void in
            self.shareToWChat(WXSceneFavorite)
        })
        
        sheet.addAction(cancelAction)
        sheet.addAction(shareToFriend)
        sheet.addAction(shareToGroupsFriends)
        sheet.addAction(favorite)
        self.presentViewController(sheet, animated: true, completion: {() -> Void in
            print("present over")
        })
    }
    
    func shareToWChat(scene: WXScene) {
        let page = WXWebpageObject()
        page.webpageUrl = self.url.absoluteString
        
        let msg = WXMediaMessage()
        msg.mediaObject = page
        msg.title = webTitle.text
        //msg.description = ""
        msg.setThumbImage(webImage.image)
        
        let req = SendMessageToWXReq()
        req.message = msg
        req.scene = Int32(scene.rawValue)
        WXApi.sendReq(req)
    }
    
    
}



