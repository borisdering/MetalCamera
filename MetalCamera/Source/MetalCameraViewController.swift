//
//  MetalCamera.swift
//  MetalCamera
//
//  Created by Boris Dering on 09.04.20.
//  Copyright © 2020 Boris Dering. All rights reserved.
//

import UIKit
import AVFoundation
import MetalKit

/// This protocol is used to log every peace that goes on in this libary
/// so you are free to use this protocol to be able to use
/// your own logger implementation 
public protocol MetalCameraLogger {
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

open class MetalCameraViewController: UIViewController {
    
    open var logger: MetalCameraLogger?
    
    var cameraSession: MetalCameraSession?
    
    lazy var renderer: MetalCameraRenderer = {
        
        let renderer = MetalCameraRenderer()
        renderer.delegate = self
        renderer.isMirroringEnabled = true
        
        return renderer
    }()
    
    override open func loadView() {
        super.loadView()
        
        self.view.backgroundColor = UIColor.clear
        self.view.insertSubview(self.renderer.view, at: 0)
        self.renderer.view.frame = UIScreen.main.bounds
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.cameraSession = MetalCameraSession()
        self.cameraSession?.delegate = self
    }
}

extension MetalCameraViewController: MetalCameraSessionDelegate {
    func capture(output sampleBuffer: CMSampleBuffer, orientation: VideoOrientation) {
        self.renderer.render(sampleBuffer)
    }
}

extension MetalCameraViewController: MetalCameraRendererDelegate {
    func didRender(texture: MTLTexture) {
        
    }
}

enum MetalCameraError: Error {
    case captureSessionUnavailable
    case cannotAddInput(_ message: String)
    case deviceNotFound
    case outputUnavailable
}
