//
//  PhotoCapture.swift
//  Flexatar
//
//  Created by Matey Vislouh on 27.06.2024.
//

import Foundation
import Display
import UIKit
import AVFoundation
import ComponentFlow

//import MobileCoreServices
//import CoreML
//import LegacyComponents

//TGAttachmentCameraView
public class PhotoCaptureController: ViewController,AVCaptureDataOutputSynchronizerDelegate, AVCapturePhotoCaptureDelegate {
    
    private var cameraSession:CamSession?
    private let closeButton : UIImageView
    private let container : UIView
    private let buttonSize:CGFloat = 36.0
    private let shutterView = ShutterView(frame: CGRect())
    private let assistantOverlay = UIImageView(frame: CGRect())
    private var assistantImgSeq:[UIImage] = []
    private var imgJpegs:[Data] = []
    private var photoCounter = 0
    private let accountId:Int64

    
    public init(accountId:Int64){
        self.closeButton = UIImageView(frame: CGRect())
        self.container = UIView(frame: CGRect())
        self.accountId = accountId
        super.init(navigationBarPresentationData: nil)
        self.navigationPresentation = .flatModal
        self.statusBar.statusBarStyle = .Ignore
        self.blocksBackgroundWhenInOverlay = true
        self.acceptsFocusWhenInOverlay = true
        
        self.closeButton.backgroundColor = .white
        self.closeButton.layer.masksToBounds = true
        self.closeButton.layer.cornerRadius = buttonSize/2
        self.closeButton.image = generateTintedImage(image:UIImage(bundleImageName: "Call/close"),color:.black)
        self.closeButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.closeButtonPressed(_:))))
        self.closeButton.isUserInteractionEnabled = true
        
        self.container.backgroundColor = .black
        shutterView.capturePressed = {[weak self] in
            guard let self = self else{return}
            let settings = AVCapturePhotoSettings()
            if let connection = self.cameraSession?.photoOutput?.connection(with: .video) {
                connection.videoOrientation = .portrait
            }
            self.cameraSession?.photoOutput?.capturePhoto(with: settings, delegate: self)
        }
        let assistantImages = ["flx_photo_helper_front","flx_photo_helper_left","flx_photo_helper_right","flx_photo_helper_down","flx_photo_helper_up"].map{
            UIImage(contentsOfFile: Self.loadImage(name: $0).getPath())!
        }
        assistantImgSeq.append(assistantImages[0])
        assistantImgSeq.append(assistantImages[1])
        assistantImgSeq.append(assistantImages[0])
        assistantImgSeq.append(assistantImages[2])
        assistantImgSeq.append(assistantImages[0])
        assistantImgSeq.append(assistantImages[3])
        assistantImgSeq.append(assistantImages[0])
        assistantImgSeq.append(assistantImages[4])
        assistantOverlay.image = assistantImgSeq[0]
       
       
    }
    private static func loadImage(name:String)->URL{
        let mainBundle = Bundle(for: MetalResProviderFlx.self)
        guard let path = mainBundle.path(forResource: "FlexatarMetalSourcesBundle", ofType: "bundle") else {
 
            fatalError("FLX_INJECT flexatar metal source bundle not found")
           
        }
        guard let bundle = Bundle(path: path) else {

            fatalError("FLX_INJECT bundle at path not found")
        }
        guard let fileUrl = bundle.url(forResource:name, withExtension: "png") else{
            fatalError("FLX_INJECT file not found")
        }
        return fileUrl
    }
    
    @objc func closeButtonPressed(_ sender: UITapGestureRecognizer)
    {
        self.cameraSession?.stop()
        self.cameraSession = nil
        self.lockOrientation = false
        self.dismiss()
        
    }
    let shitterSize:CGFloat = 90
    open override func viewDidAppear(_ animated: Bool) {
              
        super.viewDidAppear(animated)
        self.cameraSession = CamSession(preset: CamSession.capturePreset, videoOut: false, previewLayer: true, callback: self, operation: self.cameraImageCaptured)
        let previewWidth = self.view.frame.width
        let previewHeight = previewWidth * 1.3
        
        self.cameraSession?.cameraPreviewLayer?.frame = CGRect(x: 0, y: 0, width: previewWidth, height: previewHeight)
        self.assistantOverlay.frame = CGRect(x: 0, y: 0, width: previewWidth, height: previewHeight)
        
        self.container.frame = self.view.frame
        let shutterX = self.view.frame.width/2 - shitterSize/2
        self.shutterView.frame = CGRect(x: shutterX, y: self.view.frame.height - shitterSize - 50, width: shitterSize, height: shitterSize)
        
        self.container.layer.insertSublayer((self.cameraSession?.cameraPreviewLayer)!,at: 0)
        self.cameraSession?.start()
        self.closeButton.frame = CGRect(x: 20, y: 30, width: buttonSize, height: buttonSize)
        self.lockedOrientation = .portrait
        self.lockOrientation = true
        
        self.view.addSubview(self.container)
        self.container.addSubview(self.closeButton)
        self.container.addSubview(self.shutterView)
        self.container.addSubview(self.assistantOverlay)
        
       
        
    }
