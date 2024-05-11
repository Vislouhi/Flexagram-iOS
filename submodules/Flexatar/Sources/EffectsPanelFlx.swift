//
//  EffectsPanelFlx.swift
//  Flexatar
//
//  Created by Matey Vislouh on 27.04.2024.
//
import AsyncDisplayKit
import Display
import Foundation
import ItemListUI
import ComponentFlow
//import CallComponents
//class Table: ListViewItem, ItemListItem  {
//    
//}
public class EffectsPanelFlxImageView:UIView{
    private let backgrondLayer : RoundedCornersView
    private let flxHorizontalScrollView : HorizontalScrollChooseFlxView
    private let closeButton : UIImageView
    
    private let buttonSize:CGFloat = 36.0
    private var tapGestureRecognizer:UITapGestureRecognizer?
    public var closeAction:(()->Void)?
    
    public init() {
        self.backgrondLayer = RoundedCornersView(color: UIColor(red: 0, green: 0, blue: 0, alpha: 0.5), smoothCorners: true)
        self.backgrondLayer.update(cornerRadius: 12.0, transition: .immediate)
        self.flxHorizontalScrollView = HorizontalScrollChooseFlxView(items:StorageFlx.list,chooser: ChooserFlx.photoFlexatarChooser)
        self.closeButton = UIImageView(frame: CGRect())
        super.init(frame: CGRect())
        self.closeButton.backgroundColor = .white
        self.closeButton.layer.masksToBounds = true
        self.closeButton.layer.cornerRadius = buttonSize/2
        self.closeButton.image =  generateTintedImage(image:UIImage(bundleImageName: "Call/close"),color:.black)
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.closeButtonPressed(tapGestureRecognizer:)))
        self.closeButton.addGestureRecognizer(tapGestureRecognizer!)
        self.closeButton.isUserInteractionEnabled = true
        self.backgroundColor = .clear
        self.addSubview(self.backgrondLayer)
        self.addSubview(self.flxHorizontalScrollView)
        self.addSubview(self.closeButton)
    }
    
    @objc func closeButtonPressed(tapGestureRecognizer: UITapGestureRecognizer)
    {
        print("FLX_INJECT closeButtonPressed")
        self.closeAction?()
    }
    
    public func update(transition:Transition,frame:CGRect){
        let scrollWidth = frame.size.width * 0.95
        let scrollInset = (frame.size.width - scrollWidth)/2
        
        var scrollRect = CGRect(origin: CGPoint(x:scrollInset,y:scrollInset), size: CGSize(width: scrollWidth, height: 100))
        let iconHeight = self.flxHorizontalScrollView.update(frame: scrollRect, transition: transition)
        
        var tmpFrame = CGRect(origin: CGPoint(), size: frame.size)
        var tmpFrame1 = frame
        scrollRect.size.height = iconHeight + scrollInset * 2
        tmpFrame.size.height = scrollRect.size.height
        tmpFrame1.size.height = tmpFrame.size.height

        let buttonPadding:CGFloat = 12.0
        
        let buttonStartPoint = CGPoint(x:scrollRect.size.width - buttonSize-buttonPadding ,y:tmpFrame.size.height+buttonPadding )
        let buttonRect = CGRect(origin: buttonStartPoint, size: CGSize(width: buttonSize, height: buttonSize))
        transition.setFrame(view:self.closeButton, frame: buttonRect)
        let additionalHeight = buttonRect.size.height + buttonPadding*2
        tmpFrame.size.height+=additionalHeight
        tmpFrame1.size.height+=additionalHeight
        transition.setFrame(view:self, frame: tmpFrame1)
        transition.setFrame(view:self.backgrondLayer, frame: tmpFrame)
        
//        self.backgrondLayer.frame = CGRect(origin: CGPoint(), size: frame.size)
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
                                        
                                        
public class EffectsPanelFlxNode:ASDisplayNode{
    private let flexatarScrollNode:HorizontalScrollChooseFlxNode
    private let closeButtonNode:ImageButtonFlxNode
    private let buttonSize:CGFloat = 36.0
    public var closeAction:(()->Void)?{
        set{
            self.closeButtonNode.pressed = newValue
        }
        get{
            return self.closeButtonNode.pressed
        }
    }
    public override init() {
        self.flexatarScrollNode = HorizontalScrollChooseFlxNode(items:StorageFlx.list,chooser: ChooserFlx.photoFlexatarChooser)
        self.closeButtonNode = ImageButtonFlxNode()
        super.init()
        self.cornerRadius = 11.0
        self.clipsToBounds = true
        self.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        
        
        self.addSubnode(self.flexatarScrollNode)
        self.flexatarScrollNode.backgroundColor = .clear
        self.flexatarScrollNode.makeNodes()
        
        self.closeButtonNode.image =  generateTintedImage(image:UIImage(bundleImageName: "Call/close"),color:.black)
        self.closeButtonNode.imageNode.backgroundColor = .white
        self.closeButtonNode.imageNode.cornerRadius = buttonSize/2.0
        self.closeButtonNode.imageNode.clipsToBounds = true
        
        self.addSubnode( self.closeButtonNode)
    }
    
    public func update(frame: CGRect,isLandscape:Bool, transition: ContainedViewLayoutTransition) ->CGFloat{
        let scrollFrame = CGRect(origin: CGPoint(), size: frame.size)
        let flxScrollHeight = self.flexatarScrollNode.update(frame: scrollFrame, isLandscape: isLandscape, transition: transition)
        
        let buttonPadding:CGFloat = 12.0
        
        let buttonStartPoint = CGPoint(x:scrollFrame.size.width - buttonSize-buttonPadding ,y:scrollFrame.size.height+buttonPadding )
        let buttonRect = CGRect(origin: buttonStartPoint, size: CGSize(width: buttonSize, height: buttonSize))
        self.closeButtonNode.update(frame: buttonRect, transition: transition)
        
        
        
        return flxScrollHeight + buttonSize+buttonPadding*2
//        transition.updateFrame(node: self.flexatarScrollNode, frame: frame)
    }
}
