import Foundation
import Testing

@testable import SvelteSwiftUI

struct JSONValueTests {
    private func decode(_ json: String) throws -> JSONValue {
        try JSONValue(parsing: json)
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
        ("1e3", .number(1000)),
        ("-0.5E-2", .number(-0.005)),
        ("[]", .array([])),
        ("{}", .object([:])),
        (" { \"k\" : [ 1 , null ] } ", .object(["k": .array([.number(1), .null])])),
        ("\"\\u0041\\n\\\"\"", .string("A\n\"")),
    ])
    func decodes(json: String, expected: JSONValue) throws {
        #expect(try decode(json) == expected)
    }

    @Test(arguments: ["", "nul", "[1,", "{\"a\" 1}", "\"unterminated", "1 2", "-", "{1:2}"])
    func rejectsMalformedJSON(json: String) {
        #expect(throws: BridgeError.self) { try decode(json) }
    }

    @Test func keepsNumbersAndBooleansApart() throws {
        #expect(try decode("1") != .bool(true))
        #expect(try decode("true") != .number(1))
    }

    @Test(arguments: [
        (JSONValue.string("8"), Optional(8.0)),
        (.string(" 2.5 "), 2.5),
        (.number(3), 3),
        (.string("wide"), nil),
        (.bool(true), nil),
        (.null, nil),
    ])
    func readsNumbers(value: JSONValue, expected: Double?) {
        #expect(value.number == expected)
    }

    @Test(arguments: [
        (JSONValue.string("a"), Optional("a")),
        (.number(42), "42"),
        (.number(1.5), "1.5"),
        (.bool(false), "false"),
        (.null, nil),
        (.array([]), nil),
    ])
    func readsStrings(value: JSONValue, expected: String?) {
        #expect(value.string == expected)
    }

    @Test(arguments: [
        (JSONValue.bool(true), true),
        (.bool(false), false),
        (.string(""), true),
        (.string("false"), false),
        (.number(0), false),
        (.number(2), true),
        (.null, false),
        (.object([:]), true),
    ])
    func readsTruth(value: JSONValue, expected: Bool) {
        #expect(value.isTrue == expected)
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
