import Foundation

/// Minimal unaligned little-endian reads over a memory-mapped Data.
/// All geodata binaries are little-endian; Apple and Linux targets are too,
/// so loads are direct.
struct BinaryReader {
    let data: Data

    init(data: Data) {
        self.data = data
    }

    @inline(__always)
    func u8(_ offset: Int) -> UInt8 {
        data[data.startIndex + offset]
    }

    @inline(__always)
    func u16(_ offset: Int) -> UInt16 {
        load(offset)
    }

    @inline(__always)
    func i16(_ offset: Int) -> Int16 {
        load(offset)
    }

    @inline(__always)
    func u32(_ offset: Int) -> UInt32 {
        load(offset)
    }

    @inline(__always)
    func f32(_ offset: Int) -> Float {
        Float(bitPattern: load(offset) as UInt32)
    }

    @inline(__always)
    private func load<T: FixedWidthInteger>(_ offset: Int) -> T {
        data.withUnsafeBytes { raw in
            raw.loadUnaligned(fromByteOffset: offset, as: T.self)
        }
    }

    func ascii(_ offset: Int, count: Int) -> String {
        let start = data.startIndex + offset
        return String(decoding: data[start..<start + count], as: UTF8.self)
    }

    /// u8-length-prefixed UTF-8 string.
    func pascalString(_ offset: Int) -> String {
        let n = Int(u8(offset))
        let start = data.startIndex + offset + 1
        return String(decoding: data[start..<start + n], as: UTF8.self)
    }
}
