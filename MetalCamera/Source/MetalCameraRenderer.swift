//
//  Renderer.swift
//  MetalCamera
//
//  Created by Boris Dering on 14.04.20.
//  Copyright © 2020 Boris Dering. All rights reserved.
//

import MetalKit
import AVKit

protocol MetalCameraRendererDelegate: class {
    func didRender(texture: MTLTexture)
}

class MetalCameraRenderer: NSObject {
    
    private struct Constants {
        var movedBy: SIMD2<Float>
        var isMirrored: Bool
    }
    
    weak var delegate: MetalCameraRendererDelegate?
    
    var isMirroringEnabled: Bool = false {
        didSet {
            self.constants.isMirrored = self.isMirroringEnabled
        }
    }
    
    private var device: MTLDevice?
    
    private var library: MTLLibrary?
    
    private var commandQueue: MTLCommandQueue?
    
    /// Texture cache we will use for converting frame images to textures
    private var textureCache: CVMetalTextureCache?
    
    /// Metal texture to be drawn whenever the view controller is asked to render its view.
    /// Please note that if you set this `var` too frequently some of the textures may not being drawn,
    /// as setting a texture does not force the view controller's view to render its content.
    private var texture: MTLTexture?
    
    private var textureMappingRenderPipelineState: MTLRenderPipelineState?
    private var textureMappingSamplerState: MTLSamplerState?
    
    /// Keeps track of current time to be able to add
    /// special effects to video later on.
    private var currentTime: Float = 0
    
    private var constants: Constants
    
    /// View which displays the rendered video.
    lazy var view: MTKView = {
        
        let view = MTKView(frame: UIScreen.main.bounds, device: self.device)
        view.clearColor = MTLClearColor(red: 0.0, green: 0, blue: 0, alpha: 1.0)
        view.colorPixelFormat = MTLPixelFormat.bgra8Unorm
        view.framebufferOnly = false
        view.contentScaleFactor = UIScreen.main.scale
        view.autoResizeDrawable = false
        view.preferredFramesPerSecond = 30
        view.drawableSize = CGSize(width: 1080, height: 1920)
        view.delegate = self
        
        return view
    }()
    
    override init() {
    
        self.constants = Constants(movedBy: SIMD2<Float>(repeating: 0), isMirrored: self.isMirroringEnabled)
        super.init()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("unable to initilize metal device...")
        }
        
        // following this post on stackoverflow to load in .metal files due to the issue
        // that we are not able use the "default" library.
        // @link: https://stackoverflow.com/questions/46742403/metal-file-as-part-of-an-ios-framework
        let bundle = Bundle(for: type(of: self))
        guard let library = try? device.makeDefaultLibrary(bundle: bundle) else { fatalError() }
            
        self.device = device
        self.library = library
        self.commandQueue = self.makeCommandQueue(with: device)
        self.makeTextureCache(with: device, and: &self.textureCache)
        self.textureMappingRenderPipelineState = self.makeTextureMappingRenderPipelineState(with: device, and: library)
        self.textureMappingSamplerState = self.makeTextureMappingSamplerState(with: device)
    }
    
    private func makeCommandQueue(with device: MTLDevice) -> MTLCommandQueue? {
        return device.makeCommandQueue()
    }
    
    private func makeTextureCache(with device: MTLDevice, and cache: inout CVMetalTextureCache?) {
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache) == kCVReturnSuccess else { fatalError("unable to initialize texture cache.") }
    }
    
    private func makeTextureMappingRenderPipelineState(with device: MTLDevice, and library: MTLLibrary) -> MTLRenderPipelineState {
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.vertexFunction = library.makeFunction(name: "vertex_default_video_shader")
        descriptor.fragmentFunction = library.makeFunction(name: "fragment_default_video_shader")
        
        return try! device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    private func makeTextureMappingSamplerState(with device: MTLDevice) -> MTLSamplerState? {
        
        let descriptor = MTLSamplerDescriptor()
        descriptor.magFilter = .nearest
        descriptor.minFilter = .nearest
        
        return device.makeSamplerState(descriptor: descriptor)
    }
    
    func render(_ sampleBuffer: CMSampleBuffer) {
        autoreleasepool { [weak self] in
            guard let instance = self else { return }
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let cache = instance.textureCache else { return }
            
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            self?.currentTime = Float(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds)
            
            var imageTexture: CVMetalTexture?
            
            let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, imageBuffer, nil, MTLPixelFormat.bgra8Unorm, width, height, 0, &imageTexture)
            
            guard
                let unwrappedImageTexture = imageTexture,
                let texture = CVMetalTextureGetTexture(unwrappedImageTexture),
                result == kCVReturnSuccess
                else { return }
            
            self?.texture = texture
        }
    }
}

extension MetalCameraRenderer: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        autoreleasepool { [weak self] in
            guard let currentDrawable = view.currentDrawable,
                let currentRenderPassDescriptor = view.currentRenderPassDescriptor,
                let commandQueue = self?.commandQueue,
                let textureMappingRenderPipelineState = self?.textureMappingRenderPipelineState,
                let currentTexture = self?.texture,
                var constants = self?.constants
                else { return }
            
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
                else { return }
            
            commandEncoder.setRenderPipelineState(textureMappingRenderPipelineState)
            
            commandEncoder.setVertexBytes(&constants.isMirrored, length: MemoryLayout<Bool>.size, index: 1)
            commandEncoder.setFragmentSamplerState(self?.textureMappingSamplerState, index: 0)
            commandEncoder.setFragmentTexture(currentTexture, index: 0)
            
            commandEncoder.drawPrimitives(type: MTLPrimitiveType.triangleStrip, vertexStart: 0, vertexCount: 4)

            commandBuffer.present(currentDrawable)
            commandEncoder.endEncoding()
            
            // write texture if available and the recording is started...
            commandBuffer.addCompletedHandler { [weak self] commandBuffer in
                self?.delegate?.didRender(texture: currentDrawable.texture)
            }
            
            commandBuffer.commit()
        }
    }
}
