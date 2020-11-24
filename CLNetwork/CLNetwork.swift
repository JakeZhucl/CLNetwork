//
//  CLNetworkingSwift.swift
//  xbqb
//
//  Created by 朱成龙 on 2018/2/6.
//  Copyright © 2018年 Wenzhou Gongchengshi Technology Co., Ltd. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import HandyJSON
import YYCache
import SVProgressHUD
import MJRefresh

let Domain = "https://www.****.com"

let CLVersion = "1.0.0"

let App_Name = "****"

class CLNetWorkModel: HandyJSON {
    var info : JSON?
    var status : Int = 0
    var msg : String?
    
    required init() {
        
    }
}

typealias CLSuccessDataBlock = ((_ successData : Data,_ isCache : Bool) -> Void)?
typealias CLSuccessBlock = ((_ successData : JSON,_ successModel : CLNetWorkModel?,_ isCache : Bool) -> Void)?
typealias CLFailBlock = ((_ failError : NSError) -> Void)?

//MAKR: - 基类
class CLNetwork {
    
    private class func FILE(URLString : String,
                            parameter : [String:String?]? = nil,
                            file : [Data]? = nil,
                            successDataBlock : CLSuccessDataBlock = nil,
                            failBlock:CLFailBlock = nil,
                            errorShow : Bool = true,
                            isWait : Bool = true){
        
        let url = "\(Domain)\(URLString)"
        
        let requestParameter = addPostParameters(parameters: parameter)
        
        if isWait {
            SVProgressHUD.setDefaultMaskType(.clear)
            SVProgressHUD.show()
        }
        
        var header = HTTPHeaders()
        
//        addHeaderDefault(header: &header)
        
//        if Account.isLogin() {
//            addHeaderAfterLogin(header: &header)
//        }

        AF.upload(multipartFormData: { (formData) in
            if let file = file {
                for i in 0..<file.count {
                    formData.append(file[i], withName: "file[]", fileName: "file.png", mimeType: "png")
                }
            }
            
            for (key,value) in parameter ?? [:] {
                if let data = value?.data(using: .utf8) {
                    formData.append(data, withName: key)
                }
            }
            
        }, to: url, headers: header).response { (response) in
            if isWait {
                SVProgressHUD.dismiss()
                SVProgressHUD.setDefaultMaskType(.none)
            }
            
            dealWithResponseData(URLString: URLString, parameter: requestParameter, response: response, successDataBlock: successDataBlock, failBlock: failBlock, errorShow: errorShow)
        }
    }
    
    private class func request(URLString : String,
                               method : HTTPMethod = .post,
                               parameter : [String:String?]? = nil,
                               successDataBlock : CLSuccessDataBlock = nil,
                               failBlock:CLFailBlock = nil,
                               isCache : Bool = false,
                               errorShow : Bool = true,
                               scrollView : UIScrollView? = nil,
                               isWait : Bool = false) -> DataRequest{
        
        let url = "\(Domain)\(URLString)"
        
        let cache = YYCache(name: "\(App_Name)_network")
        
        let cacheURL = netWorkCacheURL(url: url, parameters: parameter)
        
        if isCache && cache?.containsObject(forKey: cacheURL) ?? false {
            let object = cache?.object(forKey: cacheURL)
            if object is Data && object != nil && successDataBlock != nil {
                successDataBlock!(object as! Data,true)
            }
        }
        
        let requestParameter = addPostParameters(parameters: parameter)
        
        var header = HTTPHeaders()
        
//        addHeaderDefault(header: &header)
        
//        if Account.isLogin() {
//            addHeaderAfterLogin(header: &header)
//        }
        
        if isWait {
            SVProgressHUD.setDefaultMaskType(.clear)
            SVProgressHUD.show()
        }
        
        return AF.request(url , method: method, parameters: requestParameter,headers: header).response { (response) in
            
            if isWait {
                SVProgressHUD.dismiss()
                SVProgressHUD.setDefaultMaskType(.none)
            }
            
            endRefresh(scrollview: scrollView, isCache: false)
            
            dealWithResponseData(URLString: url, parameter: requestParameter, response: response, cacheURL: cacheURL, cache: cache, successDataBlock: successDataBlock, failBlock: failBlock, errorShow: errorShow, isCache: isCache)
        }
    }
}

//MARK: - 使用的方法
extension CLNetwork {
    