//    override public func viewDidLoad() {
//       
//    }
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
       
    }
    private func cameraImageCaptured(cgImage:CGImage,depth:CVPixelBuffer?){
        
    }
    private func makePhotoDataForBackend(){
        self.imgJpegs.swapAt(3, 4)
        if self.imgJpegs.count > 5 {
            self.imgJpegs.swapAt(8, 9)
        }
        
        struct MakeFlxHeader:Codable{
            
            var name:String
            var date:String
            var rotation:Int?
            var teeth_top:Float?
            var teeth_bottom:Float?
            var mouth_only:Bool?
            var flx_type:String?
        }
        let header = MakeFlxHeader(name:"Test name", date:"test date",rotation: 0,teeth_top: 0.5,teeth_bottom: 0.6)
        let headerData = try! JSONEncoder().encode(header)
        var send = headerData.lengtBasedPackage()
        for imgData in self.imgJpegs{
            send += imgData.lengtBasedPackage()
        }
        let fileName = "flx_input.bin"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        try! send.write(to: fileURL)
        
        Backend.request(accountId: self.accountId, endpoint: "data", completion: {data, _ in
            let decoder = JSONDecoder()
            if let apigwResponce = try? decoder.decode(ApigwResponse.self, from: data){
//                saveApigwResponse(accountId: accountId, response: apigwResponce)
                print("FLX_INJECT verify responce \(apigwResponce)")
            }
        }, fail: {
            
        }, body:send, contentType:.data)
    }
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        let image = UIImage(data: imageData)
        let ratio = CGFloat(image!.size.width)/CGFloat(image!.size.height)
        let imWidth:CGFloat = 720
        let imHeight = imWidth / ratio
        
        if photoCounter == 0 || photoCounter % 2 == 1{
            let scaledImage = image!.scaled(to: CGSize(width: imWidth, height: imHeight))!
            if let jpegData = scaledImage.jpegData(compressionQuality: 0.5) {
                self.imgJpegs.append(jpegData)
                print("Photo captured! size \(image!.size) scale \(scaledImage.size) jpegData \(jpegData.count)")
            }
            
        }
        photoCounter += 1
        if photoCounter == assistantImgSeq.count {
            makePhotoDataForBackend()
            self.dismiss()
            return
        }
        self.assistantOverlay.image = self.assistantImgSeq[photoCounter]
        
        
            // Save or use the image as needed
//            UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil)
            
        }
}


class ShutterView: UIView {
    var innerColor:UIColor = .white
    var capturePressed:(()->())?
    
    override init(frame:CGRect){
        super.init(frame: frame)
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        self.addGestureRecognizer(tapGestureRecognizer)
        self.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
        // Step 6: Define the action method for the tap gesture recognizer
    @objc private func handleTap(_ sender: UITapGestureRecognizer) {
        print("Circle tapped!")
        capturePressed?()
        // Additional actions can be added here
    }
    // Step 2: Override the draw(_:) method
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        let outerRect = rect.scaledBy(factor: 0.95)
        let innerRect = rect.scaledBy(factor: 0.75)
        // Step 3: Create a UIBezierPath for the circle
        let path = UIBezierPath(ovalIn: outerRect)
        let path1 = UIBezierPath(ovalIn: innerRect)
        
        // Step 4: Set the fill and stroke colors
        innerColor.setFill()
        UIColor.white.setStroke()
        path.lineWidth = 5
        
        // Fill and stroke the path
        path1.fill()
        path.stroke()
    }
}

