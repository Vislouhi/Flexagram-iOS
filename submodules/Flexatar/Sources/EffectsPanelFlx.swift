//
//  EffectsPanelFlx.swift
//  Flexatar
//
//  Created by Matey Vislouh on 27.04.2024.
//
import AsyncDisplayKit
import Display
import Foundation
//import ItemListUI
import ComponentFlow
import TabSelectorComponent
import LegacyComponents
import ComponentDisplayAdapters
//import AccountContext

public class EffectSwitcher{
    public let tabSelector: ComponentView<Empty>
    private let tabItems: [TabSelectorComponent.Item]
    private let chooser:ChooserFlx
    public var superview:UIView?
    public var effectIndexDidSet : ((Int)->())?
    
    public init(chooser:ChooserFlx){
        self.chooser = chooser
        self.tabSelector =  ComponentView()
        let tabNames = ["No","Mix","Morph","Hybrid"]
        self.tabItems = tabNames.enumerated().map{TabSelectorComponent.Item(id: $0, title: $1)}

    }
    public func update(transition:Transition,frame:CGRect) -> CGFloat{
        let tabSelectorSize = tabSelector.update(
            transition: transition,
            component: AnyComponent(TabSelectorComponent(
                colors: TabSelectorComponent.Colors(
                    foreground: .white,
                    selection: .black.withMultipliedAlpha(0.5)
                ),
                customLayout: TabSelectorComponent.CustomLayout(
                    font: Font.medium(14.0),
                    spacing: 9.0
                ),
                items: self.tabItems,
                selectedId: self.chooser.effectIdx,
                setSelectedId: {[weak self]  id in

                    let intId = id as! Int
                    print("FLX_INJECT tab switch \(id)")
                    
                    if let self=self{
                        if (self.chooser.effectIdx != intId){
                            self.chooser.effectIdx = intId
                            _ = self.update(transition: transition, frame: frame)
                            self.effectIndexDidSet?(intId)
                            print("FLX_INJECT tab switch \(id)")
                        }
                    }

                }
            )),
            environment: {},
            containerSize: CGSize(width: frame.width, height: 44.0)
            
        )
        if let tabSelectorView = tabSelector.view {
            if tabSelectorView.superview == nil {
                self.superview?.addSubview(tabSelectorView)
            }
            
            let tabSelectorInset:CGFloat = frame.origin.y
            let tabSelectorXOfset = (frame.width - tabSelectorSize.width)/2
            transition.setFrame(view: tabSelectorView, frame: CGRect(origin: CGPoint(x: tabSelectorXOfset, y: tabSelectorInset), size: tabSelectorSize))
        }
        return tabSelectorSize.height
    }
}


public class EffectsPanelFlxImageView:UIView{
//    public var context : AccountContext?
    private let backgrondLayer : RoundedCornersView
//    private let flxHorizontalScrollView : HorizontalScrollChooseFlxView
    private let closeButton : UIImageView
    private var sendButton : UIImageView?
    
    private let selectedFlxIcon1 : UIImageView
    private let selectedFlxIcon2 : UIImageView
    private let effectSwitcher : EffectSwitcher
    private var flexatarView : FlexatarView?
    private var flexatarViewContainer : UIView?
    
    private var tabId = 0
    private let chooser:ChooserFlx
//    private let tabSelector: ComponentView<Empty>
//    private let tabItems: [TabSelectorComponent.Item]
    private let photoVideoTabSelector: PhotoVideoTabView
    
    private let buttonSize:CGFloat = 36.0
    private let flxIconWidth:CGFloat = 46.0
    private var flxIconHeight:CGFloat = 46.0
    private var tapGestureRecognizer:UITapGestureRecognizer?
    public var closeAction:(()->Void)?
    public var sendAction:(()->Void)?
    public var viewHeight:CGFloat = 1
    
    private let sliderView: TGPhotoEditorSliderView
    private let withFlxView: Bool
    
