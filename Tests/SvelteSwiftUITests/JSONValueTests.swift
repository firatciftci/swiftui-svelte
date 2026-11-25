import Foundation
import Testing

@testable import SvelteSwiftUI

struct JSONValueTests {
    private func decode(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    @Test(arguments: [
        ("null", JSONValue.null),
        ("true", .bool(true)),
        ("false", .bool(false)),
        ("0", .number(0)),
        ("1", .number(1)),
        ("-2.5", .number(-2.5)),
        ("\"text\"", .string("text")),
        ("\"\"", .string("")),
        ("[1,\"a\",null]", .array([.number(1), .string("a"), .null])),
        ("{\"a\":{\"b\":[true]}}", .object(["a": .object(["b": .array([.bool(true)])])])),
    ])
    func decodes(json: String, expected: JSONValue) throws {
        #expect(try decode(json) == expected)
    }

    @Test func keepsNumbersAndBooleansApart() throws {
        #expect(try decode("1") != .bool(true))
        #expect(try decode("true") != .number(1))
    }

    @Test func readsDates() throws {
        #expect(try decode("\"2026-01-02T03:04:05.006Z\"").date == Date(timeIntervalSince1970: 1_767_323_045.006))
        #expect(try decode("\"2026-01-02T03:04:05Z\"").date == Date(timeIntervalSince1970: 1_767_323_045))
        #expect(try decode("\"not a date\"").date == nil)
        #expect(try decode("5").date == nil)
    }

    @Test func convertsToFoundationObjects() throws {
        let object = try decode("{\"a\":[1,\"b\",true,null]}").object
        let dictionary = try #require(object as? [String: Any])
        let array = try #require(dictionary["a"] as? Array<Any>)
        #expect(array[0] as? Double == 1)
        #expect(array[1] as? String == "b")
        #expect(array[2] as? Bool == true)
        #expect(array[3] is NSNull)
    }
}
