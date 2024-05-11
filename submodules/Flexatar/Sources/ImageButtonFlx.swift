//
//  ImageButtonFlx.swift
//  Flexatar
//
//  Created by Matey Vislouh on 27.04.2024.
//

import Foundation
import AsyncDisplayKit
import Display

public class ImageButtonFlxView:UIButton{
    let iconView:UIImageView
    public var pressed:(()->Void)?
    public init(frame:CGRect,image:UIImage?){
        self.iconView = UIImageView(image: image)
        self.iconView.isUserInteractionEnabled = false
        
        super.init(frame: frame)
        self.addSubview(self.iconView)
        self.addTarget(self, action: #selector(onPressed), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    @objc private func onPressed(){
        self.pressed?()
    }
    public func update(size:CGSize){
//        var iconSize = size
//        iconSize.width = iconSize.height
        self.iconView.frame = CGRect(origin: CGPoint(), size: size)
    }
}

public class ImageButtonFlxNode:ASControlNode{
    
    public var image:UIImage?{
        set{
            self.imageNode.image = newValue
        }
        get{
            return self.imageNode.image
        }
    }
    public var pressed : (()->())?
    public let imageNode:ASImageNode
    
    override public init(){
        self.imageNode = ASImageNode()
        self.imageNode.contentMode = .scaleAspectFit
        super.init()
        self.addSubnode(self.imageNode)
        self.addTarget(self,  action: #selector(buttonPressed), forControlEvents: .touchUpInside)
    }
    @objc func buttonPressed() {
        self.pressed?()
   }
    public func update(frame: CGRect, transition: ContainedViewLayoutTransition){
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(), size: frame.size))
        transition.updateFrame(node: self, frame: frame)
    }
}
