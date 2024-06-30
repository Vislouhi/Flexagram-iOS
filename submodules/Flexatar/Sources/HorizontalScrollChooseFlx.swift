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
//import MergeLists
import ComponentFlow
import TabSelectorComponent
import ComponentDisplayAdapters

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


public class HorizontalScrollChooseFlxNode : ASDisplayNode{
    private let photoVideoTabSelector: PhotoVideoTabView
    
    public init(chooser:ChooserFlx) {
        self.photoVideoTabSelector =  PhotoVideoTabView(chooser: chooser)
        super.init()
        self.view.addSubview(photoVideoTabSelector)
        self.cornerRadius = 11.0
        self.clipsToBounds = true
        self.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
    }
    public func update(frame: CGRect,isLandscape:Bool, transition: ContainedViewLayoutTransition)->CGFloat{
    
        let tabSelectorFrame = CGRect(origin: CGPoint(), size: frame.size)
        let tabSelectorHeight = photoVideoTabSelector.update(transition: Transition(transition), frame: tabSelectorFrame){[weak self] _ in
            if let strongSelf = self {
                _ = strongSelf.update(frame: frame, isLandscape: isLandscape, transition: transition)
            }
        }
            
        
        var frameSelf = frame
        frameSelf.size.height = tabSelectorHeight + 12
        transition.updateFrame(node: self, frame: frameSelf)
        return frameSelf.size.height

    }
}
public class HorizontalScrollChooseFlxNode1 : ASScrollNode{
    
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

public class PhotoVideoTabView:UIView{
    private let chooser:ChooserFlx
    public let flxHorizontalScrollView : HorizontalScrollChooseFlxView
    public let tabSelector: ComponentView<Empty>
    private let tabItems: [TabSelectorComponent.Item]

    
//    private var _superview:UIView?
//    public var superview:UIView? {
//        get {
//            return _superview
//        }
//        set{
//            _superview = newValue
//            _superview?.addSubview(self.flxHorizontalScrollView)
//        }
//    }
    public var imageDidSelected:((UIImage)->())?{
        get {
            return self.flxHorizontalScrollView.imageDidSelected
        }
        set {
            self.flxHorizontalScrollView.imageDidSelected = newValue
        }
    }
    public init(chooser:ChooserFlx){
        self.chooser=chooser
        self.flxHorizontalScrollView = HorizontalScrollChooseFlxView(itemsVideo:chooser.videoList ,itemsPhoto:chooser.photoList,chooser: self.chooser)
        self.tabSelector =  ComponentView()
        self.tabItems = [TabSelectorComponent.Item(id: 0, title: "Video"),TabSelectorComponent.Item(id: 1, title: "Photo")]
        super.init(frame: CGRect())
        
//        super.init(frame: CGRect())
        self.addSubview(self.flxHorizontalScrollView)
//        self.tabSelector.view?.isUserInteractionEnabled = true
        self.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    public func subscribeStoargeObserver(){
        self.flxHorizontalScrollView.subscribeStoargeObserver()
    }
    public func update(transition:Transition,frame:CGRect,tabSwitch:@escaping(Int)->()) -> CGFloat{
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
                selectedId: self.chooser.tabIdx,
                setSelectedId: {[weak self]  id in

                    let intId = id as! Int
                    print("FLX_INJECT tab switch \(id)")
                    
                    if let self=self{
                        if (self.chooser.tabIdx != intId){
                            self.chooser.tabIdx = id as! Int
                            tabSwitch(intId)
//                            _ = self.update(transition:transition ,frame:frame)
//                            print("FLX_INJECT tab switch \(id)")
                        }
                    }

                }
            )),
            environment: {},
            containerSize: CGSize(width: frame.width, height: 44.0)
        )
        let tabSelectorInset:CGFloat = 10
        if let tabSelectorView = tabSelector.view {
            if tabSelectorView.superview == nil {
                self.addSubview(tabSelectorView)
            }
    
            let tabSelectorXOfset = (frame.width - tabSelectorSize.width)/2
            transition.setFrame(view: tabSelectorView, frame: CGRect(origin: CGPoint(x: tabSelectorXOfset, y: tabSelectorInset), size: tabSelectorSize))
        }
        let scrollRect = CGRect(origin: CGPoint(x: 0, y: tabSelectorInset + tabSelectorSize.height), size: frame.size)
        let iconHeight = self.flxHorizontalScrollView.update(frame: scrollRect, transition: transition)
        var frame1 = frame
        frame1.size.height = iconHeight + tabSelectorInset + tabSelectorSize.height
        transition.setFrame(view: self, frame: frame1)
        return frame1.size.height
    }
    
}

public class HorizontalScrollChooseFlxView:UIScrollView{
    private var imageViews:[[UIImageView]] = []
    private var paths:[[String]] = []
    private var imageRatio:CGFloat = 1.0
    private var chooser:ChooserFlx
    private var currentTabIdx:Int
    public var img1:UIImage!
    public var img2:UIImage!

    
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
    
