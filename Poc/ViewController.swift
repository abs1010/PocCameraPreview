//
//  ViewController.swift
//  Poc
//
//  Created by Alan Silva on 05/02/24.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
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
    
    /// Create and return flash button
    private lazy var flashIcon : UIButton! = {
        let flashButton = UIButton()
        flashButton.setTitle("Flash",for:.normal)
        flashButton.translatesAutoresizingMaskIntoConstraints=false
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        return flashButton
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
    private var captureSession = AVCaptureSession()
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var qrCodeFrameView = UIView()
    private var screenSize = UIScreen.main.bounds
    private var screenHeight:CGFloat = 0
    private let captureMetadataOutput = AVCaptureMetadataOutput()
    
    private lazy var xCor: CGFloat = {
        return (screenSize.width - (screenSize.width*0.8))/2
    }()
    
    private lazy var yCor: CGFloat = {
        return (screenSize.height - (screenSize.width*0.8))/2
    }()
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        screenHeight = (screenSize.height * 0.5)
        initComponents()
        setupConstraints()
    }
    
    override public func viewDidDisappear(_ animated: Bool){
        // Stop video capture
        captureSession.stopRunning()
    }
    
    private func setupConstraints() {
        [
            leftContainerView,
            previewView,
            rightContainerView,
            barCodeGuideView,
            flashIcon
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
        
        NSLayoutConstraint.activate([
            flashIcon.heightAnchor.constraint(equalToConstant: 16.0),
            flashIcon.centerXAnchor.constraint(equalTo: rightContainerView.centerXAnchor),
            flashIcon.centerYAnchor.constraint(equalTo: rightContainerView.centerYAnchor)
        ])
        
        barCodeGuideView.layer.cornerRadius = 1
        
        let radians = 90 / 180.0 * CGFloat.pi
        barCodeGuideView.transform = barCodeGuideView.transform.rotated(by: radians)
        flashIcon.transform = flashIcon.transform.rotated(by: radians)
        
    }
    
    // Inititlize components
    func initComponents(){
        
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
            let captureRectWidth = (screenSize.width*0.8)
            
            captureMetadataOutput.rectOfInterest = CGRect(x: xCor, y: yCor, width: captureRectWidth, height: screenHeight)
            if captureSession.outputs.isEmpty {
                captureSession.addOutput(captureMetadataOutput)
            }
            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = supportedCodeTypes
            
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = view.layer.bounds
        videoPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        
        // Start video capture.
        DispatchQueue.global().async {
            self.captureSession.startRunning()
        }
        
        drawOverlays()
    }
    
    func drawOverlays() {
        let overlayPath = UIBezierPath(rect: view.bounds)
        let transparentPath = UIBezierPath(rect: CGRect(x: (screenSize.width / 2) - 75,
                                                        y: (screenSize.height - (screenSize.height*0.6))/2,
                                                        width: 150,
                                                        height: screenSize.height * 0.6))
        
        overlayPath.append(transparentPath)
        overlayPath.usesEvenOddFillRule = true
        let fillLayer = CAShapeLayer()
        fillLayer.path = overlayPath.cgPath
        fillLayer.fillRule = CAShapeLayerFillRule.evenOdd
        fillLayer.fillColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).cgColor
        videoPreviewLayer?.layoutSublayers()
        videoPreviewLayer?.layoutIfNeeded()
        
        view.layer.addSublayer(videoPreviewLayer!)

        // Initialize a Frame to highlight the scanned area
        
        let scannedArea = CGRect(x: xCor, 
                                 y: yCor,
                                 width: (screenSize.width*0.8),
                                 height: screenHeight)
        let rectOfInterest = videoPreviewLayer?.metadataOutputRectConverted(fromLayerRect: scannedArea)
        
        if let rOI = rectOfInterest{
            captureMetadataOutput.rectOfInterest = rOI
        }
        
        view.addSubview(qrCodeFrameView)
        view.bringSubviewToFront(qrCodeFrameView)
        qrCodeFrameView.layer.insertSublayer(fillLayer, below: videoPreviewLayer!)
        qrCodeFrameView.layoutIfNeeded()
        qrCodeFrameView.layoutSubviews()
        qrCodeFrameView.setNeedsUpdateConstraints()
    }
    
    private func setFlashStatus(device: AVCaptureDevice, mode: AVCaptureDevice.TorchMode) {
        guard device.hasTorch else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if (mode == .off) {
                device.torchMode = AVCaptureDevice.TorchMode.off
            } else {
                
                try device.setTorchModeOn(level: 1.0)
                
            }
            
            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    /// Toggle flash and change flash icon
    @objc func toggleFlash() {
        guard let device = getCaptureDeviceFromCurrentSession(session: captureSession) else {
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
    
    private func getCaptureDeviceFromCurrentSession(session: AVCaptureSession) -> AVCaptureDevice? {
        // Get the current active input.
        guard let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else {
            return nil
        }
        return currentInput.device;
    }
    
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate Extension
extension ViewController: AVCaptureMetadataOutputObjectsDelegate {
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            qrCodeFrameView.frame = CGRect.zero
            return
        }
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        if supportedCodeTypes.contains(metadataObj.type) {
            if metadataObj.stringValue != nil {
                let alertController = UIAlertController(title: "QR Code detectado", message: metadataObj.stringValue, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                present(alertController, animated: true, completion: nil)
            }
        }
    }
}
