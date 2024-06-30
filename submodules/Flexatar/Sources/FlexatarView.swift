//
//  FlexatarView.swift
//  Flexatar
//
//  Created by Matey Vislouh on 21.06.2024.
//

import Foundation
import MetalKit

public class FlexatarView: MTKView,MTKViewDelegate,FlexatarEngine {
    public var effectCtrl: RenderEngine.EffectCtrlProvider
    
   
    
    private let loadQueue = DispatchQueue(label: "ResLoadQueueMTKView")
    private var staticResoureceLoaded = false
    private let pipelineStates: RenderEngine.PipelineStates
    private var staticResources: RenderEngine.StaticResources!
    public let flexatarLoader: RenderEngine.FlexatarLoader
    private let chooser: ChooserFlx
    public var effectIdx:Int = 0
    public var  mixWeight:Float = 0.5
    
    public init(device:MTLDevice,chooser:ChooserFlx){
        
        self.pipelineStates = RenderEngine.PipelineStates(device: device)
//        self.staticResources = RenderEngine.StaticResources(device: device)
        self.flexatarLoader = RenderEngine.FlexatarLoader(device: device)
        self.chooser = chooser
        self.effectCtrl = RenderEngine.EffectCtrlProvider()
        super.init(frame: CGRect(), device: device)
        chooser.renderEngine = self
//        self.layer.cornerRadius = 24.0
//        self.layer.masksToBounds = true
       
//        let cornerRadius: CGFloat = 20
//        let maskLayer = CAShapeLayer()
//        maskLayer.path = UIBezierPath(roundedRect: self.bounds, cornerRadius: cornerRadius).cgPath
//        self.layer.mask = maskLayer
        
        self.preferredFramesPerSecond = 30

        self.framebufferOnly = false
        self.colorPixelFormat = .bgra8Unorm
        self.clearColor = MTLClearColor(red: 0.0, green: 0.0,blue: 0.0, alpha: 1.0)
        self.delegate = self
//        self.layer.zPosition = -1
        self.isUserInteractionEnabled = false
        self.loadQueue.async {[weak self] in
            if let self = self {
                self.staticResources = RenderEngine.StaticResources(device: device)
                if chooser.currentType == .video{
                    flexatarLoader.loadFlexatar(path: chooser.videoPath)
                }else{
                    flexatarLoader.loadFlexatar(path: chooser.path1,effectPath:chooser.path2)
                    effectCtrl.effectIdx = chooser.effectIdx
                    effectCtrl.mixWeight =  1 - chooser.mixWeight
                }
                self.staticResoureceLoaded = true
            }
        }
       
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var screenRatio:Float = 1
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        screenRatio = Float( size.width/size.height)
    }
    
    public func draw(in view: MTKView) {
        if (!self.staticResoureceLoaded) {return}
        guard let drawable = view.currentDrawable,let renderPassDescriptor = self.currentRenderPassDescriptor else {return}
        
        self.flexatarLoader.swithDrawing (photo:{ [weak self] flxPack1, flxPack2 in
            guard let self = self else {return}
            let currentMixWeight = effectCtrl.calcMixWeight()
            RenderEngine.drawPhotoFLx(flxPack1, flxPack2, pipelineStates: self.pipelineStates, device: self.device!, renderPassDescriptor: renderPassDescriptor, speechVector: [0,0,0,0,0], mixWeight: currentMixWeight, effectIdx: effectCtrl.effectIdx, screenRatio: screenRatio, staticResources: self.staticResources,isRotated:false,drawable:drawable)
        }, video: {[weak self] flxPack1 in
            guard let self = self else {return}
            var ratio:Float = 1
            if let vRatio = flxPack1.videoRatio{
                ratio = self.screenRatio*vRatio
            }
            RenderEngine.drawVideoFlx(flxPack1, device: self.device!, pipelineStates: pipelineStates, renderPassDescriptor: renderPassDescriptor, staticResources: staticResources, isRotated: false,drawable:drawable, speechVector: [0,0,0,0,0],screenRatio: ratio)
        })


    }
    public func loadFlexatar(path:String,effectPath:String?){
        self.loadQueue.async {[weak self] in
            guard let self = self else{return}
            self.flexatarLoader.loadFlexatar(path: path,effectPath:effectPath)
        }
    }
    
    
}
