//
//  MetalCameraSession.swift
//  MetalCamera
//
//  Created by Boris Dering on 14.04.20.
//  Copyright © 2020 Boris Dering. All rights reserved.
//

import AVFoundation

typealias VideoOrientation = AVCaptureVideoOrientation
typealias CameraPosition = AVCaptureDevice.Position

protocol MetalCameraSessionDelegate: class {
    func capture(output sampleBuffer: CMSampleBuffer, orientation: VideoOrientation)
}

class MetalCameraSession: NSObject {
    
    weak var delegate: MetalCameraSessionDelegate?
    
    private var session = AVCaptureSession()
    
    var currentPosition: AVCaptureDevice.Position {
        let input = self.session.inputs.first as? AVCaptureDeviceInput
        guard let position = input?.device.position else { return .unspecified }
        return position
    }
    
    private var dispatchQueue = DispatchQueue(label: "camera.session.queue")
    
    init(_ positon: CameraPosition = .front) {
        super.init()
        
        self.setupSession(positon)
    }
    
    private func setupSession(_ position: CameraPosition = .front) {
        
        self.dispatchQueue.async { [weak self] in
            
            guard let instance = self else {
                // log something...
                return
            }

            try? instance.setupInputs(with: instance.session, and: position)
            try? instance.setupOutputs(with: instance.session)
        }
    }
    
    private func setupInputs(with session: AVCaptureSession, and position: CameraPosition) throws {
        
        session.beginConfiguration()
        
        session.inputs.forEach { (input) in
            session.removeInput(input)
        }
        
        guard let camera = AVCaptureDevice.DiscoverySession.cameraDevice(with: position) else { return }
//            throw CameraSession.SessionError.failed(message: "unable setup camera for positon \(position).") }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: camera) else { return }
//            throw CameraSession.SessionError.failed(message: "unable to setup camera input for position \(position).")}
        
        guard session.canAddInput(videoInput) else { return }
//            throw CameraSession.SessionError.failed(message: "unable to add camera input for \(position).") }
        session.addInput(videoInput)
        
        camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        session.sessionPreset = .hd1920x1080
        
        session.commitConfiguration()
        
        self.start()
    }
    
    private func setupOutputs(with session: AVCaptureSession, on dispathQueue: DispatchQueue = DispatchQueue.main) throws {
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        output.setSampleBufferDelegate(self, queue: self.dispatchQueue)
        output.alwaysDiscardsLateVideoFrames = false
        
        guard session.canAddOutput(output) else { return }
//            throw CameraSession.SessionError.failed(message: "unable to add capture output.") }
        session.addOutput(output)
    }
    
//    func requestPermission() -> Promises.Promise<Bool> {
//        return Promises.wrap { (handler) in
//            AVCaptureDevice.requestAccess(for: .video, completionHandler: handler)
//        }
//    }
    
    func changeCamera() {
        let positon: CameraPosition = (self.currentPosition == .front) ? .back : .front
        try? self.setupInputs(with: self.session, and: positon)
    }
    
    func start() {
        self.session.startRunning()
    }
    
    func stop() {
        self.session.stopRunning()
    }
}

extension MetalCameraSession {
    enum SessionError: Error {
        case failed(message: String)
    }
}

extension MetalCameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("did drop")
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.delegate?.capture(output: sampleBuffer, orientation: connection.videoOrientation)
    }
}

/// Extension to access used device easier.
extension AVCaptureDevice.DiscoverySession {
    static func cameraDevice(with position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: position).devices.first
    }
    
    static func microphoneDevice() -> AVCaptureDevice? {
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone],
            mediaType: .audio,
            position: .unspecified).devices.first
    }
}

extension AVCaptureVideoOrientation: CustomStringConvertible {
    public var description: String {
        switch self {
            case .portrait:
            return "portrait"
            case .portraitUpsideDown:
            return "portraitUpsideDown"
            case .landscapeRight:
            return "landscapeRight"
            case .landscapeLeft:
            return "landscapeLeft"
            @unknown default:
            fatalError()
        }
    }
}
