var App = (function(exports) {
	Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
	// src/app.ts
	function greet(name) {
		const message = `Hello, ${name}`;
		if (name === "") throw new Error("empty name");
		return message;
	}
	greet("");
	exports.greet = greet;
	return exports;
})({});

//# sourceMappingURL=sourcemap.js.map