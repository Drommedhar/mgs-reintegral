@tool
extends RefCounted

static func mask(source: String, language: String) -> String:
	var parts := PackedStringArray()
	var cursor := 0
	var start := 0
	while cursor < source.length():
		var character := source[cursor]
		var end := cursor
		if character in ["'", '"']:
			var quote := character.repeat(3) if source.substr(cursor, 3) == character.repeat(3) else character
			end = string_end(source, cursor + quote.length(), quote)
		elif language == "shader" and source.substr(cursor, 2) == "/*":
			var close := source.find("*/", cursor + 2)
			end = source.length() if close < 0 else close + 2
		elif (language != "shader" and character == "#") or (language == "resource" and character == ";") or (language == "shader" and source.substr(cursor, 2) == "//"):
			end = source.find("\n", cursor)
			if end < 0: end = source.length()
		if end == cursor:
			cursor += 1
			continue
		parts.append(source.substr(start, cursor - start))
		parts.append(" ".repeat(end - cursor))
		cursor = end
		start = end
	parts.append(source.substr(start))
	return "".join(parts)

static func string_end(source: String, cursor: int, quote: String) -> int:
	while cursor < source.length():
		if source[cursor] == "\\": cursor += 2
		elif source.substr(cursor, quote.length()) == quote: return cursor + quote.length()
		else: cursor += 1
	return source.length()