    public init(chooser:ChooserFlx,withFlxView:Bool = false) {
        self.withFlxView = withFlxView
        self.chooser = chooser
        self.backgrondLayer = RoundedCornersView(color: UIColor(red: 0, green: 0, blue: 0, alpha: 0.5), smoothCorners: true)
        self.backgrondLayer.update(cornerRadius: 12.0, transition: .immediate)
//        self.flxHorizontalScrollView = HorizontalScrollChooseFlxView(itemsVideo:StorageFlx.listVideoBuiltin,itemsPhoto:StorageFlx.listPhotoBuiltin,chooser: ChooserFlx.photoFlexatarChooser)
        self.closeButton = UIImageView(frame: CGRect())
        self.selectedFlxIcon1 = UIImageView(frame: CGRect())
        self.selectedFlxIcon2 = UIImageView(frame: CGRect())
        self.effectSwitcher = EffectSwitcher(chooser: chooser)
//        self.tabSelector =  ComponentView()
//        self.tabItems = [TabSelectorComponent.Item(id: 0, title: "Video"),TabSelectorComponent.Item(id: 1, title: "Photo")]
        self.photoVideoTabSelector =  PhotoVideoTabView(chooser: chooser)
        
        let sliderView = TGPhotoEditorSliderView()
        
        sliderView.enableEdgeTap = true
        sliderView.enablePanHandling = true
        sliderView.trackCornerRadius = 1.0
        sliderView.lineSize = 4.0
        sliderView.minimumValue = 0.0
        sliderView.startValue = 0.0
        sliderView.maximumValue = 1.0
        sliderView.disablesInteractiveTransitionGestureRecognizer = true
        sliderView.displayEdges = true
        sliderView.value = CGFloat(chooser.mixWeight)
        sliderView.backgroundColor = .clear
        sliderView.backColor = .white
        sliderView.trackColor = UIColor(rgb: 0x03adfc)
        
        self.sliderView = sliderView
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        
        super.init(frame: CGRect())
        self.closeButton.backgroundColor = .white
        self.closeButton.layer.masksToBounds = true
        self.closeButton.layer.cornerRadius = buttonSize/2
        self.closeButton.image = generateTintedImage(image:UIImage(bundleImageName: "Call/close"),color:.black)
//        self.tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.closeButtonPressed(_:)))
        
//        tapGestureRecognizer?.numberOfTapsRequired = 1
//        tapGestureRecognizer?.numberOfTouchesRequired = 1
        self.closeButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.closeButtonPressed(_:))))
        self.closeButton.isUserInteractionEnabled = true
       
        self.selectedFlxIcon1.image = photoVideoTabSelector.flxHorizontalScrollView.img1
        self.selectedFlxIcon1.backgroundColor = .clear
        self.selectedFlxIcon1.layer.cornerRadius = 11.0
        self.selectedFlxIcon1.layer.masksToBounds = true
        
        self.selectedFlxIcon2.image = photoVideoTabSelector.flxHorizontalScrollView.img2
        self.selectedFlxIcon2.backgroundColor = .clear
        self.selectedFlxIcon2.layer.cornerRadius = 11.0
        self.selectedFlxIcon2.layer.masksToBounds = true
        
        self.flxIconHeight = self.flxIconWidth * self.selectedFlxIcon1.image!.size.height / self.selectedFlxIcon1.image!.size.width
//        self.backgrondLayer.isUserInteractionEnabled = true
//        self.backgroundColor = .red
        self.backgroundColor = .clear
        self.addSubview(self.backgrondLayer)
//        self.addSubview(self.flxHorizontalScrollView)
        
