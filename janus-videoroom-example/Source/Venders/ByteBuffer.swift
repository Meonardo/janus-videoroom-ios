import Foundation

/// 类似于Java的ByteBuffer, 方便转换Data
class ByteBuffer: CustomDebugStringConvertible {
    
    enum Endianness {
        case little
        case big
    }
    
    private var array = [UInt8]()
    private var currentIndex: Int = 0
    
    private var currentEndianness: Endianness = .big
    private let hostEndianness: Endianness = OSHostByteOrder() == OSLittleEndian ? .little : .big
    
    var debugDescription: String {
        let length = array.count
        var out : String = "<ByteBuffer"
        for i in 0 ..< length {
            out += " " + String(format:"%02X", array[i])
        }
        out += ">"
        return out
    }
    
    init(size: Int) {
        array.reserveCapacity(size)
    }
    
    init(data: Data) {
        array = data.bytes
    }
    
    func allocate(_ size: Int) {
        array = [UInt8]()
        array.reserveCapacity(size)
        currentIndex = 0
    }
    
    func nativeByteOrder() -> Endianness {
        return hostEndianness
    }
    
    func currentByteOrder() -> Endianness {
        return currentEndianness
    }
    
    func order(_ endianness: Endianness) -> ByteBuffer {
        currentEndianness = endianness
        return self
    }
}

/// Data
extension ByteBuffer {
    
    func append(_ data: Data) {
        array.append(contentsOf: data.bytes)
    }
    
    func append(_ bytes: [UInt8]) {
        array.append(contentsOf: bytes)
    }
    
    var bytes: [UInt8] {
        array
    }
    
    var data: Data {
        array.data
    }
}

/// Put
extension ByteBuffer {
    
    @discardableResult func put(_ value: UInt8) -> ByteBuffer {
        array.append(value)
        return self
    }
    
    @discardableResult func put(_ value: Int16) -> ByteBuffer {
        if currentEndianness == .little {
            array.append(contentsOf: to(value.littleEndian))
            return self
        }
        
        array.append(contentsOf: to(value.bigEndian))
        return self
    }
    
    @discardableResult func put(_ value: UInt16) -> ByteBuffer {
        if currentEndianness == .little {
            array.append(contentsOf: to(value.littleEndian))
            return self
        }
        
        array.append(contentsOf: to(value.bigEndian))
        return self
    }
    
    @discardableResult func put(_ value: Int32) -> ByteBuffer {
        if currentEndianness == .little {
            array.append(contentsOf: to(value.littleEndian))
            return self
        }
        
        array.append(contentsOf: to(value.bigEndian))
        return self
    }
    
    @discardableResult func put(_ value: UInt32) -> ByteBuffer {
        if currentEndianness == .little {
            array.append(contentsOf: to(value.littleEndian))
            return self
        }
        
        array.append(contentsOf: to(value.bigEndian))
        return self
    }
    
    @discardableResult func put(_ value: Int64) -> ByteBuffer {
        if currentEndianness == .little {
            array.append(contentsOf: to(value.littleEndian))
            return self
        }
        
        array.append(contentsOf: to(value.bigEndian))
        return self
    }
    
    @discardableResult func put(_ value: UInt64) -> ByteBuffer {
        if currentEndianness == .little {
            array.append(contentsOf: to(value.littleEndian))
            return self
        }
        
        array.append(contentsOf: to(value.bigEndian))
        return self
    }
    
    @discardableResult func put(_ value: Int) -> ByteBuffer {
        if currentEndianness == .little {
            array.append(contentsOf: to(value.littleEndian))
            return self
        }
        
        array.append(contentsOf: to(value.bigEndian))
        return self
    }
    
    @discardableResult func put(_ value: Float) -> ByteBuffer {
        if currentEndianness == .little {
            array.append(contentsOf: to(value.bitPattern.littleEndian))
            return self
        }
        
        array.append(contentsOf: to(value.bitPattern.bigEndian))
        return self
    }
    
    @discardableResult func put(_ value: Double) -> ByteBuffer {
        if currentEndianness == .little {
            array.append(contentsOf: to(value.bitPattern.littleEndian))
            return self
        }
        
        array.append(contentsOf: to(value.bitPattern.bigEndian))
        return self
    }
}

/// Get
extension ByteBuffer {
    