extension CGRect {
    
    // Step 2: Add a method to scale the CGRect relative to its center
    func scaledBy(factor: CGFloat) -> CGRect {
        // Calculate the new width and height
        let newWidth = width * factor
        let newHeight = height * factor
        
        // Calculate the new origin to keep the rectangle centered
        let newX = origin.x + (width - newWidth) / 2
        let newY = origin.y + (height - newHeight) / 2
        
        // Return the new CGRect
        return CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
    }
}

extension UIImage {
    
    // Method to scale the image to a target size
    func scaled(to targetSize: CGSize) -> UIImage? {
        let size = self.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Determine the scale factor that preserves aspect ratio
        let scaleFactor = min(widthRatio, heightRatio)
        
        // Compute the new size that preserves aspect ratio
        let scaledSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        
        // Create a new bitmap image context
        UIGraphicsBeginImageContextWithOptions(scaledSize, false, 0.0)
        self.draw(in: CGRect(origin: .zero, size: scaledSize))
        
        // Get the scaled image from the context
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
}
extension Data {
    public func getLengthHeader()->Data{
        var length = UInt64(self.count)
        let lengthData = Data(bytes: &length, count: MemoryLayout<UInt64>.size)
        return lengthData
    }
    public func lengtBasedPackage()->Data{
        return getLengthHeader() + self
    }
}
class CamSession {
    static var fov_x :Float?
    static var fov_y :Float?
    static var capturePreset :AVCaptureSession.Preset = .photo
    
    var fov :Float?
    var ratio :Float?
    
    
    
    var captureSession: AVCaptureSession?
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    var videoOutput: AVCaptureVideoDataOutput?
    var vOutWidth: CGFloat?
    var vOutHeight: CGFloat?
    let captureQueue = DispatchQueue(label: "captureQueue")
    
//    let bboxMean : MeanList = MeanList(size:10)
//    let cursorMean : MeanList = MeanList(size:3)
    
    var operation:((CGImage,CVPixelBuffer?) -> ())?
   
    var input:AVCaptureInput?
    var depthInput:AVCaptureInput?
    var cameraTexture:MTLTexture?
    var cameraTextureFlag:Bool
    var isOn:Bool
    var textureCache:CVMetalTextureCache?
    var outputSynchronizer :AVCaptureDataOutputSynchronizer?
    var depthDataOutput:AVCaptureDepthDataOutput?
    var photoOutput: AVCapturePhotoOutput?
    
