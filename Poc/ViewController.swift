//
//  ViewController.swift
//  Poc
//
//  Created by Alan Silva on 05/02/24.
//

import UIKit
import AVFoundation

protocol ScanBarcodeDelegate {
    func userDidScanWith(barcode: String)
}

class ViewController: UIViewController {
    
    //✅ok
    
    private lazy var leftContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.alpha = 0.8
        
        return view
    }()
    
    private var previewView: PreviewView = {
        let view = PreviewView()
        return view
    }()
    
    private lazy var rightContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.alpha = 0.8
        
        return view
    }()
    
    private lazy var barCodeGuideView: UIView = {
        let view = UIView()
        view.backgroundColor = .yellow
        
        return view
    }()
    
    private let supportedCodeTypes = [AVMetadataObject.ObjectType.upce,
                                      AVMetadataObject.ObjectType.code39,
                                      AVMetadataObject.ObjectType.code39Mod43,
                                      AVMetadataObject.ObjectType.code93,
                                      AVMetadataObject.ObjectType.code128,
                                      AVMetadataObject.ObjectType.ean8,
                                      AVMetadataObject.ObjectType.ean13,
                                      AVMetadataObject.ObjectType.aztec,
                                      AVMetadataObject.ObjectType.pdf417,
                                      AVMetadataObject.ObjectType.itf14,
                                      AVMetadataObject.ObjectType.dataMatrix,
                                      AVMetadataObject.ObjectType.interleaved2of5,
                                      AVMetadataObject.ObjectType.qr]
    public var delegate: ScanBarcodeDelegate? = nil
    private var captureSession = AVCaptureSession()
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var qrCodeFrameView: UIView?
    private var scanlineRect = CGRect.zero
    private var scanlineStartY: CGFloat = 0
    private var scanlineStopY: CGFloat = 0
    private var topBottomMargin: CGFloat = 80
    private var scanLine: UIView = UIView()
    var screenSize = UIScreen.main.bounds
    private var isOrientationPortrait = true
    var screenHeight:CGFloat = 0
    let captureMetadataOutput = AVCaptureMetadataOutput()
    
    private lazy var xCor: CGFloat! = {
        return self.isOrientationPortrait ? (screenSize.width - (screenSize.width*0.8))/2 :
            (screenSize.width - (screenSize.width*0.6))/2
    }()
    private lazy var yCor: CGFloat! = {
        return self.isOrientationPortrait ? (screenSize.height - (screenSize.width*0.8))/2 :
            (screenSize.height - (screenSize.height*0.8))/2
    }()
    //Bottom view
    private lazy var bottomView : UIView! = {
        let view = UIView()
        view.backgroundColor = UIColor.black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    /// Create and return flash button
    private lazy var flashIcon : UIButton! = {
        let flashButton = UIButton()
        flashButton.setTitle("Flash",for:.normal)
        flashButton.translatesAutoresizingMaskIntoConstraints=false

        flashButton.addTarget(self, action: #selector(flashButtonClicked), for: .touchUpInside)
        return flashButton
    }()
    
    /// Create and return switch camera button
    private lazy var switchCameraButton : UIButton! = {
        let button = UIButton()
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(switchCameraButtonClicked), for: .touchUpInside)
        
        return button
    }()
    
    
    /// Create and return cancel button
    public lazy var cancelButton: UIButton! = {
        let view = UIButton()
        view.setTitle("Cancelar", for: .normal)
        view.translatesAutoresizingMaskIntoConstraints = false
        //view.addTarget(self, action: #selector(cancelButtonClicked), for: .touchUpInside)
        return view
    }()
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.isOrientationPortrait = isLandscape
        self.initUIComponents()
        setupConstraints()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.moveVertically()
    }

    override public func viewDidDisappear(_ animated: Bool){
        // Stop video capture
        captureSession.stopRunning()
    }
    
    // Init UI components needed
    func initUIComponents(){
        screenHeight = (screenSize.height * 0.5)
        self.initBarcodeComponents()
    }
    
    private func setupConstraints() {
        [
            leftContainerView,
            previewView,
            rightContainerView,
            barCodeGuideView
        ].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        let g = self.view!
        
        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            previewView.leadingAnchor.constraint(equalTo: leftContainerView.trailingAnchor),
            previewView.trailingAnchor.constraint(equalTo: rightContainerView.leadingAnchor)
        ])
        
        NSLayoutConstraint.activate([
            leftContainerView.topAnchor.constraint(equalTo: g.topAnchor),
            leftContainerView.bottomAnchor.constraint(equalTo: g.bottomAnchor),
            leftContainerView.leadingAnchor.constraint(equalTo: g.leadingAnchor),
            leftContainerView.widthAnchor.constraint(equalToConstant: 80.0)
        ])
        
        NSLayoutConstraint.activate([
            rightContainerView.topAnchor.constraint(equalTo: g.topAnchor),
            rightContainerView.bottomAnchor.constraint(equalTo: g.bottomAnchor),
            rightContainerView.widthAnchor.constraint(equalToConstant: 80.0),
            rightContainerView.trailingAnchor.constraint(equalTo: g.trailingAnchor)
        ])
        
        NSLayoutConstraint.activate([
            barCodeGuideView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            barCodeGuideView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            barCodeGuideView.heightAnchor.constraint(equalToConstant: 2.0),
            barCodeGuideView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -50),
            barCodeGuideView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 50)
        ])
        
        barCodeGuideView.layer.cornerRadius = 1
        
        let radians = 90 / 180.0 * CGFloat.pi
        barCodeGuideView.transform = barCodeGuideView.transform.rotated(by: radians)
        
    }
    
    
    // Inititlize components
    func initBarcodeComponents(){
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back)
        // Get the back-facing camera for capturing videos
        guard let captureDevice = deviceDiscoverySession.devices.first else {
            print("Failed to get the camera device")
            return
        }
        
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            // Set the input device on the capture session.
            if captureSession.inputs.isEmpty {
                captureSession.addInput(input)
            }
            // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
            
            let captureRectWidth = self.isOrientationPortrait ? (screenSize.width*0.8):(screenSize.height*0.8)
            
            captureMetadataOutput.rectOfInterest = CGRect(x: xCor, y: yCor, width: captureRectWidth, height: screenHeight)
            if captureSession.outputs.isEmpty {
                captureSession.addOutput(captureMetadataOutput)
            }
            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = supportedCodeTypes
            //            captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = view.layer.bounds
        
        setVideoPreviewOrientation()
        //videoPreviewLayer?.connection?.videoOrientation = self.isOrientationPortrait ? AVCaptureVideoOrientation.portrait : AVCaptureVideoOrientation.landscapeRight
        
        self.drawUIOverlays{
        }
    }
    
    
    func drawUIOverlays(withCompletion processCompletionCallback: () -> Void){
        //    func drawUIOverlays(){
        let overlayPath = UIBezierPath(rect: view.bounds)
        
        let transparentPath = UIBezierPath(rect: CGRect(x: xCor, y: yCor, width: self.isOrientationPortrait ? (screenSize.width*0.8) : (screenSize.height*0.8), height: screenHeight))
        
        overlayPath.append(transparentPath)
        overlayPath.usesEvenOddFillRule = true
        let fillLayer = CAShapeLayer()
        
        fillLayer.path = overlayPath.cgPath
        fillLayer.fillRule = CAShapeLayerFillRule.evenOdd
        fillLayer.fillColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).cgColor
        
        videoPreviewLayer?.layoutSublayers()
        videoPreviewLayer?.layoutIfNeeded()
        
        view.layer.addSublayer(videoPreviewLayer!)
        
        
        // Start video capture.
        DispatchQueue.global().async {
            self.captureSession.startRunning()
        }
        
        let scanRect = CGRect(x: xCor, y: yCor, width: self.isOrientationPortrait ? (screenSize.width*0.8) : (screenSize.height*0.8), height: screenHeight)
        
        
        let rectOfInterest = videoPreviewLayer?.metadataOutputRectConverted(fromLayerRect: scanRect)
        if let rOI = rectOfInterest{
            captureMetadataOutput.rectOfInterest = rOI
        }
        // Initialize QR Code Frame to highlight the QR code
        qrCodeFrameView = UIView()
        
        qrCodeFrameView!.frame = CGRect(x: 0, y: 0, width: self.isOrientationPortrait ? (screenSize.width * 0.8) : (screenSize.height * 0.8), height: screenHeight)
        
        
        if let qrCodeFrameView = qrCodeFrameView {
            self.view.addSubview(qrCodeFrameView)
            self.view.bringSubviewToFront(qrCodeFrameView)
            qrCodeFrameView.layer.insertSublayer(fillLayer, below: videoPreviewLayer!)
            self.view.bringSubviewToFront(bottomView)
            self.view.bringSubviewToFront(flashIcon)
            qrCodeFrameView.layoutIfNeeded()
            qrCodeFrameView.layoutSubviews()
            qrCodeFrameView.setNeedsUpdateConstraints()
            self.view.bringSubviewToFront(cancelButton)
            self.view.bringSubviewToFront(switchCameraButton)
        }
        
        self.drawLine()
        processCompletionCallback()
    }
    
    /// Flash button click event listener
    @IBAction private func flashButtonClicked() {
        if #available(iOS 10.0, *) {
            toggleFlash()
        } else {
            /// Handle further checks
        }
    }
    
    private func flashIconOff() {
       // flashIcon.setImage(UIImage(named: "ic_flash_off", in: Bundle(for: SwiftFlutterBarcodeScannerPlugin.self), compatibleWith: nil),for:.normal)
    }
    
    private func flashIconOn() {
        //flashIcon.setImage(UIImage(named: "ic_flash_on", in: Bundle(for: SwiftFlutterBarcodeScannerPlugin.self), compatibleWith: nil),for:.normal)
    }
    
    private func setFlashStatus(device: AVCaptureDevice, mode: AVCaptureDevice.TorchMode) {
        guard device.hasTorch else {
            flashIconOff()
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if (mode == .off) {
                device.torchMode = AVCaptureDevice.TorchMode.off
                flashIconOff()
            } else {
                // Treat .auto & .on equally.
                do {
                    try device.setTorchModeOn(level: 1.0)
                    flashIconOn()
                } catch {
                    print(error)
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    /// Toggle flash and change flash icon
    func toggleFlash() {
        guard let device = getCaptureDeviceFromCurrentSession(session: captureSession) else {
            flashIconOff()
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if (device.torchMode == AVCaptureDevice.TorchMode.off) {
                setFlashStatus(device: device, mode: .on)
            } else {
                setFlashStatus(device: device, mode: .off)
            }
            
            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    /// Switch camera button click event listener
    @IBAction private func switchCameraButtonClicked() {
        // Get the current active input.
        guard let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else { return }
        //let newPosition = getInversePosition(position: currentInput.device.position);
        guard let device = getCaptureDeviceByPosition(position: AVCaptureDevice.Position.back) else { return }
        do {
            let newInput = try AVCaptureDeviceInput(device: device)
            // Replace current input with the new one.
            captureSession.removeInput(currentInput)
            captureSession.addInput(newInput)
            // Disable flash by default
            setFlashStatus(device: device, mode: .off)
        } catch let error {
            print(error)
            return
        }
    }
    
    private func getCaptureDeviceFromCurrentSession(session: AVCaptureSession) -> AVCaptureDevice? {
        // Get the current active input.
        guard let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else { return nil }
        return currentInput.device;
    }
    
    private func getCaptureDeviceByPosition(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // List all capture devices
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [ .builtInWideAngleCamera ], mediaType: AVMediaType.video, position: .unspecified).devices
        for device in devices {
            if device.position == position {
                return device
            }
        }
        
        return nil;
    }
    
    /// Draw scan line
    private func drawLine() {
        self.view.addSubview(scanLine)
        //scanLine.backgroundColor = hexStringToUIColor(hex: SwiftFlutterBarcodeScannerPlugin.lineColor)
        scanlineRect = CGRect(x: xCor, y: yCor, width:self.isOrientationPortrait ? (screenSize.width*0.8) : (screenSize.height*0.8), height: 2)
        
        scanlineStartY = yCor
        
        var stopY:CGFloat
        
//        if SwiftFlutterBarcodeScannerPlugin.scanMode == ScanMode.QR.index {
//            let w = self.isOrientationPortrait ? (screenSize.width*0.8) : (screenSize.height*0.6)
//            stopY = (yCor + w)
//        } else {
            let w = self.isOrientationPortrait ? (screenSize.width * 0.5) : (screenSize.height * 0.5)
            stopY = (yCor + w)
        //}
        scanlineStopY = stopY
    }
    
    /// Animate scan line vertically
    private func moveVertically() {
        scanLine.frame  = scanlineRect
        scanLine.center = CGPoint(x: scanLine.center.x, y: scanlineStartY)
        scanLine.isHidden = false
        weak var weakSelf = scanLine
        UIView.animate(withDuration: 2.0, delay: 0.0, options: [.repeat, .autoreverse, .beginFromCurrentState], animations: {() -> Void in
            weakSelf!.center = CGPoint(x: weakSelf!.center.x, y: self.scanlineStopY)
        }, completion: nil)
    }
    
    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
    }
    
    var isLandscape: Bool {
        return UIDevice.current.orientation.isValidInterfaceOrientation
            ? UIDevice.current.orientation.isPortrait
            : UIApplication.shared.statusBarOrientation.isPortrait
    }
    
//    private func launchApp(decodedURL: String) {
//        if presentedViewController != nil {
//            return
//        }
//        if self.delegate != nil {
//            self.dismiss(animated: true, completion: {
//                self.delegate?.userDidScanWith(barcode: decodedURL)
//            })
//        }
//    }
}

/// Extension for view controller
extension ViewController: AVCaptureMetadataOutputObjectsDelegate {
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            return
        }
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        if supportedCodeTypes.contains(metadataObj.type) {
            // If the found metadata is equal to the QR code metadata (or barcode) then update the status label's text and set the bounds
            //            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            //qrCodeFrameView?.frame = barCodeObject!.bounds
            if metadataObj.stringValue != nil {
//                if(SwiftFlutterBarcodeScannerPlugin.isContinuousScan){
//                    SwiftFlutterBarcodeScannerPlugin.onBarcodeScanReceiver(barcode: metadataObj.stringValue!)
//                }else{
                
                    //launchApp(decodedURL: metadataObj.stringValue!)
                let alertController = UIAlertController(title: "QR Code detectado", message: metadataObj.stringValue, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                
                present(alertController, animated: true, completion: nil)
                //}
            }
        }
    }
}

// Handle auto rotation
extension ViewController {
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateUIAfterRotation()
    }
    
    func updateUIAfterRotation(){
        DispatchQueue.main.async {
            if UIDevice.current.orientation == .portrait || UIDevice.current.orientation == .portraitUpsideDown {
                self.isOrientationPortrait = true
            }else{
                self.isOrientationPortrait = false
            }
            //self.isOrientationPortrait = self.isLandscape
            
            self.screenSize = UIScreen.main.bounds
            
            if UIDevice.current.orientation == .portrait || UIDevice.current.orientation == .portraitUpsideDown {
                self.screenHeight = (self.screenSize.width * 0.5)
                
            } else {
                self.screenHeight = (self.screenSize.height * 0.5)
            }
            
            
            self.videoPreviewLayer?.frame = self.view.layer.bounds
            
            self.setVideoPreviewOrientation()
            self.xCor = self.isOrientationPortrait ? (self.screenSize.width - (self.screenSize.width*0.8))/2 :
                (self.screenSize.width - (self.screenSize.width*0.6))/2
            
            self.yCor = self.isOrientationPortrait ? (self.screenSize.height - (self.screenSize.width*0.8))/2 :
                (self.screenSize.height - (self.screenSize.height*0.8))/2
            
            self.videoPreviewLayer?.layoutIfNeeded()
            self.removeAllViews {
                self.drawUIOverlays{
                    //self.scanlineRect = CGRect(x: self.xCor, y: self.yCor, width:self.isOrientationPortrait ? (self.screenSize.width*0.8) : (self.screenSize.height*0.8), height: 2)
                    self.scanLine.frame  = self.scanlineRect
                    self.scanLine.center = CGPoint(x: self.scanLine.center.x, y: self.scanlineStopY)
                    //                self.moveVertically()
                }
            }
        }
    }
    
    // Set video preview orientation
    func setVideoPreviewOrientation(){
        switch(UIDevice.current.orientation){
        case .unknown:
            self.videoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
            break
        case .portrait:
            self.videoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
            break
        case .portraitUpsideDown:
            self.videoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portraitUpsideDown
            break
        case .landscapeLeft:
            self.videoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
            break
        case .landscapeRight:
            self.videoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
            break
        case .faceUp:
            self.videoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
            break
        case .faceDown:
            self.videoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
            break
        @unknown default:
            self.videoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
            break
        }
    }
    
    
    /// Remove all subviews from superviews
    func removeAllViews(withCompletion processCompletionCallback: () -> Void){
        for view in self.view.subviews {
            view.removeFromSuperview()
        }
        processCompletionCallback()
    }
}

/// Convert hex string to UIColor
func hexStringToUIColor (hex:String) -> UIColor {
    var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    
    if (cString.hasPrefix("#")) {
        cString.remove(at: cString.startIndex)
    }
    
    if ((cString.count) != 6 && (cString.count) != 8) {
        return UIColor.gray
    }
    
    var rgbaValue:UInt32 = 0
    
    if (!Scanner(string: cString).scanHexInt32(&rgbaValue)) {
        return UIColor.gray
    }
    
    var aValue:CGFloat = 1.0
    if ((cString.count) == 8) {
        aValue = CGFloat((rgbaValue & 0xFF000000) >> 24) / 255.0
    }
    
    let rValue:CGFloat = CGFloat((rgbaValue & 0x00FF0000) >> 16) / 255.0
    let gValue:CGFloat = CGFloat((rgbaValue & 0x0000FF00) >> 8) / 255.0
    let bValue:CGFloat = CGFloat(rgbaValue & 0x000000FF) / 255.0
    
    return UIColor(
        red: rValue,
        green: gValue,
        blue: bValue,
        alpha: aValue
    )
}