    func get() -> UInt8 {
        let result = array[currentIndex]
        currentIndex += 1
        return result
    }
    
    func get(_ index: Int) -> UInt8 {
        return array[index]
    }
    
    func getInt16() -> Int16 {
        let result = from(Array(array[currentIndex..<currentIndex + MemoryLayout<Int16>.size]), Int16.self)
        currentIndex += MemoryLayout<Int16>.size
        return currentEndianness == .little ? result.littleEndian : result.bigEndian
    }
    
    func getUInt16(_ index: Int) -> UInt16 {
        let result = from(Array(array[index..<index + MemoryLayout<UInt16>.size]), UInt16.self)
        return currentEndianness == .little ? result.littleEndian : result.bigEndian
    }
    
    func getInt32() -> Int32 {
        let result = from(Array(array[currentIndex..<currentIndex + MemoryLayout<Int32>.size]), Int32.self)
        currentIndex += MemoryLayout<Int32>.size
        return currentEndianness == .little ? result.littleEndian : result.bigEndian
    }
    
    func getInt32(_ index: Int) -> Int32 {
        let result = from(Array(array[index..<index + MemoryLayout<Int32>.size]), Int32.self)
        return currentEndianness == .little ? result.littleEndian : result.bigEndian
    }
    
    func getUInt32(_ index: Int) -> UInt32 {
        let result = from(Array(array[index..<index + MemoryLayout<UInt32>.size]), UInt32.self)
        return currentEndianness == .little ? result.littleEndian : result.bigEndian
    }
    
    func getInt64() -> Int64 {
        let result = from(Array(array[currentIndex..<currentIndex + MemoryLayout<Int64>.size]), Int64.self)
        currentIndex += MemoryLayout<Int64>.size
        return currentEndianness == .little ? result.littleEndian : result.bigEndian
    }
    
    func getInt64(_ index: Int) -> Int64 {
        let result = from(Array(array[index..<index + MemoryLayout<Int64>.size]), Int64.self)
        return currentEndianness == .little ? result.littleEndian : result.bigEndian
    }
    
    func getInt() -> Int {
        let result = from(Array(array[currentIndex..<currentIndex + MemoryLayout<Int>.size]), Int.self)
        currentIndex += MemoryLayout<Int>.size
        return currentEndianness == .little ? result.littleEndian : result.bigEndian
    }
    
    func getInt(_ index: Int) -> Int {
        let result = from(Array(array[index..<index + MemoryLayout<Int>.size]), Int.self)
        return currentEndianness == .little ? result.littleEndian : result.bigEndian
    }
    
    func getFloat() -> Float {
        let result = from(Array(array[currentIndex..<currentIndex + MemoryLayout<UInt32>.size]), UInt32.self)
        currentIndex += MemoryLayout<UInt32>.size
        return currentEndianness == .little ? Float(bitPattern: result.littleEndian) : Float(bitPattern: result.bigEndian)
    }
    
    func getFloat(_ index: Int) -> Float {
        let result = from(Array(array[index..<index + MemoryLayout<UInt32>.size]), UInt32.self)
        return currentEndianness == .little ? Float(bitPattern: result.littleEndian) : Float(bitPattern: result.bigEndian)
    }
    
    func getDouble() -> Double {
        let result = from(Array(array[currentIndex..<currentIndex + MemoryLayout<UInt64>.size]), UInt64.self)
        currentIndex += MemoryLayout<UInt64>.size
        return currentEndianness == .little ? Double(bitPattern: result.littleEndian) : Double(bitPattern: result.bigEndian)
    }
    
    func getDouble(_ index: Int) -> Double {
        let result = from(Array(array[index..<index + MemoryLayout<UInt64>.size]), UInt64.self)
        return currentEndianness == .little ? Double(bitPattern: result.littleEndian) : Double(bitPattern: result.bigEndian)
    }
}

extension ByteBuffer {
    
    private func to<T>(_ value: T) -> [UInt8] {
        var value = value
        return withUnsafeBytes(of: &value, Array.init)
    }
    
    private func from<T>(_ value: [UInt8], _: T.Type) -> T {
        return value.withUnsafeBytes {
            $0.load(fromByteOffset: 0, as: T.self)
        }
    }
}

extension Array where Element == UInt8 {
    var data: Data {
        return Data(self)
    }
}

extension Data {
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}
