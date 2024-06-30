//
//  PreviewController.swift
//  Flexatar
//
//  Created by Matey Vislouh on 30.06.2024.
//

import Foundation
import Display
import UIKit

public class FlxPreviewController: ViewController {
    private let container : UIView = UIView(frame: CGRect())
    private let closeButton = UIImageView(frame: CGRect())
    private let buttonSize:CGFloat = 36.0
    
    public init(accountId:Int64,ftar:String){
        super.init(navigationBarPresentationData: nil)
        
        self.container.backgroundColor = .black
        print("FLX_INJECT ftar \(ftar))")
        
        self.closeButton.backgroundColor = .white
        self.closeButton.layer.masksToBounds = true
        self.closeButton.layer.cornerRadius = buttonSize/2
        self.closeButton.image = generateTintedImage(image:UIImage(bundleImageName: "Call/close"),color:.black)
        self.closeButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.closeButtonPressed(_:))))
        self.closeButton.isUserInteractionEnabled = true
        
    }
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    open override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        self.container.frame = self.view.frame
        self.lockedOrientation = .portrait
        self.lockOrientation = true
        self.closeButton.frame = CGRect(x: 20, y: 30, width: buttonSize, height: buttonSize)
        
    }
    @objc func closeButtonPressed(_ sender: UITapGestureRecognizer)
    {

        self.lockOrientation = false
        self.dismiss()
        
    }
}