    static var trueDepthAvailable = false;
    
    
    static func isTrueDepthCameraAvailable()  {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera], mediaType: .video, position: .front)
        let available = !discoverySession.devices.isEmpty
        
       
        if available {
//            let presets:[AVCaptureSession.Preset] = [.photo]
            let presets:[AVCaptureSession.Preset] = [.high,.photo]
            let captureSession = AVCaptureSession()
            presertLoop : for preset in presets{
                
                captureSession.sessionPreset = preset
                
                let camera:AVCaptureDevice.DeviceType = .builtInTrueDepthCamera
                guard let backCamera = AVCaptureDevice.default(camera, for: .video, position: .front) else {
                    CamSession.trueDepthAvailable = false
                    print("Unable to access back camera!")
                    return
                }
                var input:AVCaptureDeviceInput?
                do {
                    input = try AVCaptureDeviceInput(device: backCamera)
                    captureSession.addInput(input!)
                } catch {
                    print("Error adding camera input: \(error)")
                }
                
                let depthFormats = backCamera.activeFormat.supportedDepthDataFormats
                
                
                let filtered = depthFormats.filter({
                    CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat32
                })
//                for f in depthFormats{
//                    print(f.formatDescription)
//                }
                captureSession.removeInput(input!)
                if filtered.count > 0 {
                    CamSession.trueDepthAvailable = true
                    CamSession.capturePreset = preset
                    break presertLoop
                    
                }
                
            }
//            if filtered.count == 0 {
//                CamSession.trueDepthAvailable = false
//            }
        }
    }
    
    
    init(preset: AVCaptureSession.Preset, videoOut: Bool, previewLayer: Bool,callback:AVCaptureDataOutputSynchronizerDelegate,operation:( (CGImage,CVPixelBuffer?) -> ())?,cameraTexture: Bool = false,depthOutput:Bool = false,position: AVCaptureDevice.Position = .front){
        
        self.isOn = false
        self.operation = operation
        self.cameraTextureFlag = cameraTexture
        
//        super.init()
       
        captureSession = AVCaptureSession()
//        captureSession?.sessionPreset = .video
        captureSession?.sessionPreset = preset
       
       
        let camera:AVCaptureDevice.DeviceType = depthOutput ? .builtInTrueDepthCamera : .builtInWideAngleCamera
        
//        let camera:AVCaptureDevice.DeviceType = .
        
//        guard let backCamera = AVCaptureDevice.default(camera, for: .video, position: position) else {
        guard let backCamera = AVCaptureDevice.default(camera, for: .video, position: position) else {
            print("Unable to access back camera!")
            return
        }

        
        let deviceFormat = backCamera.activeFormat
        let resolution = CMVideoFormatDescriptionGetDimensions(deviceFormat.formatDescription)
        print(resolution)
//        ratio = Float(resolution.width)/Float(resolution.height)
//        print(ratio)
        
        do {
            input = try AVCaptureDeviceInput(device: backCamera)
//            let deviceFormat = input.device.activeFormat
//            let resolution = CMVideoFormatDescriptionGetDimensions(deviceFormat.formatDescription)
//            print(resolution)
            captureSession?.addInput(input!)
        } catch {
            print("Error adding camera input: \(error)")
        }

        /*if videoOut {
            videoOutput = AVCaptureVideoDataOutput()
//            videoOutput?.setSampleBufferDelegate(callback, queue: captureQueue)
            videoOutput?.alwaysDiscardsLateVideoFrames = true
            videoOutput?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            captureSession?.addOutput(videoOutput!)
            let videoSettings = videoOutput?.videoSettings!
            vOutWidth = CGFloat(videoSettings![kCVPixelBufferWidthKey as String] as! Float)
            vOutHeight = CGFloat(videoSettings![kCVPixelBufferHeightKey as String] as! Float)
           
//            ratio = Float(vOutWidth!)/Float(vOutHeight!)
            fov = backCamera.activeFormat.videoFieldOfView
//            print(fov)
        }*/
        self.photoOutput = AVCapturePhotoOutput()
        captureSession?.addOutput(photoOutput!)
       
//        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoOutput!])
////        print("depthCallback\(depthCallback)")
//        outputSynchronizer?.setDelegate(callback, queue:captureQueue)
       
        
        if previewLayer{
            cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            cameraPreviewLayer?.videoGravity = .resizeAspectFill
            cameraPreviewLayer?.frame = CGRect(x: 100, y: 100, width: 200, height: 200)
//            cameraPreviewLayer?.zPosition = -0.1
        }
        captureSession?.commitConfiguration()
        
        
    }
    
    
    func release(){
        
   
        captureSession?.removeOutput(videoOutput!)
        print("videoOutput removed")
        captureSession?.removeInput(input!)
        print("videoInput removed")
        captureSession=nil
        cameraPreviewLayer=nil
       
        
    }
    
    func start(){
        
        DispatchQueue.global().async {
            self.captureSession?.startRunning()
            self.isOn = true
        }
    }
    func stop(){
        self.isOn = false
//        DispatchQueue.global().async {
            self.captureSession?.stopRunning()
//        }
    }
//    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    func captureOutput( didOutput sampleBuffer: CMSampleBuffer, depth:CVPixelBuffer?) {

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        if cameraTextureFlag{
            var cvTexture: CVMetalTexture?
            CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache!, imageBuffer, nil, .bgra8Unorm, CVPixelBufferGetWidth(imageBuffer), CVPixelBufferGetHeight(imageBuffer), 0, &cvTexture)
            guard let metalTexture = cvTexture else { return }
            
            // Get the Metal texture from the CVMetalTexture
            cameraTexture = CVMetalTextureGetTexture(metalTexture)
            
        }
        
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
//        var depthCIImage:CIImage?
//        if depth != nil {
//            depthCIImage = CIImage(cvPixelBuffer: depth!)
//
//        }
        if let op = self.operation{
            op(cgImage,depth)
        }
//        if operation != nil {
//            self.operation!(cgImage)
//        }
      
        
    }
    
    
}