    public init(itemsVideo:[String?],itemsPhoto:[String?],chooser:ChooserFlx){
        
        self.chooser = chooser
        currentTabIdx = self.chooser.tabIdx
        super.init(frame: CGRect())
        for (tabIdx,items) in [itemsVideo,itemsPhoto].enumerated(){
            self.imageViews.append([UIImageView]())
            self.paths.append([String]())
            for (idx,item) in items.enumerated(){
                if let path = item{
                    self.paths[tabIdx].append(path)
                    let node = Self.imageViewFactory(atPath: path)
                    print("FLX_INJECT current path \(path) chooser path \(self.chooser.path1) verdict \(path==self.chooser.path1)")
                    if path == self.chooser.path1 {
                        self.img1 = node.image!
                        print("FLX_INJECT image for path1 set")
                    }else
                    if path == self.chooser.path2 {
                        self.img2 = node.image!
                    }
                    node.tag = idx
                    
                    node.isUserInteractionEnabled = true
                    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(flxIconPressed(tapGestureRecognizer:)))
                    node.addGestureRecognizer(tapGestureRecognizer)
                    
                    //                node.addTarget(self, action: #selector(flxIconPressed(_:)), forControlEvents: .touchUpInside)
                    self.imageViews[tabIdx].append(node)
                    if self.chooser.tabIdx == tabIdx{
                        self.addSubview(node)
                    }
                    
                    
                }
            }
        }
        self.imageRatio = self.imageViews[0][0].image!.size.width/self.imageViews[0][0].image!.size.height
        
    }
     
    public var imageDidSelected:((UIImage)->())?
    public func subscribeStoargeObserver(){
        StorageFlx.storageDidChange = {  taskType, flxContentType,path in
            let flxTypeIdx = flxContentType == .photo ? 1 : 0
            DispatchQueue.main.sync {[weak self] in
                guard let strongSelf = self else {return}
                switch taskType{
                case .add:
                    
                    let node = Self.imageViewFactory(atPath: path)
                    node.isUserInteractionEnabled = true
                    let tapGestureRecognizer = UITapGestureRecognizer(target: strongSelf, action: #selector(strongSelf.flxIconPressed(tapGestureRecognizer:)))
                    node.addGestureRecognizer(tapGestureRecognizer)
                    if strongSelf.chooser.tabIdx == flxTypeIdx {
                        
                        strongSelf.addSubview(node)
                        
                        
                    }
                    strongSelf.imageViews[flxTypeIdx].insert(node, at: 0)
                    strongSelf.paths[flxTypeIdx].insert(path, at: 0)
//                        print("FLX_INJECT new paths \(strongSelf.paths[1])")
                    for (idx,imageView) in strongSelf.imageViews[flxTypeIdx].enumerated(){
                        imageView.tag = idx
                        
                    }
                    if strongSelf.chooser.tabIdx == flxTypeIdx {
                        
                        if let frame = strongSelf.updateFrame,let transition =
                            strongSelf.updateTransitione{
                            
                            _ = strongSelf.update(frame: frame, transition: transition)
                        }
                       
                    }
                   
                    print("FLX_INJECT new flx in storage")
                    break
                case .remove:
                    
                    if let idxToRemove = strongSelf.paths[flxTypeIdx].firstIndex(where: {$0 == path}){
                        print("FLX_INJECT idxToRemove \(idxToRemove) path \(path)")
                        strongSelf.imageViews[flxTypeIdx][idxToRemove].removeFromSuperview()
                        strongSelf.imageViews[flxTypeIdx].remove(at: idxToRemove)
                        strongSelf.paths[flxTypeIdx].remove(at: idxToRemove)
                        for (idx,imageView) in strongSelf.imageViews[flxTypeIdx].enumerated(){
                            imageView.tag = idx
                        }
                        if strongSelf.chooser.tabIdx == flxTypeIdx {
                            if let frame = strongSelf.updateFrame,let transition =
                                strongSelf.updateTransitione{
                                
                                _ = strongSelf.update(frame: frame, transition: transition)
                            }
                         }
                    }
                    print("FLX_INJECT flx from storage removed")
                    break
                }
            }
        }
        print("FLX_INJECT subscribe observer")
    }
    @objc func flxIconPressed(tapGestureRecognizer: UITapGestureRecognizer)
    {
        print("FLX_INJECT icon pressed")
        let tappedImage = tapGestureRecognizer.view as! UIImageView
        
        if chooser.tabIdx == 1{
            let newPath = paths[chooser.tabIdx][tappedImage.tag]
            if newPath != self.chooser.path1{
                self.imageDidSelected?(tappedImage.image!)
            }
            self.chooser.path1 = paths[chooser.tabIdx][tappedImage.tag]
        }else{
            self.chooser.videoPath = paths[chooser.tabIdx][tappedImage.tag]
        }
    }
    private var updateFrame:CGRect?
    private var updateTransitione:Transition?
    public func update(frame:CGRect,transition:Transition)->CGFloat{
//        updateFrame = frame
//        updateTransitione = transition
        let iconWidth:CGFloat
        let iconHeight:CGFloat
        iconWidth = 72.0
        iconHeight =  iconWidth / self.imageRatio
        
        let iconMargin = iconHeight*0.05
        var frameTmp = frame
        frameTmp.size.height = iconHeight + iconMargin*2
        if currentTabIdx != self.chooser.tabIdx{
            for items in self.imageViews[currentTabIdx]{
                items.removeFromSuperview()
            }
            currentTabIdx = self.chooser.tabIdx
            for items in self.imageViews[currentTabIdx]{
                self.addSubview(items) 
            }
        }
        for (idx,iconNode) in self.imageViews[self.chooser.tabIdx].enumerated(){
            let imageFrame = CGRect(x: iconMargin+CGFloat(idx)*(iconWidth+iconMargin), y: iconMargin, width: iconWidth, height: iconHeight)

            transition.setFrame(view: iconNode, frame: imageFrame)
        }
        let contentWidth = CGFloat(imageViews[self.chooser.tabIdx].count) * (iconWidth+iconMargin)+iconMargin
        
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
