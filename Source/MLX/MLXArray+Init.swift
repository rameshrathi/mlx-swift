// Copyright © 2024 Apple Inc.

import Cmlx
import Foundation

private func shapePrecondition(shape: [Int]?, count: Int) {
    if let shape {
        let total = shape.reduce(1, *)
        precondition(total == count, "shape \(shape) total \(total) != \(count) (actual)")
    }
}

extension MLXArray {

    /// Initalizer allowing creation of scalar (0-dimension) `MLXArray` from an `Int32`.
    ///
    /// ```swift
    /// let a = MLXArray(7)
    /// ```
    ///
    /// ### See Also
    /// - <doc:initialization>
    public convenience init(_ value: Int32) {
        self.init(mlx_array_from_int(value))
    }

    /// Initalizer allowing creation of scalar (0-dimension) `MLXArray` from a `Bool`.
    ///
    /// ```swift
    /// let a = MLXArray(true)
    /// ```
    ///
    /// ### See Also
    /// - <doc:initialization>
    public convenience init(_ value: Bool) {
        self.init(mlx_array_from_bool(value))
    }

    /// Initalizer allowing creation of scalar (0-dimension) `MLXArray` from a `Float`.
    ///
    /// ```swift
    /// let a = MLXArray(35.1)
    /// ```
    ///
    /// ### See Also
    /// - <doc:initialization>
    public convenience init(_ value: Float) {
        self.init(mlx_array_from_float(value))
    }

    /// Initalizer allowing creation of scalar (0-dimension) `MLXArray` from a `HasDType` value.
    ///
    /// ```swift
    /// let a = MLXArray(UInt64(7))
    /// ```
    ///
    /// ### See Also
    /// - <doc:initialization>
    public convenience init<T: HasDType>(_ value: T) {
        self.init(
            withUnsafePointer(to: value) { ptr in
                mlx_array_from_data(ptr, [], 0, T.dtype.cmlxDtype)
            })
    }

    /// Initalizer allowing creation of scalar (0-dimension) `MLXArray` from a `HasDType` value
    /// with a conversion to a given ``DType``.
    ///
    /// ```swift
    /// let a = MLXArray(7.5, dtype: .float16)
    /// ```
    ///
    /// ### See Also
    /// - <doc:initialization>
    /// - ``ScalarOrArray``
    public convenience init<T: HasDType>(_ value: T, dtype: DType) {
        if T.dtype == dtype {
            // matching dtypes, no coercion
            switch type(of: value) {
            case is Int32.Type:
                self.init(value as! Int32)
            case is Bool.Type:
                self.init(value as! Bool)
            case is Float32.Type:
                self.init(value as! Float32)
            default:
                self.init(
                    withUnsafePointer(to: value) { ptr in
                        mlx_array_from_data(ptr, [], 0, T.dtype.cmlxDtype)
                    })
            }
        } else {
            if let v = value as? (any BinaryFloatingPoint) {
                // Floatish-ish source
                switch dtype {
                case .bool:
                    self.init(!v.isZero)
                case .uint8:
                    self.init(UInt8(v))
                case .uint16:
                    self.init(UInt16(v))
                case .uint32:
                    self.init(UInt32(v))
                case .uint64:
                    self.init(UInt64(v))
                case .int8:
                    self.init(Int8(v))
                case .int16:
                    self.init(Int16(v))
                case .int32:
                    self.init(Int32(v))
                case .int64:
                    self.init(Int64(v))
                #if !arch(x86_64)
                case .float16:
                    self.init(Float16(v))
                #else
                case .float16:
                    fatalError("dtype \(dtype) not supported")
                #endif
                case .float32:
                    self.init(Float32(v))
                case .bfloat16, .complex64:
                    fatalError("dtype \(dtype) not supported")
                }

            } else if let v = value as? (any BinaryInteger) {
                // Int-ish source
                switch dtype {
                case .bool:
                    self.init(Int(v) != 0)
                case .uint8:
                    self.init(UInt8(v))
                case .uint16:
                    self.init(UInt16(v))
                case .uint32:
                    self.init(UInt32(v))
                case .uint64:
                    self.init(UInt64(v))
                case .int8:
                    self.init(Int8(v))
                case .int16:
                    self.init(Int16(v))
                case .int32:
                    self.init(Int32(v))
                case .int64:
                    self.init(Int64(v))
                #if !arch(x86_64)
                case .float16:
                    self.init(Float16(v))
                #else
                case .float16:
                    fatalError("dtype \(dtype) not supported")
                #endif
                case .float32:
                    self.init(Float32(v))
                case .bfloat16, .complex64:
                    fatalError("dtype \(dtype) not supported")
                }

            } else {
                // e.g. Bool -> Int
                fatalError("unable to coerce \(T.dtype) to \(dtype)")
            }
        }
    }

    /// Initalizer allowing creation of `MLXArray` from an array of `HasDType` values with
    /// an optional shape.
    ///
    /// ```swift
    /// let linear = MLXArray([0, 1, 2, 3])
    /// let twoByTwo = MLXArray([0, 1, 2, 3], [2, 2])
    /// ```
    ///
    /// ### See Also
    /// - <doc:initialization>
    public convenience init<T: HasDType>(_ value: [T], _ shape: [Int]? = nil) {
        shapePrecondition(shape: shape, count: value.count)
        self.init(
            value.withUnsafeBufferPointer { ptr in
                let shape = shape ?? [value.count]
                return mlx_array_from_data(
                    ptr.baseAddress!, shape.asInt32, shape.count.int32, T.dtype.cmlxDtype)
            })
    }

