//
//  FluidDotsView.swift
//  Retrospect
//
//  SwiftUI wrapper that drives the FluidDotsShader.metal fragment shader in a
//  continuously-rendering MTKView (time-driven, full-screen triangle).
//

import MetalKit
import SwiftUI

struct FluidDotsView: UIViewRepresentable {
    /// Name of the Metal fragment function to render. Defaults to the original orb.
    var fragmentName: String = "fluidDotsFragment"

    func makeCoordinator() -> Coordinator { Coordinator(fragmentName: fragmentName) }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = context.coordinator.device
        view.delegate = context.coordinator
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.isOpaque = true
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}

    final class Coordinator: NSObject, MTKViewDelegate {
        let device: MTLDevice?
        private let commandQueue: MTLCommandQueue?
        private var pipelineState: MTLRenderPipelineState?
        private let startTime = CACurrentMediaTime()
        private let fragmentName: String

        struct Uniforms {
            var iResolution: SIMD2<Float>
            var iTime: Float
        }

        init(fragmentName: String) {
            self.fragmentName = fragmentName
            let dev = MTLCreateSystemDefaultDevice()
            device = dev
            commandQueue = dev?.makeCommandQueue()
            super.init()
            buildPipeline()
        }

        private func buildPipeline() {
            guard let device,
                  let library = device.makeDefaultLibrary(),
                  let vertexFn = library.makeFunction(name: "fluidDotsVertex"),
                  let fragmentFn = library.makeFunction(name: fragmentName) else { return }
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vertexFn
            desc.fragmentFunction = fragmentFn
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineState = try? device.makeRenderPipelineState(descriptor: desc)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let pipelineState,
                  let commandQueue,
                  let descriptor = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
            }

            let size = view.drawableSize
            var uniforms = Uniforms(
                iResolution: SIMD2<Float>(Float(size.width), Float(size.height)),
                iTime: Float(CACurrentMediaTime() - startTime)
            )

            encoder.setRenderPipelineState(pipelineState)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
