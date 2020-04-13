//
//  MetalCamera.swift
//  MetalCamera
//
//  Created by Boris Dering on 09.04.20.
//  Copyright © 2020 Boris Dering. All rights reserved.
//

import UIKit
import AVFoundation

/// This protocol is used to log every peace that goes on in this libary
/// so you are free to use this protocol to be able to use
/// your own logger implementation 
public protocol MetalCameraLogger {
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

open class MetalCameraViewController: UIViewController {
    
    /// Dispatch queue to use to avoid freezing main thred
    open var queue = DispatchQueue(label: "video_capture_queue")
    
    var captureSession: AVCaptureSession?
    
    open var logger: MetalCameraLogger?
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        // check for authorization status and request permissions if needed
        if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == .authorized {
            self.setupCamera()
        } else {
            AVCaptureDevice.requestAccess(for: AVMediaType.video) { [weak self] (result) in
                self?.setupCamera()
            }
        }
    }

    open func setupCamera() {
        
        self.queue.async { [weak self] in
            
            self?.createCaptureSession()
            
            do {
                guard let device = try self?.videoDevice(for: AVCaptureDevice.Position.back) else { return }
                
                guard let input = try self?.createDeviceInput(for: device) else { return }
                
                try self?.addInput(input)
                
                guard let output = self?.createCaptureOutput() else { return }
                
                try self?.addOutput(output)
                
                try self?.setupPreview()
                
                self?.startRunning()
            } catch {
                self?.logger?.error(error.localizedDescription)
            }
        }
    }
    
    open func createCaptureSession() {
        self.captureSession = AVCaptureSession()
    }
    
    open func addOutput(_ output: AVCaptureOutput) throws {
        guard self.captureSession?.canAddOutput(output) ?? false else { throw MetalCameraError.outputUnavailable }
        self.captureSession?.addOutput(output)
    }
    
    open func createCaptureOutput() -> AVCaptureOutput {
        
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = false
        output.setSampleBufferDelegate(self, queue: self.queue)
        
        return output
    }
    
    open func videoDevice(for position: AVCaptureDevice.Position) throws -> AVCaptureDevice {
        guard let device = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: position)
            else { throw MetalCameraError.deviceNotFound }
        
        return device
    }
    
    open func createDeviceInput(for device: AVCaptureDevice) throws -> AVCaptureDeviceInput {
        return try AVCaptureDeviceInput(device: device)
    }
    
    open func addInput(_ input: AVCaptureInput) throws {
        guard self.captureSession?.canAddInput(input) ?? false else { throw MetalCameraError.cannotAddInput("") }
        self.captureSession?.addInput(input)
    }
    
    open func startRunning() {
        self.captureSession?.startRunning()
    }
    
    open func stopRunning() {
        self.captureSession?.stopRunning()
    }
    
    open func setupPreview() throws {
        
        guard let session = self.captureSession else { throw MetalCameraError.captureSessionUnavailable }
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        
        DispatchQueue.main.async { [weak self] in
            layer.frame = self?.view.bounds ?? UIScreen.main.bounds
            self?.view.layer.addSublayer(layer)
        }
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

enum MetalCameraError: Error {
    case captureSessionUnavailable
    case cannotAddInput(_ message: String)
    case deviceNotFound
    case outputUnavailable
}