//        self.photoVideoTabSelector.superview = self
        self.addSubview(self.photoVideoTabSelector)
        self.addSubview(self.closeButton)
        
        if self.chooser.tabIdx == 1 {
            self.addSubview(self.selectedFlxIcon1)
            self.addSubview(self.selectedFlxIcon2)
            self.addSubview(self.sliderView)
        }
        self.effectSwitcher.superview = self
        
        self.photoVideoTabSelector.imageDidSelected = {image in
            self.selectedFlxIcon2.image = self.selectedFlxIcon1.image
            self.selectedFlxIcon1.image = image
        }
        self.effectSwitcher.effectIndexDidSet = {effectIdx in
           
            self.sliderView.isUserInteractionEnabled = effectIdx == 1
            self.sliderView.backColor = effectIdx == 1 ? .white : .gray
            self.sliderView.trackColor = effectIdx == 1 ? UIColor(rgb: 0x03adfc) : .gray
        }
        self.sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
        self.effectSwitcher.effectIndexDidSet?(self.chooser.effectIdx)
        if withFlxView {
            self.flexatarView = FlexatarView(device: device, chooser: chooser)
            self.flexatarViewContainer = UIView(frame: CGRect())
            
            self.addSubview(flexatarViewContainer!)
            flexatarViewContainer?.addSubview(flexatarView!)
            flexatarViewContainer?.layer.cornerRadius = 24.0
            flexatarViewContainer?.layer.masksToBounds = true
            
            self.sendButton = UIImageView(frame: CGRect())
            self.sendButton?.backgroundColor = .white
            self.sendButton?.layer.masksToBounds = true
            self.sendButton?.layer.cornerRadius = buttonSize/2
            self.sendButton?.image = generateTintedImage(image:UIImage(bundleImageName: "Chat/Context Menu/Resend"), color:.black)
    //        self.tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.closeButtonPressed(_:)))
            
    //        tapGestureRecognizer?.numberOfTapsRequired = 1
    //        tapGestureRecognizer?.numberOfTouchesRequired = 1
            self.sendButton?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.sendButtonPressed(_:))))
            self.sendButton?.isUserInteractionEnabled = true
            self.addSubview(self.sendButton!)
        }
//        self.sliderView.isUserInteractionEnabled = self.chooser.effectIdx == 1
//        self.sliderView.backColor = self.chooser.effectIdx == 1 ? .white : .gray
//        self.sliderView.trackColor = self.chooser.effectIdx == 1 ? UIColor(rgb: 0x03adfc) : .gray
      
        
//        self.photoVideoTabSelector.isUserInteractionEnabled = true
//        self.isUserInteractionEnabled = true
//        self.addSubview(self.tabSelector.view!)
//        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.panelPressed(_:))))
        
    }
    public func subscribeStoargeObserver(){
        self.photoVideoTabSelector.subscribeStoargeObserver()
    }