    /// 读取缓存本地的接口数据 若本地没有数据则请求接口.
    /// - Parameters:
    ///   - URLString: 接口地址.
    ///   - parameter: 参数.
    ///   - successBlock: 成功回调
    ///   - errorUnShowStatus: 设置要显示的错误code数组.
    ///   - update: 是否直接请求接口更新数据 默认是false 不请求接口.
    open class func LoadCache(URLString : String,
                              parameter : [String:String?]? = nil,
                              successBlock : CLSuccessBlock = nil,
                              errorUnShowStatus : [Int] = [],
                              update : Bool = false) {
        let url = "\(Domain)\(URLString)"
        
        let cache = YYCache(name: "\(App_Name)_network")
        
        let cacheURL = netWorkCacheURL(url: url, parameters: parameter,isLog: false)
        
        if cache?.containsObject(forKey: cacheURL) ?? false &&
            !update {
            let object = cache?.object(forKey: cacheURL)
            if object is Data && object != nil && successBlock != nil {
                dealWithResponseJSON(URLString: URLString, parameter: parameter, successData: object as! Data, successBlock: successBlock, errorUnShowStatus: errorUnShowStatus, isCache: true)
            }
        }else{
            POST(URLString: URLString, parameter: parameter, successBlock: successBlock, errorUnShowStatus : errorUnShowStatus, isCache: true)
        }
    }
    
    @discardableResult
    open class func GET(URLString : String,
                        parameter : [String:String?]? = nil,
                        successBlock : CLSuccessBlock = nil,
                        failBlock:CLFailBlock = nil,
                        errorUnShowStatus : [Int] = [],
                        isCache : Bool = false,
                        errorShow : Bool = true,
                        scrollView : UIScrollView? = nil,
                        isWait : Bool = false) -> DataRequest{
        
        return request(URLString: URLString,method: .get, parameter: parameter, successDataBlock: { (successData, isCache) in
            dealWithResponseJSON(URLString: URLString, parameter: parameter, successData: successData, successBlock: successBlock, failBlock: failBlock, errorShow: errorShow, errorUnShowStatus: errorUnShowStatus, isCache: isCache, scrollView: scrollView)
        }, failBlock: failBlock, isCache: isCache, errorShow: errorShow,scrollView: scrollView,isWait: isWait)
    }
    
    /// POST请求
    /// - Parameters:
    ///   - URLString: 请求路径.
    ///   - parameter: 请求参数.
    ///   - successBlock: 成功回调.
    ///   - failBlock: 失败回调.
    ///   - isCache: 是否缓存到本地 默认不缓存.
    ///   - errorShow: 是否打印错误信息 默认打印.
    ///   - scrollView: 自动停止刷新scrollview的mjrefresh.
    ///   - isWait: 是否显示展位图禁止操作.
    ///   - errorUnShowStatus: 设置要显示的错误code数组.
    /// - Returns: 请求对象，用于停止请求，监听请求.
    @discardableResult
    
    open class func POST(URLString : String,
                         parameter : [String:String?]? = nil,
                         successBlock : CLSuccessBlock = nil,
                         failBlock : CLFailBlock = nil,
                         errorUnShowStatus : [Int] = [],
                         isCache : Bool = false,
                         errorShow : Bool = true,
                         scrollView : UIScrollView? = nil,
                         isWait : Bool = false) -> DataRequest{
        return request(URLString: URLString, parameter: parameter, successDataBlock: { (successData, isCache) in
            dealWithResponseJSON(URLString: URLString, parameter: parameter, successData: successData, successBlock: successBlock, failBlock: failBlock, errorShow: errorShow, errorUnShowStatus: errorUnShowStatus, isCache: isCache, scrollView: scrollView)
        }, failBlock: failBlock, isCache: isCache,errorShow: errorShow,scrollView: scrollView,isWait: isWait)
    }
    
    /// 表单请求.
    /// - Parameters:
    ///   - URLString: 请求路径.
    ///   - parameter: 参数.
    ///   - file: 文件数组.
    ///   - successBlock: 成功回调.
    ///   - failBlock: 失败回调.
    ///   - errorUnShowStatus: 错误
    ///   - errorUnShowStatus: 设置要显示的错误code数组.
    ///   - isWait: 是否遮蔽页面禁止操作.
    open class func FILE(URLString : String,
                         parameter : [String:String?]? = nil,
                         file : [Data],
                         successBlock : CLSuccessBlock = nil,
                         failBlock:CLFailBlock = nil,
                         errorUnShowStatus : [Int] = [],
                         errorShow : Bool = true,
                         isWait : Bool = false) {
        FILE(URLString: URLString, parameter: parameter, file: file, successDataBlock: { (successData, isCache) in
            dealWithResponseJSON(URLString: URLString, parameter: parameter, successData: successData, successBlock: successBlock, failBlock: failBlock, errorShow: errorShow, errorUnShowStatus: errorUnShowStatus, isCache: isCache, scrollView: nil)
        }, failBlock: failBlock, errorShow: errorShow, isWait: isWait)
    }
}

