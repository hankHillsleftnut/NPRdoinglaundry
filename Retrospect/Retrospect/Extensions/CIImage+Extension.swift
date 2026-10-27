import CoreImage

extension CIImage {
    var cgImage: CGImage? {
        let ciContext = CIContext()

        guard let cgImage = ciContext.createCGImage(self, from: extent) else {
            return nil
        }

        return cgImage
    }
}
