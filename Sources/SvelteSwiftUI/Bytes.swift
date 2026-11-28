import Foundation
import JavaScriptCore

nonisolated extension JSValue {
    func withBytes<Result>(_ body: (UnsafeMutableRawBufferPointer) -> Result) -> Result? {
        guard let reference = jsValueRef, let context = context?.jsGlobalContextRef,
            JSValueGetTypedArrayType(context, reference, nil) != kJSTypedArrayTypeNone,
            let object = JSValueToObject(context, reference, nil),
            let base = JSObjectGetTypedArrayBytesPtr(context, object, nil)
        else { return nil }
        let offset = JSObjectGetTypedArrayByteOffset(context, object, nil)
        let length = JSObjectGetTypedArrayByteLength(context, object, nil)
        return body(UnsafeMutableRawBufferPointer(start: base + offset, count: length))
    }

    var bytes: Data? {
        withBytes { Data($0) }
    }

    var utf8String: String? {
        guard let reference = jsValueRef, let context = context?.jsGlobalContextRef,
            let string = JSValueToStringCopy(context, reference, nil)
        else { return nil }
        defer { JSStringRelease(string) }
        let capacity = JSStringGetMaximumUTF8CStringSize(string)
        return String(unsafeUninitializedCapacity: capacity) { buffer in
            guard let base = buffer.baseAddress else { return 0 }
            let written = base.withMemoryRebound(to: CChar.self, capacity: capacity) {
                JSStringGetUTF8CString(string, $0, capacity)
            }
            return max(0, written - 1)
        }
    }

    var isTypedArray: Bool {
        guard let reference = jsValueRef, let context = context?.jsGlobalContextRef else { return false }
        return JSValueGetTypedArrayType(context, reference, nil) != kJSTypedArrayTypeNone
    }
}

nonisolated extension JSContext {
    func bytes(_ data: Data) -> JSValue {
        guard let object = JSObjectMakeTypedArray(jsGlobalContextRef, kJSTypedArrayTypeUint8Array, data.count, nil),
            let value = JSValue(jsValueRef: object, in: self)
        else { return JSValue(nullIn: self) }
        if !data.isEmpty, let base = JSObjectGetTypedArrayBytesPtr(jsGlobalContextRef, object, nil) {
            data.copyBytes(to: base.assumingMemoryBound(to: UInt8.self), count: data.count)
        }
        return value
    }
}
