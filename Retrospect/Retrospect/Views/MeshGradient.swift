import SwiftUI
import MetalKit

struct MeshGradient: View {
    let width: Int
    let height: Int
    let points: [SIMD2<Float>]
    let colors: [Color]
    
    private let device = MTLCreateSystemDefaultDevice()
    @State private var metalView = MTKView()
    
    var body: some View {
        MetalViewRepresentable(
            metalView: metalView,
            width: width,
            height: height,
            points: points,
            colors: colors.map { color in
                let uiColor = UIColor(color)
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                return SIMD4<Float>(
                    Float(red),
                    Float(green),
                    Float(blue),
                    Float(alpha)
                )
            }
        )
    }
}

struct MetalViewRepresentable: UIViewRepresentable {
    let metalView: MTKView
    let width: Int
    let height: Int
    let points: [SIMD2<Float>]
    let colors: [SIMD4<Float>]
    
    func makeUIView(context: Context) -> MTKView {
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.delegate = context.coordinator
        metalView.enableSetNeedsDisplay = true
        metalView.framebufferOnly = false
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.points = points
        context.coordinator.colors = colors
        uiView.setNeedsDisplay()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(width: width, height: height, points: points, colors: colors)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var points: [SIMD2<Float>]
        var colors: [SIMD4<Float>]
        let width: Int
        let height: Int
        var pipelineState: MTLRenderPipelineState?
        var vertexBuffer: MTLBuffer?
        var pointsBuffer: MTLBuffer?
        var colorsBuffer: MTLBuffer?
        
        init(width: Int, height: Int, points: [SIMD2<Float>], colors: [SIMD4<Float>]) {
            self.width = width
            self.height = height
            self.points = points
            self.colors = colors
            super.init()
            createPipelineState()
        }
        
        func createPipelineState() {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let library = device.makeDefaultLibrary(),
                  let vertexFunction = library.makeFunction(name: "meshGradientVertex"),
                  let fragmentFunction = library.makeFunction(name: "meshGradientFragment") else {
                return
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        func draw(in view: MTKView) {
            guard let device = view.device,
                  let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer(),
                  let descriptor = view.currentRenderPassDescriptor,
                  let pipelineState = pipelineState,
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
            }
            
            // Create vertex data for a quad
            let vertices: [SIMD2<Float>] = [
                SIMD2<Float>(-1, -1),
                SIMD2<Float>(1, -1),
                SIMD2<Float>(-1, 1),
                SIMD2<Float>(1, 1)
            ]
            
            // Create or update buffers
            if vertexBuffer == nil {
                vertexBuffer = device.makeBuffer(bytes: vertices,
                                               length: vertices.count * MemoryLayout<SIMD2<Float>>.stride,
                                               options: [])
            }
            
            pointsBuffer = device.makeBuffer(bytes: points,
                                           length: points.count * MemoryLayout<SIMD2<Float>>.stride,
                                           options: [])
            
            colorsBuffer = device.makeBuffer(bytes: colors,
                                           length: colors.count * MemoryLayout<SIMD4<Float>>.stride,
                                           options: [])
            
            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(pointsBuffer, offset: 0, index: 1)
            encoder.setFragmentBuffer(pointsBuffer, offset: 0, index: 0)
            encoder.setFragmentBuffer(colorsBuffer, offset: 0, index: 1)
            
            let pointCount = UInt32(points.count)
            var fragmentUniforms = pointCount
            encoder.setFragmentBytes(&fragmentUniforms,
                                   length: MemoryLayout<UInt32>.stride,
                                   index: 2)
            
            encoder.drawPrimitives(type: .triangleStrip,
                                 vertexStart: 0,
                                 vertexCount: 4)
            
            encoder.endEncoding()
            
            if let drawable = view.currentDrawable {
                commandBuffer.present(drawable)
            }
            
            commandBuffer.commit()
        }
    }
}

extension Color {
    func resolve(in environment: EnvironmentValues) -> (red: Double, green: Double, blue: Double, opacity: Double) {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue), Double(alpha))
    }
} 