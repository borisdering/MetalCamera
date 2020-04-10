//
//  MetalCamera.swift
//  MetalCamera
//
//  Created by Boris Dering on 09.04.20.
//  Copyright © 2020 Boris Dering. All rights reserved.
//

import UIKit
import AVFoundation

open class MetalCameraViewController: UIViewController {
    
    var captureSession: AVCaptureSession!
    var queue: DispatchQueue!
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == .authorized {
            self.setupCamera()
        } else {
            AVCaptureDevice.requestAccess(for: AVMediaType.video) { [weak self] (result) in
                self?.setupCamera()
            }
        }
    }

    open func setupCamera() {
        
        self.captureSession = AVCaptureSession()
        let device = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: AVCaptureDevice.Position.back)!
        let input = try! AVCaptureDeviceInput(device: device)
        
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = false
        self.queue = DispatchQueue(label: "video_capture_queue")
        output.setSampleBufferDelegate(self, queue: self.queue)
        
        self.captureSession.addInput(input)
        self.captureSession.addOutput(output)
        
        let previewLayaer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        previewLayaer.frame = self.view.bounds
        self.view.layer.addSublayer(previewLayaer)
        
        self.captureSession.startRunning()
    }
    
    func authorizationStatus() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
    }
}

extension MetalCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        print("did output sample buffer...")
    }
}
