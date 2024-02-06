//
//  PreviewView.swift
//  Poc
//
//  Created by Alan Silva on 05/02/24.
//

import Foundation
import AVFoundation
import UIKit

// MARK: PreviewView
class PreviewView: UIView {
    
    var shouldUseClipboardImage: Bool = false
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Layer expected is of type VideoPreviewLayer")
        }
        return layer
    }
    
    var session: AVCaptureSession? {
        get {
            return previewLayer.session
        }
        set {
            previewLayer.session = newValue
        }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
}
