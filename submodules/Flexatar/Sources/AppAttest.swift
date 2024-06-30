//
//  AppAttest.swift
//  Flexatar
//
//  Created by Matey Vislouh on 03.06.2024.
//

import Foundation
import DeviceCheck
import Security
import CryptoKit

class KeychainManager {
    
    static let shared = KeychainManager()
    private init() {}
    
    // Save key to Keychain
    func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item before adding the new one
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // Retrieve key from Keychain
    func retrieve(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject? = nil
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        
        return nil
    }
    
    // Delete key from Keychain
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}

@available(iOS 14.0, *)
public class AppAttest{
    public static let dcAppAttestService = DCAppAttestService.shared
    public static func start(challenge:String, completion:@escaping(String,String)->(), error:@escaping()->()){
        var tryCounter = 0
        getKeyId (completion:{ keyId in
            print("FLX_INJECT key id : \(keyId)")
//            let challenge = UUID().uuidString
            
            print("FLX_INJECT challenge : \(challenge)")
            certifyAppAttestKey(
                challenge: challenge.data(using: .utf8)!,
                keyId: keyId,completion: { attestation in
                    completion(attestation.base64EncodedString(),keyId)
                    
                }, error: {
                    if tryCounter == 0 {
                        print("FLX_INJECT attestation error trying new key")
                        _ = KeychainManager.shared.delete(key: keyIdKey)
                        start(challenge: challenge, completion: completion, error: error)
                        tryCounter+=1
                    }else{
                        print("FLX_INJECT attestation error trying new key not helps")
                    }
                })

        }, error: {
            print("FLX_INJECT key id error")
        })

    }

    static func certifyAppAttestKey(challenge: Data, keyId: String,completion:@escaping(Data)->(),error:@escaping()->()) {
       

        let hashValue = Data(SHA256.hash(data: challenge))

        // This method contacts Apple's server to retrieve an attestation object for the given hash value
        dcAppAttestService.attestKey(keyId, clientDataHash: hashValue) { attestation, error1 in
            guard error1 == nil else {
                print("FLX_INJECT attestation error \(error1!.localizedDescription)")
                error()
                return
            }

            guard let attestation = attestation else {
                error()
                return
            }
            completion(attestation)

        }
    }
    static let keyIdKey = "appAttestKey"
    static func getKeyId(completion:@escaping(String)->(),error:@escaping()->()){
        guard let keyData = KeychainManager.shared.retrieve(key: keyIdKey) else{
            dcAppAttestService.generateKey(completionHandler: { keyId, error1 in

                guard let keyId = keyId else {
                    print("key generate failed: \(String(describing: error1))")
                    error()
                    return
                }

                // Cache the keyId for use at a later time.
                guard let keyData = keyId.data(using: .utf8) else{
                    error()
                    return
                }
                let success = KeychainManager.shared.save(key: keyIdKey, data: keyData)
                if success {
                    completion(keyId)
                }else{
                    error()
                }
                    
            })
            return
        }
        guard let retrievedKeyId = String(data: keyData, encoding: .utf8) else {
            fatalError("FLX_INJECT unable decode keyid")
        }
        completion(retrievedKeyId)
    }


}
