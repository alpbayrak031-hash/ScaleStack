import Foundation

/// The result of compressing an image.
public struct ImageEncodeResult: Sendable {
    /// The complete `.ssm` file.
    public let data: Data
    public let timings: ImageEncodeTimings
}

/// Stage timings of one decode, in milliseconds.
public struct ImageDecodeTimings: Sendable {
    /// Parsing the container and entropy-decoding every stream.
    public var entropyDecoding: Double = 0
    /// Rebuilding the planes from patterns and converting back to RGB.
    public var reconstruction: Double = 0
    public var total: Double = 0
}

/// The result of opening a `.ssm` file.
public struct ImageDecodeResult: Sendable {
    public let image: RGBAImage
    /// The file's internal structure, for inspection and visualisation.
    public let analysis: ImageAnalysis
    public let timings: ImageDecodeTimings
}

/// What a `.ssm` header says about its image.
public struct ImageFileInfo: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let colorModel: ImageColorModel
    public let hasAlpha: Bool
    /// The quality setting (1–100) the file was written with.
    public let quality: Int
    public let versionMajor: Int
    public let versionMinor: Int
}

/// ScaleStack's `.ssm` image codec.
///
/// `.ssm` stores an image as a small dictionary of 4×4 patterns plus, for each block, the
/// pattern to use and how strongly to apply it. The image is coded as a resolution pyramid,
/// so smooth regions are carried by a handful of coarse blocks and only detailed regions
/// spend bits on fine ones.
///
/// All entry points are synchronous, thread-safe and internally parallel; call them off the
/// main thread.
public enum ImageCodec {
    public static let fileExtension = "ssm"
    /// Uniform Type Identifier the app exports for `.ssm` files.
    public static let typeIdentifier = "com.scalestack.ssm"
    public static let qualityRange = 1...100
    public static let defaultQuality = 60

    /// Compresses `image`. `quality` runs from 1 (smallest) to 100 (most faithful).
    public static func encode(_ image: RGBAImage, quality: Int = defaultQuality) throws -> ImageEncodeResult {
        let clock = Stopwatch()
        var (coded, timings) = try Encoder.encode(image, quality: quality)
        var entropyClock = Stopwatch()
        let bytes = Container.write(coded).bytes
        timings.entropyCoding = entropyClock.lap()
        timings.total = clock.milliseconds
        return ImageEncodeResult(data: Data(bytes), timings: timings)
    }

    /// Decompresses a `.ssm` file and reports its structure.
    public static func decode(_ data: Data) throws -> ImageDecodeResult {
        let clock = Stopwatch()
        var stage = Stopwatch()
        var timings = ImageDecodeTimings()

        let bytes = [UInt8](data)
        let (coded, sizes) = try Container.read(bytes)
        timings.entropyDecoding = stage.lap()

        let image = try Reconstructor.render(coded)
        timings.reconstruction = stage.lap()
        timings.total = clock.milliseconds

        let analysis = ImageAnalysis(coded, sizes: sizes, fileSize: bytes.count)
        return ImageDecodeResult(image: image, analysis: analysis, timings: timings)
    }

    /// Decodes a smaller rendition of a `.ssm` file for thumbnails and previews.
    ///
    /// The format is a resolution pyramid, so stopping early yields the image at 1/2, 1/4 or
    /// 1/8 size while skipping most of the decoding work and memory. The result is the
    /// smallest of those whose longer side is still at least `minimumLongSide` pixels, or the
    /// full image when none is.
    public static func decodePreview(_ data: Data, minimumLongSide: Int) throws -> RGBAImage {
        let bytes = [UInt8](data)
        let header = try Container.readHeader(bytes)
        let longSide = max(header.width, header.height)
        var reduction = 0
        while reduction < header.lumaLevels, longSide >> (reduction + 1) >= minimumLongSide {
            reduction += 1
        }
        return try Reconstructor.render(try Container.read(bytes, reduction: reduction).image)
    }

    /// True when `data` starts with the `.ssm` signature (or PixelVault 1.0's `.pixv` one).
    public static func isImageData(_ data: Data) -> Bool {
        ImageFormat.hasSignature(data)
    }

    /// Reads the header only — cheap enough to call for previews and validation.
    public static func readInfo(_ data: Data) throws -> ImageFileInfo {
        let header = try Container.readHeader([UInt8](data.prefix(ImageFormat.headerSize)))
        return ImageFileInfo(width: header.width, height: header.height, colorModel: header.colorModel,
                            hasAlpha: header.hasAlpha, quality: header.quality,
                            versionMajor: Int(ImageFormat.versionMajor), versionMinor: header.versionMinor)
    }
}
