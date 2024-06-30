//
//  VersionControl.swift
//  Flexatar
//
//  Created by Matey Vislouh on 16.06.2024.
//


import Foundation

public class VersionControl{
    public static let currentVersion = 4480
    public static func checkVersionChanged(accointPeerId:Int64){
        let key = "version_for_\(accointPeerId)"
        let defaults = UserDefaults.standard
        let storedVersion = defaults.integer(forKey: key)
        if storedVersion == 0{
            defaults.set(currentVersion, forKey: key)
            print("FLX_INJECT save verison")
        }else{
            if currentVersion != storedVersion {
               
                if let tempToken = Backend.botToken(for: accointPeerId){
                    print("FLX_INJECT start request new token")
                    Backend.getToken(tempTocken: tempToken, accountId: accointPeerId) { isOk in
                        if isOk {
                            defaults.set(currentVersion, forKey: key)
                            print("FLX_INJECT token refreshed")
                        }else{
                            print("FLX_INJECT token refresh failed")
                        }
                   
                        
                    }
                
                }
            }else{
                print("FLX_INJECT version not changed")
            
        
                let dateKey = "flx_date_for_\(accointPeerId)"
                if let retrievedDate = defaults.object(forKey: dateKey) as? Date {
                    print("FLX_INJECT retrieved Date: \(retrievedDate)")
                    let nowDate = Date()
                    let intervalInSeconds = nowDate.timeIntervalSince(retrievedDate)
                    print("FLX_INJECT passed \(intervalInSeconds) seconds")
                    if let interval = Backend.interval(for: accointPeerId){
                        if intervalInSeconds > Double(interval*24*60*60){
                            Backend.verify(accountId: accointPeerId) { isOk,result in
                                if isOk {
                                    print("FLX_INJECT verify ok setting new current date")
                                    if result != "FAIL"{
                                        let currentDate = Date()
                                        defaults.set(currentDate, forKey: dateKey)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    print("FLX_INJECT version check date not found setting current")
                    let currentDate = Date()
                    defaults.set(currentDate, forKey: dateKey)
                }
            }
        }
            
        
    }
}