//    @objc func panelPressed(_ sender: UITapGestureRecognizer){
//        print("FLX_INJECT panelPressed")
//    }
    @objc func sliderValueChanged() {
        self.chooser.mixWeight = Float(self.sliderView.value)
//        if let context = self.context{
            print("FLX_INJECT slider changed \(self.chooser.mixWeight) for tg_id ")
//        }
        
    }
    @objc func closeButtonPressed(_ sender: UITapGestureRecognizer)
    {
        if let flexatarView = self.flexatarView{
            flexatarView.removeFromSuperview()
            self.flexatarView = nil
            self.chooser.renderEngine = nil
        }
        print("FLX_INJECT closeButtonPressed")
        
        self.closeAction?()
    }
    @objc func sendButtonPressed(_ sender: UITapGestureRecognizer)
    {
        if let flexatarView = self.flexatarView{
            flexatarView.removeFromSuperview()
            self.flexatarView = nil
            self.chooser.renderEngine = nil
        }
        print("FLX_INJECT sendButtonPressed")
        self.sendAction?()
    }
    public func update(transition:ContainedViewLayoutTransition,frame:CGRect,isLandscape:Bool=false){
        update(transition:Transition(transition),frame:frame,isLandscape:isLandscape)
    }
    public func update(transition:Transition,frame:CGRect,isLandscape:Bool=false){
        
        var tabSelectorFrame = CGRect(origin: CGPoint(), size: frame.size)
        var flxViewWidth = frame.size.width * 0.4
        if isLandscape {
            let flxPartWidth = tabSelectorFrame.size.width/4
            tabSelectorFrame.size.width -= flxPartWidth
            flxViewWidth = 0.8 * flxPartWidth
        }
        
        let tabSelectorHeight = photoVideoTabSelector.update(transition: transition, frame: tabSelectorFrame){[weak self] tabId in
            if let strongSelf = self {
                strongSelf.update(transition: transition, frame: frame)
            }
        }
        
        let buttonPadding:CGFloat = 10.0
        var currentYOfset = tabSelectorHeight + buttonPadding
//        tmpFrame.size.height = scrollYShift
        
//        let buttonStartPoint=CGPoint()
        
        if self.chooser.tabIdx == 1 {
            
            let effectSwitcherFrame = CGRect(origin: CGPoint(x: 0, y: currentYOfset), size: CGSize(width: tabSelectorFrame.size.width, height: 44))
            currentYOfset += self.effectSwitcher.update(transition: transition, frame: effectSwitcherFrame)
            currentYOfset += buttonPadding
            
            
            if self.selectedFlxIcon1.superview == nil {
                self.addSubview(self.selectedFlxIcon1)
            }
            if self.selectedFlxIcon2.superview == nil {
                self.addSubview(self.selectedFlxIcon2)
            }
            if self.sliderView.superview == nil {
                self.addSubview(self.sliderView)
            }
            let iocnPadding:CGFloat = 6.0
            var xOfsetIcon = iocnPadding
            let icon1Frame = CGRect(origin: CGPoint(x: xOfsetIcon, y: currentYOfset), size: CGSize(width: self.flxIconWidth, height: self.flxIconHeight))
            transition.setFrame(view:self.selectedFlxIcon1, frame: icon1Frame)
            xOfsetIcon += self.flxIconWidth + iocnPadding
            let icon2Frame = CGRect(origin: CGPoint(x: xOfsetIcon, y: currentYOfset), size: CGSize(width: self.flxIconWidth, height: self.flxIconHeight))
            transition.setFrame(view:self.selectedFlxIcon2, frame: icon2Frame)
            xOfsetIcon += self.flxIconWidth + iocnPadding
            
            let sliderFrame = CGRect(origin: CGPoint(x: xOfsetIcon, y: currentYOfset), size: CGSize(width: tabSelectorFrame.width - xOfsetIcon - iocnPadding, height: self.flxIconHeight))
            transition.setFrame(view: self.sliderView, frame: sliderFrame)
           
            
            currentYOfset += self.flxIconHeight
            
        }else{
            self.selectedFlxIcon1.removeFromSuperview()
            self.selectedFlxIcon2.removeFromSuperview()
            self.effectSwitcher.tabSelector.view?.removeFromSuperview()
            self.sliderView.removeFromSuperview()
        }
        if withFlxView {
            if !isLandscape {
                currentYOfset += buttonPadding
            }
//            let flxViewWidth = frame.size.width * 0.3
            let flxViewHeight = flxViewWidth * 1.25
            var flxViewX = (frame.size.width - flxViewWidth)/2
            var flxViewY = currentYOfset
            if isLandscape {
                flxViewX = tabSelectorFrame.size.width + (frame.size.width - tabSelectorFrame.size.width-flxViewWidth)/2
                
                flxViewY = 30
            }
            let flexatarViewFrame = CGRect(origin: CGPoint(x: flxViewX, y: flxViewY), size: CGSize(width: flxViewWidth, height: flxViewHeight))
            transition.setFrame(view:flexatarView!, frame: CGRect(origin: CGPoint(), size: flexatarViewFrame.size))
            transition.setFrame(view:flexatarViewContainer!, frame: flexatarViewFrame)
            if !isLandscape {
                currentYOfset += flxViewHeight
            }
        }
        let buttonYOfset = currentYOfset + buttonPadding
        
        let buttonStartPoint = CGPoint(x:frame.size.width - buttonSize - buttonPadding ,y:buttonYOfset )
        var buttonRect = CGRect(origin: buttonStartPoint, size: CGSize(width: buttonSize, height: buttonSize))
        if let sendButton = self.sendButton{
            transition.setFrame(view:sendButton, frame: buttonRect)
            buttonRect.origin.x -= buttonSize + 2 * buttonPadding
            transition.setFrame(view:self.closeButton, frame: buttonRect)
        }else{
            transition.setFrame(view:self.closeButton, frame: buttonRect)
        }
        
        
        
        var selfFrame = frame
        selfFrame.size.height = buttonYOfset + buttonRect.height + buttonPadding
        transition.setFrame(view:self, frame: selfFrame)
        
        
        transition.setFrame(view:self.backgrondLayer, frame: CGRect(origin: CGPoint(), size: selfFrame.size))
        self.viewHeight = selfFrame.size.height
        
        
        
        
    }
   
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
                                        
