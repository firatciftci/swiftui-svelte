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