//MARK: - 配置处理
extension CLNetwork {
    
    /// 处理data为JSON和Model对象.
    /// - Parameters:
    ///   - URLString: 接口请求地址.
    ///   - parameter: 请求参数.
    ///   - successData: 需要处理的data.
    ///   - successBlock: 成功回调.
    ///   - failBlock: 失败回调.
    ///   - errorShow: 是否打印输出 默认为true 输出.
    ///   - errorUnShowStatus: 设置要显示的错误code数组.
    ///   - isCache: 是否缓存 默认为false 不缓存.
    private class func dealWithResponseJSON(URLString : String,
                                            parameter : [String:String?]? = nil,
                                            successData : Data,
                                            successBlock : CLSuccessBlock = nil,
                                            failBlock : CLFailBlock = nil,
                                            errorShow : Bool = true,
                                            errorUnShowStatus : [Int],
                                            isCache : Bool = false,
                                            scrollView : UIScrollView? = nil) {
        do {
            
            let successJSON = try JSON(data: successData)
              
            let successModel = CLNetWorkModel.deserialize(from: successJSON.dictionaryObject)
            successModel?.info = successJSON["info"]
            switch successModel?.status {
            /// 请求成功.
            case 1:
                if successBlock != nil {
                    successBlock!(successJSON,successModel,false)
                }
            /// 登录问题.
            case 2, 3, 4:
                if !isCache {
                    let error_ns = NSError(domain: "登录失效,请重新登录", code: -1003, userInfo: nil)
                    
                    if errorShow {
                        SVProgressHUD.showError(withStatus: error_ns.localizedDescription)
                        SVProgressHUD.dismiss(withDelay: 2)
                    }
                    
                    if failBlock != nil {
                        failBlock!(error_ns)
                    }
                    
                    DispatchQueue.main.async {
//                        if Account.gotoLogin() {
//                            Account.logout()
//                        }
                    }
                }
            default:
                if !isCache {
                    var code = -1004
                    
                    if let s_code = successModel?.status {
                        code = s_code
                    }
                    
                    let s_status = errorUnShowStatus.first(where: { (s_code) -> Bool in
                        return s_code == code
                    })
                    
                    let error_ns = NSError(domain: successModel?.msg ?? "", code: code, userInfo: nil)
                    
                    if s_status == nil && errorShow {
                        SVProgressHUD.showError(withStatus: successModel?.msg ?? "")
                        SVProgressHUD.dismiss(withDelay: 2)
                    }
                    
                    if failBlock != nil {
                        failBlock!(error_ns)
                    }
                }
            }
        }catch {
            if !isCache {
                let error_ns = NSError(domain: "请检查网络情况，若仍有请联系客服。", code: -1002, userInfo: nil)
                if errorShow {
                    SVProgressHUD.showError(withStatus: error_ns.localizedDescription)
                    SVProgressHUD.dismiss(withDelay: 2)
                }
                print("json解析失败:")
                print("\(Domain)\(URLString)")
                print(addPostParameters(parameters: parameter))
                print(error.localizedDescription)
                print(String(data: successData, encoding: .utf8) ?? "")
                
                if failBlock != nil{
                    failBlock!(error_ns)
                }
            }
        }
    }
    
    
    /// 处理接口是否请求成功、缓存.
    /// - Parameters:
    ///   - URLString: 接口地址.
    ///   - parameter: 参数.
    ///   - response: 接口请求返回的数据.
    ///   - cacheURL: 缓存地址.
    ///   - cache: 缓存类的实例化对象.
    ///   - successDataBlock: 成功回调.
    ///   - failBlock: 失败回调.
    ///   - errorShow: 是否输出error信息，默认true 输出.
    ///   - isCache: 是否缓存.
    private class func dealWithResponseData(URLString : String,
                                            parameter : [String:String?]? = nil,
                                            response : AFDataResponse<Data?>,
                                            cacheURL : String? = nil,
                                            cache : YYCache? = nil,
                                            successDataBlock : CLSuccessDataBlock = nil,
                                            failBlock : CLFailBlock = nil,
                                            errorShow : Bool = true,
                                            isCache : Bool = false) {
        
        if response.error == nil &&
            successDataBlock != nil &&
            response.data != nil {
            if isCache && cacheURL != nil && cache != nil {
                cache?.setObject(response.data! as NSCoding, forKey: cacheURL!)
            }
            successDataBlock!(response.data!, false)
        }else{
            let error = NSError(domain: Domain, code: -1001, userInfo: ["info":"请检查网络情况，若仍有请联系客服。"])
            if errorShow {
                SVProgressHUD.showError(withStatus: error.userInfo["info"] as? String ?? "")
                SVProgressHUD.dismiss(withDelay: 2)
            }
            print("网络请求直接失败error:")
            print(URLString)
            print(addPostParameters(parameters: parameter))
            print(response.error?.localizedDescription ?? "")
            
            if failBlock != nil{
                failBlock!(error)
            }
        }
    }
    
    
    /// 添加请求的header的默认参数.
    private class func addHeaderDefault(header : inout HTTPHeaders) {
        header.add(name: "device_type", value: "iOS")
        header.add(name: "version_name", value: CLVersion)
        header.add(name: "app_name", value: App_Name)
    }
    