    /// Initalizer allowing creation of `MLXArray` from an array of `Double` values with
    /// an optional shape.
    ///
    /// Note: this converts the types to `Float`, which is a type representable in `MLXArray`
    ///
    /// ```swift
    /// let array = MLXArray(convert: [0.5, 0.9])
    /// ```
    ///
    /// ### See Also
    /// - <doc:initialization>
    public convenience init(converting value: [Double], _ shape: [Int]? = nil) {
        shapePrecondition(shape: shape, count: value.count)
        let floats = value.map { Float($0) }
        self.init(
            floats.withUnsafeBufferPointer { ptr in
                let shape = shape ?? [floats.count]
                return mlx_array_from_data(
                    ptr.baseAddress!, shape.asInt32, shape.count.int32, Float.dtype.cmlxDtype)
            })
    }

    /// Unavailable init to redirect for initializing with a `[Double]`
    @available(
        *, unavailable, renamed: "MLXArray(converting:shape:)",
        message: "Use MLXArray(converting: [1.0, 2.0, ...]) instead"
    )
    public convenience init(_ value: [Double], _ shape: [Int]? = nil) {
        fatalError("unavailable")
    }

    /// Initalizer allowing creation of `MLXArray` from a sequence of `HasDType` values with
    /// an optional shape.
    ///
    /// ```swift
    /// let ramp = MLXArray(0 ..< 64)
    /// let square = MLXArray(0 ..< 64, [8, 8])
    /// ```
    ///
    /// ### See Also
    /// - <doc:initialization>
    public convenience init<S: Sequence>(_ sequence: S, _ shape: [Int]? = nil)
    where S.Element: HasDType {
        let value = Array(sequence)
        shapePrecondition(shape: shape, count: value.count)
        self.init(
            value.withUnsafeBufferPointer { ptr in
                let shape = shape ?? [value.count]
                return mlx_array_from_data(
                    ptr.baseAddress!, shape.asInt32, shape.count.int32, S.Element.dtype.cmlxDtype)
            })
    }

    /// Initalizer allowing creation of `MLXArray` from a buffer of `HasDType` values with
    /// an optional shape.
    ///
    /// ```swift
    /// let image = vImage.PixelBuffer
    /// let array = image.withUnsafeBufferPointer { ptr in
    ///     MLXArray(ptr, [64, 64, 4])
    /// }
    /// ```
    ///
    /// ### See Also
    /// - <doc:initialization>
    public convenience init<T: HasDType>(_ ptr: UnsafeBufferPointer<T>, _ shape: [Int]? = nil) {
        shapePrecondition(shape: shape, count: ptr.count)
        let shape = shape ?? [ptr.count]
        self.init(
            mlx_array_from_data(
                ptr.baseAddress!, shape.asInt32, shape.count.int32, T.dtype.cmlxDtype))
    }

    /// Initalizer allowing creation of `MLXArray` from a `UnsafeRawBufferPointer` filled
    /// with bytes of `HasDType` values with an optional shape.
    ///
    /// ```swift
    /// let ptr: UnsafeRawBufferPointer
    /// let array = MLXArray(ptr, [2, 3], type: Int32.self)
    /// ```
    ///
    /// ### See Also
    /// - <doc:initialization>
    public convenience init<T: HasDType>(
        _ ptr: UnsafeRawBufferPointer, _ shape: [Int]? = nil, type: T.Type
    ) {
        let buffer = ptr.assumingMemoryBound(to: type)
        self.init(buffer, shape)
    }

    /// Initalizer allowing creation of `MLXArray` from a `Data` filled with bytes of `HasDType` values with
    /// an optional shape.
    ///
    /// ```swift
    /// let data: Data
    /// let array = MLXArray(data, [2, 3], type: Int32.self)
    /// ```
    ///
    /// ### See Also
    /// - <doc:initialization>
    public convenience init<T: HasDType>(_ data: Data, _ shape: [Int]? = nil, type: T.Type) {
        self.init(
            data.withUnsafeBytes { ptr in
                let buffer = ptr.assumingMemoryBound(to: type)
                shapePrecondition(shape: shape, count: buffer.count)
                let shape = shape ?? [buffer.count]
                return mlx_array_from_data(
                    ptr.baseAddress!, shape.asInt32, shape.count.int32, T.dtype.cmlxDtype)
            })
    }

}

// MARK: - Expressible by literals

extension MLXArray: ExpressibleByArrayLiteral {

    // Note: MLXArray does not implement ExpressibleByFloatLiteral etc. because
    // we want to create arrays in the context of the other arrays.  For example:
    //
    // let x = MLXArray(1.5, dtype: .float16)
    // let r = x + 2.5
    //
    // We expect r to have a dtype of float16.  See ``ScalarOrArray``.

    /// Initalizer allowing creation of 1d `MLXArray` from an array literal.
    ///
    /// ```swift
    /// let a: MLXArray = [1, 2, 3]
    /// ```
    ///
    /// This is convenient for methods that have `MLXArray` parameters:
    ///
    /// ```swift
    /// print(array.take([1, 2, 3], axis: 0))
    /// ```
    ///
    /// ### See Also
    /// - <doc:initialization>
    public convenience init(arrayLiteral elements: Int32...) {
        let ctx = elements.withUnsafeBufferPointer { ptr in
            let shape = [Int32(elements.count)]
            return mlx_array_from_data(
                ptr.baseAddress!, shape, Int32(shape.count), Int32.dtype.cmlxDtype)!
        }
        self.init(ctx)
    }
}