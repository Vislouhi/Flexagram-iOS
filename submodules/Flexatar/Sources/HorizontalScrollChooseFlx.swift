//
//  HorizontalScrollChooseFlx.swift
//  Flexatar
//
//  Created by Matey Vislouh on 26.04.2024.
//
import Display
import AsyncDisplayKit
import Foundation
//import ItemListUI
import SwiftSignalKit
import MergeLists
import ComponentFlow

extension UIImage {
    func resizeImage(to newSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        self.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
extension ASControlNode {
    private struct AssociatedKeys {
        static var tag: UInt8 = 0
    }
    
    var tag: Int {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.tag) as? Int ?? 0
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.tag, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}



public class HorizontalScrollChooseFlxNode : ASScrollNode{
    
//    private let imageNode:ASImageNode
    private let iconsCount:CGFloat = 5
    private let landscapeIconsCount:CGFloat = 10
    private var imageRatio:CGFloat = 1.0
    private let items:[String?]
    private var iconsNodes:[ASImageNode] = []
    private var controllNodes:[ASControlNode] = []
    private var paths:[String] = []
    private let chooser:ChooserFlx
    

    
    
    private static func imageNodeFactory(atPath path:String)->ASImageNode{
        let imageNode = ASImageNode()
        imageNode.cornerRadius = 11.0
        imageNode.clipsToBounds = true
        imageNode.contentMode = .scaleAspectFit
        let metaData = MetaDataFlexatar(withPreviewImage: true,atPath: path)
        if let imageData = metaData.imageData{
            let img = UIImage(data: imageData)
            if let imageSize = img?.size{
                let imageRatio = imageSize.width/imageSize.height
                let imageWidth:CGFloat = 50
                imageNode.image = img?.resizeImage(to: CGSize(width: imageWidth, height: imageWidth/imageRatio))
            }
        }
        return imageNode
    }
    
    public init(items:[String?],chooser:ChooserFlx) {
        self.chooser=chooser
        self.items=items
        
       
        

//        self.imageNode = ASImageNode()
//        self.imageNode.cornerRadius = 11.0
//        self.imageNode.clipsToBounds = true
//        self.imageNode.contentMode = .scaleAspectFit
        super.init()
//        self.view.disablesInteractiveTransitionGestureRecognizer = true
        self.cornerRadius = 11.0
        self.clipsToBounds = true
        self.view.showsVerticalScrollIndicator = false
        self.view.showsHorizontalScrollIndicator = false
        self.view.scrollsToTop = false
        self.view.delaysContentTouches = false
        self.view.canCancelContentTouches = true
        if #available(iOS 11.0, *) {
            self.view.contentInsetAdjustmentBehavior = .never
        }
        self.view.panGestureRecognizer.isEnabled = true
        
        self.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        
       
    }
    
    public func makeNodes(){
        for (idx,item) in items.enumerated(){
            if let path = item{
                self.paths.append(path)
                let node = Self.imageNodeFactory(atPath: path)
                let control = ASControlNode()
                control.tag = idx
                control.addTarget(self, action: #selector(flxIconPressed(_:)), forControlEvents: .touchUpInside)
                self.iconsNodes.append(node)
                self.controllNodes.append(control)
                self.addSubnode(control)
                control.addSubnode(node)
                
            }
            
        }
        imageRatio = iconsNodes[0].image!.size.width/iconsNodes[0].image!.size.height

    }
    @objc func flxIconPressed(_ sender: ASControlNode) {
        self.chooser.path1 = paths[sender.tag]
        print("FLX_INJECT selected flexatar: \(sender.tag)")
           // Handle the control node click event here based on sender.tag or other properties
   }
//    public func update(frame: CGRect,isLandscape:Bool, transition: ContainedViewLayoutTransition){
//        let _ = self.update(frame: frame,isLandscape:isLandscape, transition: transition)
//    }
    public func update(frame: CGRect,isLandscape:Bool, transition: ContainedViewLayoutTransition)->CGFloat{
        
        
        
        let iconWidth:CGFloat
        let iconHeight:CGFloat
        iconWidth = 72.0
        iconHeight =  iconWidth / imageRatio
//        if isLandscape{
//            iconWidth = frame.width / landscapeIconsCount
//            iconHeight =  iconWidth / imageRatio
//        }else{
//            iconWidth = frame.width / iconsCount
//            iconHeight = iconWidth / imageRatio
//        }
        let iconMargin = iconHeight*0.05
        var frameTmp = frame
        frameTmp.size.height = iconHeight + iconMargin*2
        
        for (idx,iconNode) in self.iconsNodes.enumerated(){
            let imageFrame = CGRect(x: iconMargin+CGFloat(idx)*(iconWidth+iconMargin), y: iconMargin, width: iconWidth, height: iconHeight)
            let controlNode = controllNodes[idx]
            transition.updateFrame(node: controlNode, frame: imageFrame)
//            transition.updateFrame(node: iconNode, frame: imageFrame)
            transition.updateFrame(node: iconNode, frame: CGRect(origin: CGPoint(), size: imageFrame.size))
        }
        let contentWidth = CGFloat(iconsNodes.count) * (iconWidth+iconMargin)+iconMargin
        
        transition.updateFrame(node: self, frame: frameTmp)
        self.view.contentSize = CGSize(width: contentWidth, height: frameTmp.size.height)
        return frameTmp.size.height
    }
    
}

public class HorizontalScrollChooseFlxView:UIScrollView{
    var imageViews:[UIImageView] = []
    var paths:[String] = []
    var imageRatio:CGFloat = 1.0
    var chooser:ChooserFlx
    
    private static func imageViewFactory(atPath path:String)->UIImageView{
        let imageNode = UIImageView(frame: CGRect() )
        imageNode.layer.cornerRadius = 11.0
        imageNode.layer.masksToBounds = true
        imageNode.contentMode = .scaleAspectFit
        let metaData = MetaDataFlexatar(withPreviewImage: true,atPath: path)
        if let imageData = metaData.imageData{
            let img = UIImage(data: imageData)
            if let imageSize = img?.size{
                let imageRatio = imageSize.width/imageSize.height
                let imageWidth:CGFloat = 50
                imageNode.image = img?.resizeImage(to: CGSize(width: imageWidth, height: imageWidth/imageRatio))
            }
        }
        return imageNode
    }
    
    public init(items:[String?],chooser:ChooserFlx){
        self.chooser = chooser
        super.init(frame: CGRect())
        
        for (idx,item) in items.enumerated(){
            if let path = item{
                self.paths.append(path)
                let node = Self.imageViewFactory(atPath: path)
                node.tag = idx
                
                node.isUserInteractionEnabled = true
                let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(flxIconPressed(tapGestureRecognizer:)))
                node.addGestureRecognizer(tapGestureRecognizer)
                
//                node.addTarget(self, action: #selector(flxIconPressed(_:)), forControlEvents: .touchUpInside)
                self.imageViews.append(node)

                self.addSubview(node)
               
                
            }
            
        }
        self.imageRatio = self.imageViews[0].image!.size.width/self.imageViews[0].image!.size.height
        
    }
    @objc func flxIconPressed(tapGestureRecognizer: UITapGestureRecognizer)
    {
        let tappedImage = tapGestureRecognizer.view as! UIImageView
        self.chooser.path1 = paths[tappedImage.tag]
    }
    public func update(frame:CGRect,transition:Transition)->CGFloat{
        let iconWidth:CGFloat
        let iconHeight:CGFloat
        iconWidth = 72.0
        iconHeight =  iconWidth / self.imageRatio
        
        let iconMargin = iconHeight*0.05
        var frameTmp = frame
        frameTmp.size.height = iconHeight + iconMargin*2
        
        for (idx,iconNode) in self.imageViews.enumerated(){
            let imageFrame = CGRect(x: iconMargin+CGFloat(idx)*(iconWidth+iconMargin), y: iconMargin, width: iconWidth, height: iconHeight)

            transition.setFrame(view: iconNode, frame: imageFrame)
        }
        let contentWidth = CGFloat(imageViews.count) * (iconWidth+iconMargin)+iconMargin
        
        transition.setFrame(view: self, frame: frameTmp)
        self.contentSize = CGSize(width: contentWidth, height: frameTmp.size.height)
        return iconHeight
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
/*
public class HorizontalListFlxNode:ASDisplayNode{
    public let listNode: ListView
    
    public override init(){
        self.listNode = ListView()
        self.listNode.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        self.listNode.backgroundColor = UIColor.red
        super.init()
        
//        self.addSubnode(self.listNode)
    }
    public func makeList(){
        var entries: [FlxIconEntry] = []
        for i in 0..<100{
            entries.append(FlxIconEntry(index: i))
        }
        let transition = preparedTransition( entries: entries, crossfade: false)
        let scrollToItem = ListViewScrollToItem(index: 0, position: .bottom(-10.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Down)
        var options = ListViewDeleteAndInsertOptions()
        options.insert(.Synchronous)
        
        self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, scrollToItem: scrollToItem, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
        })
    }
}

public class IconFlxItem:ItemListItem, ListViewItemWithHeader {
    public var sectionId: ItemListUI.ItemListSectionId
    
    public var header: Display.ListViewItemHeader?
    
    public init(sectionId: ItemListSectionId = 0){
        self.sectionId=sectionId
    }
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: Display.ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: Display.ListViewItem?, nextItem: Display.ListViewItem?, completion: @escaping (Display.ListViewItemNode, @escaping () -> (SwiftSignalKit.Signal<Void, SwiftSignalKit.NoError>?, (Display.ListViewItemApply) -> Void)) -> Void) {
        
        let node = IconNodeFlx()
        let (nodeLayout, apply) = node.asyncLayout()()
        node.insets = nodeLayout.insets
        node.contentSize = nodeLayout.contentSize
        
        Queue.mainQueue().async {
            completion(node, {
                return (nil, { _ in
                    apply()
                })
            })
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> Display.ListViewItemNode, params: Display.ListViewItemLayoutParams, previousItem: Display.ListViewItem?, nextItem: Display.ListViewItem?, animation: Display.ListViewItemUpdateAnimation, completion: @escaping (Display.ListViewItemNodeLayout, @escaping (Display.ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is IconNodeFlx)
            if let nodeValue = node() as? IconNodeFlx {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout()
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    
}

public class IconNodeFlx: ListViewItemNode, ASGestureRecognizerDelegate{
    
    var imageNode:ASImageNode
    public init(){
        self.imageNode = ASImageNode()
        imageNode.cornerRadius = 11.0
        imageNode.clipsToBounds = true
        imageNode.contentMode = .scaleAspectFit
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        self.addSubnode(self.imageNode)
    }
    public func asyncLayout() -> () -> (ListViewItemNodeLayout, () -> Void) {
        return { [weak self]  in
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: 120.0, height: 90.0), insets: UIEdgeInsets())
            return (itemLayout, { 
                let path = Bundle.main.path(forResource: "x00_char\(1)t", ofType: "flx")
                let metaData = MetaDataFlexatar(withPreviewImage: true,atPath: path!)
                if let imageData = metaData.imageData{
                    let img = UIImage(data: imageData)
                    if let imageSize = img?.size{
                        let imageRatio = imageSize.width/imageSize.height
                        let imageWidth:CGFloat = 50
                        if let strongSelf = self{
                            strongSelf.imageNode.image = img?.resizeImage(to: CGSize(width: imageWidth, height: imageWidth/imageRatio))
                        }
                    }
                }
            })
        }
    }
}

private struct FlxItemNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let crossfade: Bool
    let entries: [FlxIconEntry]
}

private struct FlxIconEntry: Comparable, Identifiable {
    
    let index: Int

    
    var stableId: Int {
        return index
    }
    
    static func ==(lhs: FlxIconEntry, rhs: FlxIconEntry) -> Bool {
        if lhs.index != rhs.index {
            return false
        }
       
        return true
    }
    
    static func <(lhs: FlxIconEntry, rhs: FlxIconEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item() -> ListViewItem {
        return IconFlxItem()
    }
}

private func preparedTransition( entries: [FlxIconEntry], crossfade: Bool) -> FlxItemNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: [], rightList: entries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(), directionHint: .Down) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(), directionHint: nil) }
        return FlxItemNodeTransition(deletions: deletions, insertions: insertions, updates: updates, crossfade: crossfade, entries: entries)
}
*/