    /// 添加请求的header中登录的参数.
    private class func addHeaderAfterLogin(header : inout HTTPHeaders) {
//        header.add(name: "Authorization", value: Account.account().access_token!)
    }
    
    
    /// 添加默认参数.
    private class func addPostParameters( parameters : [String:String?]?) -> [String:String]{
        
        var newParameters = [String:String]()
        newParameters["device_type"] = "iOS"
        newParameters["version_name"] = CLVersion
        newParameters["app_name"] = App_Name
//        newParameters["membertoken"] = Account.account().access_token
        if let install_code_ip_bind_id = UserDefaults.standard.value(forKey: "install_code_ip_bind_id") as? String {
            newParameters["install_code_ip_bind_id"] = install_code_ip_bind_id
        }
        
        if parameters == nil {
            return newParameters
        }else{
            for (key,value) in parameters!{
                newParameters[key] = value
            }
            return newParameters
        }
    }
    
    /// 生成缓存的key.
    /// - Parameters:
    ///   - url: 路径.
    ///   - parameters: 参数.
    ///   - isLog: 是否打印日志.
    /// - Returns: 缓存的key.
    private class func netWorkCacheURL(url : String,
                                       parameters : [String:String?]?,
                                       isLog : Bool = true) -> String{
        
        let addParameters = self.addPostParameters(parameters: parameters)
        
        if(isLog){
            print(url)
            print(addParameters.CLDictionaryToJsonString())
        }
        
        let parametersKeys = addParameters.keys.sorted { (num1 , num2) -> Bool in
            return num1 < num2
        }
        
        var cacheString = ""
        for key in parametersKeys {
            //            if key != "lat" && key != "lng" {
            cacheString += "\(key)\(String(describing: addParameters[key]))"
            //            }
        }
        
        return "\(url)\(cacheString)"
    }
    
    
    /// 结束刷新.
    /// - Parameters:
    ///   - scrollview: scrollview的子类都可以
    ///   - isCache: 是否缓存
    private class func endRefresh(scrollview : UIScrollView?,
                                  isCache : Bool){
        if !isCache && scrollview != nil {
            scrollview!.mj_header?.endRefreshing()
            scrollview!.mj_footer?.endRefreshing()
        }
    }
}

extension Dictionary{
    
    /// 字典转JSON字符串.
    func CLDictionaryToJsonString() -> String {
        if (!JSONSerialization.isValidJSONObject(self)) {
            print("无法解析出JSONString")
            return ""
        }
        let data : NSData! = try! JSONSerialization.data(withJSONObject: self, options: []) as NSData?
        let JSONString = NSString(data:data as Data,encoding: String.Encoding.utf8.rawValue)
        return JSONString! as String
    }
}


extension UITableView {
    
    /// 处理tableview的刷新问题.
    /// - Parameters:
    ///   - dataArray: 目标数据数组.
    ///   - page: 页码.
    ///   - array: 接口请求返回数组.
    func endRefresh<T>( dataArray : inout [T],
                        page : Int,
                        array : [T?]?) -> Void {
        
        var new = [T]()
        
        if let old = array as? [T] {
            new = old
        }
        
        if page == 1 {
            dataArray = new
        }else{
            dataArray.append(contentsOf: new)
        }
        
        if new.isEmpty {
            self.mj_footer?.endRefreshingWithNoMoreData()
        }else{
            self.mj_footer?.endRefreshing()
        }
        
        self.mj_header?.endRefreshing()
        
        self.mj_footer?.isHidden = dataArray.isEmpty

    }
}