public class EffectsPanelFlxNode:ASDisplayNode{
    public var closeAction:(()->Void)?{
        set{
            self.effectsView.closeAction = newValue
//            self.closeButtonNode.pressed = newValue
        }
        get{
            return self.effectsView.closeAction
//            return self.closeButtonNode.pressed
        }
    }
//    public var context:AccountContext?{
//        set{
//            self.effectsView.context = newValue
//        }
//        get{
//            return self.effectsView.context
//        }
//    }
    private let effectsView:EffectsPanelFlxImageView
    public init(chooser: ChooserFlx) {
        
        self.effectsView = EffectsPanelFlxImageView(chooser: chooser)
        super.init()
        self.view.addSubview(self.effectsView)
    }
    public func subscribeStoargeObserver(){
        self.effectsView.subscribeStoargeObserver()
    }
    
    public func update(frame: CGRect,isLandscape:Bool, transition: ContainedViewLayoutTransition) ->CGFloat{
        self.effectsView.update(transition: Transition(transition), frame: CGRect(origin: CGPoint(), size: frame.size))
        
        return self.effectsView.viewHeight
    }
}
//public class EffectsPanelFlxNode1:ASDisplayNode{
//    private let flexatarScrollNode:HorizontalScrollChooseFlxNode
//    private let closeButtonNode:ImageButtonFlxNode
//    private let buttonSize:CGFloat = 36.0
//    public var closeAction:(()->Void)?{
//        set{
//            self.closeButtonNode.pressed = newValue
//        }
//        get{
//            return self.closeButtonNode.pressed
//        }
//    }
//    public override init() {
//        self.flexatarScrollNode = HorizontalScrollChooseFlxNode(items:StorageFlx.listPhotoBuiltin,chooser: ChooserFlx.photoFlexatarChooser)
//        self.closeButtonNode = ImageButtonFlxNode()
//        super.init()
//        self.cornerRadius = 11.0
//        self.clipsToBounds = true
//        self.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
//        
//        
//        self.addSubnode(self.flexatarScrollNode)
//        self.flexatarScrollNode.backgroundColor = .clear
//        self.flexatarScrollNode.makeNodes()
//        
//        self.closeButtonNode.image =  generateTintedImage(image:UIImage(bundleImageName: "Call/close"),color:.black)
//        self.closeButtonNode.imageNode.backgroundColor = .white
//        self.closeButtonNode.imageNode.cornerRadius = buttonSize/2.0
//        self.closeButtonNode.imageNode.clipsToBounds = true
//        
//        self.addSubnode( self.closeButtonNode)
//    }
//    
//    public func update(frame: CGRect,isLandscape:Bool, transition: ContainedViewLayoutTransition) ->CGFloat{
//        let scrollFrame = CGRect(origin: CGPoint(), size: frame.size)
//        let flxScrollHeight = self.flexatarScrollNode.update(frame: scrollFrame, isLandscape: isLandscape, transition: transition)
//        
//        let buttonPadding:CGFloat = 12.0
//        
//        let buttonStartPoint = CGPoint(x:scrollFrame.size.width - buttonSize-buttonPadding ,y:scrollFrame.size.height+buttonPadding )
//        let buttonRect = CGRect(origin: buttonStartPoint, size: CGSize(width: buttonSize, height: buttonSize))
//        self.closeButtonNode.update(frame: buttonRect, transition: transition)
//        
//        
//        
//        return flxScrollHeight + buttonSize+buttonPadding*2
////        transition.updateFrame(node: self.flexatarScrollNode, frame: frame)
//    }
//}
