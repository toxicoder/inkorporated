---
title: Protocol Buffers Interview Questions & Answers (100+)
description: Protocol Buffers Interview Questions & Answers (100+) for Inkorporated.
tags: [enterprise, interview]
---

# Protocol Buffers Interview Questions & Answers (100+)


**What's on this page**

- Core content for this topic in the Inkorporated enterprise OS.
- Practical guidance, roles, or standards as applicable.

**What this enables**

- Consistent enterprise operations and decision-making.
- Shared language for humans and cyborg AI agents.

This guide contains 100+ Protocol Buffers (Protobuf) interview questions, ranging from core concepts to advanced wire format encoding and gRPC integration. Each question includes a model answer and potential follow-up paths based on the candidate's response.

## Part 1: General Concepts & Basics (1-20)

### 1. What is Protocol Buffers (Protobuf)?

Protocol Buffers is a language-neutral, platform-neutral, extensible mechanism for serializing structured data. It was developed by Google. You define how you want your data to be structured once (in `.proto` files), and then you can use generated source code to easily write and read your structured data to and from a variety of data streams and using a variety of languages.

**Candidate Response Paths:**

*   **Path A: Comparison with XML/JSON.**
    *   *Follow-up:* "Why would you choose it over JSON for a public REST API?"
    *   *Answer:* You might not. JSON is better for human readability and browser consumption. Protobuf is better for internal microservices or performance-critical mobile clients.

### 2. Compare Protobuf vs. XML vs. JSON.

| Feature | Protobuf | JSON | XML |
| :--- | :--- | :--- | :--- |
| **Format** | Binary | Text (Human Readable) | Text (Human Readable) |
| **Size** | Smallest | Medium | Largest |
| **Speed** | Fastest (Parsing/Serialization) | Medium | Slow |
| **Schema** | Required (.proto) | Optional (JSON Schema) | Optional (XSD) |
| **Typing** | Strong | Loose | Loose/Strong (with XSD) |

### 3. What are the key benefits of using Protocol Buffers?

1.  **Performance:** Smaller message size and faster processing (parsing/serialization) compared to text-based formats.
2.  **Language Interoperability:** Supports C++, Java, Python, Go, Ruby, C#, etc.
3.  **Backward/Forward Compatibility:** Fields can be added or removed without breaking old binaries.
4.  **Schema Enforcement:** The structure is defined and enforced by the compiler.

### 4. What is a `.proto` file?

It is a text file that contains the schema definition for the data structures (messages) and services. It uses the Protocol Buffers Interface Description Language (IDL).

```protobuf
syntax = "proto3";

message Person {
  string name = 1;
  int32 id = 2;
  string email = 3;
}
```

### 5. What are the main differences between `proto2` and `proto3`?

*   **Field Presence:** `proto2` has `required`, `optional`, and `repeated`. `proto3` removed `required` and `optional` (fields are optional by default and have default values).
*   **Default Values:** `proto2` allows explicit default values (`default = 5`). `proto3` uses zero values (0, empty string, false).
*   **Enums:** `proto3` enums must start with a zero value (usually `UNKNOWN`).
*   **Extensions:** `proto2` supports extensions. `proto3` mostly replaced them with `Any`.

**Candidate Response Paths:**

*   **Path A: Candidate complains about missing `required`.**
    *   *Follow-up:* "Why did Google remove `required` fields?"
    *   *Answer:* `Required` fields harm backward compatibility. If a field stops being required in the logic but the schema says `required`, old consumers will crash if it's missing.

### 6. Why should you avoid `required` fields in `proto2`?

If you ever wish to stop sending a `required` field, or if you want to rename it or effectively remove it, it becomes a breaking change. Any client reading the message that expects the field will fail to parse the message if it is missing. This makes evolving the schema extremely difficult.

### 7. What are "Tags" (Field Numbers) in Protobuf?

Each field in the message definition has a unique numbered tag (e.g., `string name = 1;`).
*   These numbers are used to identify fields in the binary message wire format.
*   They must not change once your message type is in use.

### 8. Why are field numbers 1 through 15 more efficient?

Field numbers 1-15 take **one byte** to encode (including the field number and wire type). Field numbers 16-2047 take **two bytes**.
*   *Optimization Tip:* Use 1-15 for very frequently occurring fields.

### 9. What basic data types are supported in Protobuf?

*   **Integers:** `int32`, `int64`, `uint32`, `uint64`, `sint32`, `sint64` (signed), `fixed32`, `fixed64`.
*   **Floating Point:** `float`, `double`.
*   **Boolean:** `bool`.
*   **Strings:** `string` (UTF-8), `bytes` (arbitrary byte arrays).

### 10. How does Protobuf handle Backward Compatibility?

*   **New Fields:** Old code reads new data -> It ignores (or stores as unknown) the new fields.
*   **Deleted Fields:** Old code reads data missing the deleted field -> It sees the default value.
*   **Rule:** Never reuse a field tag number.

### 11. What is the generated code?

The `protoc` compiler generates classes for your specific language (e.g., `Person.java`, `person_pb2.py`).
*   These classes provide builders, accessors (getters/setters), and methods to serialize/parse (`toByteArray()`, `parseFrom()`).

### 12. Can you modify a field's type without breaking compatibility?

Generally **No**, with exceptions:
*   `int32`, `uint32`, `int64`, `uint64`, and `bool` are compatible (can be changed to each other, though values might be truncated).
*   `string` and `bytes` are compatible if the bytes are valid UTF-8.
*   Changing `int32` to `string` will break parsing.

### 13. What is the `repeated` keyword?

It indicates that the field can be repeated any number of times (including zero). It is dynamically sized, similar to a List or Array.
```protobuf
repeated string phone_numbers = 4;
```

### 14. What are "Unknown Fields"?

Fields present in the parsed data that the parser does not recognize (e.g., from a newer version of the schema).
*   **Proto2:** Preserved in the message and re-serialized.
*   **Proto3 (Early):** Discarded.
*   **Proto3 (Modern):** Preserved (since version 3.5+).

### 15. Is Protobuf self-describing?

**No.** Unlike XML or JSON, a Protobuf binary message does not contain field names, only tag numbers. You *must* have the `.proto` definition (schema) to decode the data meaningfully.

### 16. What is the default value for an `int32` field in Proto3?

**0**.
*   There is no distinction between "0 was explicitly set" and "the field was missing" in the wire format (for scalar types in Proto3).

### 17. How do you distinguish between missing field and default value in Proto3?

For scalar types (int, bool), you **cannot** by default.
*   **Solution:** Use `wrapper types` (e.g., `google.protobuf.Int32Value`) or the `optional` keyword (available in newer Proto3) which generates a presence bit.

### 18. What is the `syntax` statement?

The first non-empty, non-comment line of the `.proto` file.
*   `syntax = "proto3";`
*   If omitted, the compiler assumes `proto2`.

### 19. Can you comment in `.proto` files?

Yes.
*   `// Single line comment`
*   `/* Multi-line comment */`

### 20. How are `bytes` different from `string`?

*   `string`: Must contain valid UTF-8 text.
*   `bytes`: Can contain arbitrary binary data (e.g., an image, an encrypted payload).

## Part 2: Schema Definition (.proto) (21-40)

### 21. How do you define a package?

```protobuf
package tutorial;
```
*   Helps prevent name clashes between different projects.
*   In Java, creates a package directory structure (unless `java_package` option is used).
*   In C++, generates a namespace.

### 22. What are `imports` in Protobuf?

Used to use definitions from other `.proto` files.
```protobuf
import "google/protobuf/timestamp.proto";
```

**Candidate Response Paths:**

*   **Path A: Public Imports.**
    *   *Follow-up:* "What does `import public` do?"
    *   *Answer:* It forwards the import. Any file importing the current file also gets the transitive public imports.

### 23. Explain "Nested Types".

You can define a message inside another message.
```protobuf
message SearchResponse {
  message Result {
    string url = 1;
  }
  repeated Result results = 1;
}
```
*   Referenced outside as `SearchResponse.Result`.

### 24. How do you define an Enum?

```protobuf
enum Corpus {
  CORPUS_UNSPECIFIED = 0; // Proto3 requires 0 value
  CORPUS_UNIVERSAL = 1;
  CORPUS_WEB = 2;
}
```

### 25. Can Enums share values (Aliases)?

Yes, if you set the `allow_alias` option.
```protobuf
enum EnumAllowingAlias {
  option allow_alias = true;
  UNKNOWN = 0;
  STARTED = 1;
  RUNNING = 1; // Alias to STARTED
}
```

### 26. What is a `map` in Protobuf?

Associative arrays (key-value pairs).
```protobuf
map<string, Project> projects = 3;
```
*   Keys: integers, bools, strings. (No floats, no enums).
*   Values: Any type except another map.
*   On the wire, maps are equivalent to a repeated message containing `key` and `value` fields.

### 27. What is `oneof`?

A set of fields where only one can be set at a time. Setting one field clears the others. Saves memory.
```protobuf
message Profile {
  oneof avatar {
    string image_url = 1;
    bytes image_data = 2;
  }
}
```

**Candidate Response Paths:**

*   **Path A: Repeated in oneof.**
    *   *Follow-up:* "Can you have `repeated` fields inside a `oneof`?"
    *   *Answer:* No.

### 28. What are `reserved` fields?

If you delete a field, you should reserve its tag number (and name) to prevent future users from accidentally reusing it and causing corruption with old data.
```protobuf
message Foo {
  reserved 2, 15, 9 to 11;
  reserved "foo", "bar";
}
```

### 29. What happens if you define two fields with the same tag number?

The `protoc` compiler will throw an error and fail to generate code. Tags must be unique within a message.

### 30. What is `java_multiple_files` option?

```protobuf
option java_multiple_files = true;
```
*   **False (Default):** Generates a single outer class containing all messages as inner static classes.
*   **True:** Generates separate `.java` files for each message/enum. Better for large projects.

### 31. What is the `deprecated` option?

```protobuf
int32 old_field = 1 [deprecated = true];
```
*   Marks the field as deprecated. Generated code will often have annotations (like `@Deprecated` in Java) to warn developers.

### 32. How do you handle Date and Time in Protobuf?

Do not use `string` (e.g., ISO-8601) or `int64` (seconds) directly if you want standard interoperability. Use **Well Known Types**:
```protobuf
import "google/protobuf/timestamp.proto";
// ...
google.protobuf.Timestamp last_updated = 1;
```

### 33. What is the `Any` type?

Allows you to embed a message without having its .proto definition at compile time.
```protobuf
import "google/protobuf/any.proto";
message ErrorStatus {
  string message = 1;
  repeated google.protobuf.Any details = 2;
}
```
*   Internally stores the byte data and a Type URL string.

### 34. How do you define a Service in Protobuf?

Used for RPC (Remote Procedure Call) systems like gRPC.
```protobuf
service SearchService {
  rpc Search (SearchRequest) returns (SearchResponse);
}
```

### 35. Can a field be both `repeated` and `optional`?

In `proto3`, `repeated` implies a list (0 to N). `optional` implies presence tracking (0 or 1). They are mutually exclusive.

### 36. What is the best practice for naming fields?

*   **Field Names:** `snake_case` (e.g., `song_name`).
*   **Message Names:** `CamelCase` (e.g., `SongRequest`).
*   **Enums:** `CAPS_WITH_UNDERSCORES`.
*   *Reason:* The generated code converts these to the language-specific standard (e.g., `getSongName()` in Java, `SongName` property in C#).

### 37. Can you default a map field?

No. Map fields cannot have default values explicitly defined, and they are never null (an empty map is the default).

### 38. How to update an Enum?

*   You can add new values.
*   **Be careful:** If an old client receives a new enum value it doesn't know, it treats it as an unknown integer value (in Proto3) or discards it (in older Proto2).
*   Always preserve the numeric values.

### 39. What is a "wrapper type"?

Types in `google/protobuf/wrappers.proto` (e.g., `StringValue`, `Int32Value`).
*   They wrap primitives in a Message.
*   Allows distinction between "null" (message not present) and default value (0 or "").

### 40. Can you inherit from other messages?

No. Protobuf does not support inheritance. You must use **Composition** (nesting messages).

## Part 3: Encoding & Wire Format (41-60)

### 41. Explain Base 128 Varints.

Variable-length integers.
*   Uses 1 byte for small numbers, more bytes for large numbers.
*   The **MSB (Most Significant Bit)** of each byte indicates if there are more bytes to follow (1 = yes, 0 = last byte).
*   Example: The number `1` is `0000 0001`. The number `300` takes two bytes.

### 42. How is a field encoded (Key-Value)?

A field in the stream is a Key followed by a Value.
*   **Key** = `(field_number << 3) | wire_type`.
*   The last 3 bits store the wire type.

### 43. What are the Wire Types?

| Type | Name | Meaning | Used For |
| :--- | :--- | :--- | :--- |
| 0 | Varint | Variable length | int32, int64, bool, enum |
| 1 | 64-bit | Fixed 8 bytes | fixed64, double |
| 2 | Length-delimited | Length + Bytes | string, bytes, messages, packed repeated |
| 3 | Start Group | (Deprecated) | Groups (Proto2) |
| 4 | End Group | (Deprecated) | Groups (Proto2) |
| 5 | 32-bit | Fixed 4 bytes | fixed32, float |

### 44. Why does `int32` encode negative numbers inefficiently?

In standard Varint encoding, negative numbers are sign-extended to 64 bits (even for `int32`), resulting in **10 bytes** on the wire.

### 45. What is ZigZag Encoding?

Used by `sint32` and `sint64` types.
*   It maps signed integers to unsigned integers so that small absolute values (like -1, -2) become small unsigned values.
*   -1 -> 1, 1 -> 2, -2 -> 3.
*   Makes encoding negative numbers efficient.

### 46. What is the difference between `int32` and `sint32`?

*   `int32`: Uses standard Varint. Good for positive numbers. Bad for negative (always 10 bytes).
*   `sint32`: Uses ZigZag Varint. Good for mixed positive/negative numbers.

### 47. How are Strings encoded?

**Wire Type 2 (Length-delimited).**
Format: `[Tag] [Length Varint] [UTF-8 Bytes]`.

### 48. How are nested messages encoded?

Also **Wire Type 2**.
*   The value is simply the serialized byte stream of the inner message.
*   Allows "lazy parsing" (decoding the outer message without parsing the inner one immediately).

### 49. What is "Packed Encoding"?

Used for `repeated` fields of scalar numeric types (proto3 default).
*   **Unpacked:** `[Tag][Value] [Tag][Value] [Tag][Value]` (Repeats Tag overhead).
*   **Packed:** `[Tag][Length][Value][Value][Value]` (Tag appears once). Saves space.

### 50. How does a decoder know when a message ends?

It doesn't.
*   Protobuf messages are not self-delimiting.
*   If you write multiple messages to a single file/stream, you must implement a framing protocol (e.g., write the length of the message before the message itself).

**Candidate Response Paths:**

*   **Path A: Use `writeDelimitedTo`.**
    *   *Follow-up:* "Is that standard across languages?"
    *   *Answer:* Most Java/C++ libs support it, but it's not strictly part of the wire format spec, just a common utility.

### 51. Is the wire format order deterministic?

**No.**
*   Fields can appear in any order.
*   Unknown fields might be interspersed.
*   Maps have no defined order.
*   *Implication:* You cannot compare two binary blobs for equality to check if messages are equal. You must parse and compare.

### 52. What is Canonical Encoding?

A deterministic serialization approach (e.g., sorting map keys, sorting field tags) sometimes used for hashing signatures, but standard Protobuf libraries do not guarantee this by default.

### 53. How much space does a boolean take?

*   **1 Byte** for the tag (if field number < 16).
*   **1 Byte** for the value (0 or 1).
*   Total: 2 Bytes.

### 54. Can you decode a `proto3` message using a `proto2` schema?

Partially. The wire format is mostly compatible.
*   Proto3 specific types (like `Map` or Packed repeated fields) might cause issues if the Proto2 schema doesn't define them correctly (though `packed=true` exists in proto2).
*   Missing required fields in the input (from proto3 source) will cause proto2 parsers to fail.

### 55. What happens if the wire type doesn't match the schema?

The parser generally throws an exception or marks it as a parse error.
*   Example: Expecting `Varint` (Type 0) but finding `Length-delimited` (Type 2).

### 56. How is `fixed32` different from `int32` on the wire?

*   `int32`: Varint encoded (1-5 bytes typically).
*   `fixed32`: Always 4 bytes.
*   *Use Case:* `fixed32` is better if values are usually very large (random IDs, hashes) where Varint would take 5 bytes.

### 57. How do Maps look on the wire?

A map `map<K, V> field = N` is serialized as a repeated message of a virtual entry message:
```protobuf
message MapEntry {
  K key = 1;
  V value = 2;
}
repeated MapEntry field = N;
```

### 58. What is the limit on message size?

*   Theoretical: 2GB (due to signed 32-bit integer limits in many implementations like Java/C++).
*   Practical: Default limits are often set to 64MB to prevent DOS attacks (OOM). Can be increased via API.

### 59. Does Protobuf compress data?

No. It uses efficient binary encoding (removing whitespace, using varints), which results in small sizes, but it does not use compression algorithms like GZIP or LZW.
*   *Tip:* You can GZIP the resulting binary protobuf for further reduction.

### 60. How does field reordering affect the wire format?

It doesn't.
*   If you change the order of fields in the `.proto` file (e.g., move `id = 1` below `name = 2`), the wire format depends only on the **Tag Number**, not the line number in the file.

## Part 4: Language Support & Compilation (61-80)

### 61. What is `protoc`?

The Protocol Buffer Compiler.
*   Input: `.proto` files.
*   Output: Generated code (C++, Java, Python, etc.).

### 62. How do you compile a python file?

```bash
protoc --python_out=. my_proto.proto
```

### 63. What is a "Builder" in Java generated code?

Protobuf messages in Java are **Immutable**.
*   To create or modify a message, you must use the generated `Builder` class.
```java
Person p = Person.newBuilder().setName("Jules").build();
```

### 64. How do you merge two messages?

Builders support merging.
```java
builder.mergeFrom(otherMessage);
```
*   **Singular fields:** Overwritten by `otherMessage`.
*   **Repeated fields:** Concatenated.

### 65. Does Protobuf support inheritance in generated code?

**No.**
*   Generated classes extend `GeneratedMessageV3`.
*   They do not support extending your own custom classes to add logic.
*   *Reason:* Preserves the "Data Object" nature and serialization guarantees.

### 66. How to print a message for debugging?

*   `toString()`: Returns a human-readable text format representation.
*   **Do not** use this for parsing/serialization logic, only for logging.

### 67. Can you convert Protobuf to JSON?

Yes. `JsonFormat` (Java) or `MessageToJson` (Python) util classes are provided by the library.
*   It converts field names to JSON keys.
*   It handles Enums as strings.

### 68. What is `protoc-gen-go`?

The plugin for Go language support. `protoc` itself doesn't support Go natively out of the box in the main binary; it delegates to this plugin.

### 69. How does Python dynamic nature affect Protobuf?

Python code generated by `protoc` is often just descriptors. The actual message classes are created dynamically at runtime (metaclasses) in newer versions, using C++ extensions for speed.

### 70. What is the `option optimize_for`?

```protobuf
option optimize_for = CODE_SIZE;
```
*   **SPEED (Default):** Generates optimized code for serializing/parsing. Larger class files.
*   **CODE_SIZE:** Generates minimal classes that rely on shared reflection-based code. Slower, but smaller binary.
*   **LITE_RUNTIME:** Generates classes that only depend on the "Lite" library (no descriptors/reflection). Good for mobile.

### 71. How do you check if a field is set in Proto3 (Java)?

*   **Message fields:** `hasField()`.
*   **Scalar fields:** You can't (unless using `optional` keyword). You only check if value != 0.

### 72. What are "Well Known Types"?

A set of `.proto` definitions provided by Google that cover common use cases.
*   `Timestamp`, `Duration`
*   `StringValue`, `BoolValue` (Wrappers)
*   `FieldMask`
*   `Struct` (JSON Object)

### 73. What is `FieldMask`?

Used in Update/Patch RPCs.
*   Lists which fields the client wants to update.
*   Allows distinct updates (e.g., update only 'email', leave 'name' alone) even if the object has both.

### 74. How does reflection work in Protobuf?

You can traverse a message without knowing its type at compile time.
*   **Descriptors:** Describe the schema (MessageDescriptor, FieldDescriptor).
*   **Reflection Interface:** Get value by FieldDescriptor.

### 75. How to write a custom `protoc` plugin?

A plugin is an executable that accepts a `CodeGeneratorRequest` (protobuf message) from standard input and writes a `CodeGeneratorResponse` to standard output.
*   Can be written in any language (Python/Go are popular).

### 76. What is `Struct` type?

`google.protobuf.Struct`.
*   Represents a dynamic JSON object.
*   Maps strings to `Value` (which can be number, string, list, struct, etc.).
*   Useful when data structure is not known at compile time (loss of type safety).

### 77. Handling Polymorphism?

Since there is no inheritance, use:
1.  **Oneof:** If types are known.
2.  **Any:** If types are open-ended.

### 78. What is `DescriptorSet`?

A file containing the parsed schema information (descriptors) of `.proto` files.
*   Generated via `protoc --descriptor_set_out=file.pb`.
*   Used by tools (like grpcurl) to understand messages without source code.

### 79. How to handle huge messages?

Protobuf loads the entire message into memory.
*   **Solution:** Don't use a single huge message. Use a stream of smaller messages or split data into chunks.

### 80. Dependency Management?

`protoc` needs import paths (`-I` or `--proto_path`).
*   Complex projects use tools like **Buf** to manage dependencies and linting.

## Part 5: Advanced Topics, Performance & gRPC (81-100)

### 81. How does gRPC relate to Protobuf?

gRPC is an RPC framework. Protobuf is the default:
1.  **IDL:** Defines the service and messages.
2.  **Serialization:** Encodes the payload on the wire.

### 82. Can gRPC use JSON?

Yes, but it's not the default. You can use gRPC-Web or custom codecs, but you lose the performance benefits of Protobuf.

### 83. What are the 4 types of gRPC methods?

1.  **Unary:** Simple Request -> Response.
2.  **Server Streaming:** Request -> Stream of Responses.
3.  **Client Streaming:** Stream of Requests -> Response.
4.  **Bidirectional Streaming:** Stream -> Stream (Async).

### 84. Why is Protobuf faster than JSON?

1.  **Size:** Binary is compact (Varints, no field names). Less bandwidth.
2.  **Parsing:** CPU efficient. No text scanning/tokenizing. It's mostly reading bytes and jumping pointers.

### 85. What is "Zero-Copy" parsing?

Some C++ implementations (like `StringPiece` or `Cord`) allow the protobuf parser to point directly to the raw byte buffer for string/byte fields instead of copying memory.

### 86. How to validate Protobuf messages?

Protobuf ensures *type* safety, not *value* validity (e.g., email format, age > 0).
*   **Solution:** Use **PGV (Protoc Gen Validate)**. Annotate fields in `.proto`:
    ```protobuf
    string email = 1 [(validate.rules).string.email = true];
    ```

### 87. What is Schema Registry?

In systems like Kafka, a Schema Registry stores the `.proto` definitions (versioned).
*   Producers send ID + Binary Data.
*   Consumers fetch Schema by ID to decode.
*   Decouples producers and consumers.

### 88. Protobuf Text Format vs JSON?

Protobuf has its own text format (looks like the `.proto` default values).
*   `name: "Jules" id: 42`
*   Used for config files or debugging. Not valid JSON.

### 89. How to handle breaking changes safely?

1.  Create a new field `string name_v2 = 5;`.
2.  Deprecate old field `name`.
3.  Dual-write to both in application logic.
4.  Migrate readers to `name_v2`.
5.  Stop writing `name`.

### 90. What is `Arena Allocation` (C++)?

A memory management optimization.
*   Allocates a large block of memory (Arena) upfront.
*   All message objects are allocated from this block.
*   Freeing the Arena frees everything at once.
*   Reduces `malloc`/`free` overhead and improves cache locality.

### 91. Explain "Unknown Fields" attack vector.

If a server acts as a proxy (Read -> Modify -> Write), and it preserves unknown fields:
*   Attacker sends a malicious payload in an "unknown field".
*   Server verifies known fields (checks pass).
*   Server forwards message to a vulnerable internal service that *does* understand the field.

### 92. Deterministic Serialization options.

Required for things like hashing a message to sign it.
*   Proto3 C++ has `MessageDifferencer` and serialization options to force map sorting.
*   Generally, don't rely on binary equality.

### 93. Is Protobuf encrypted?

No. It is just an encoding format. If you need security, you must encrypt the transport (TLS/SSL) or the payload field (`bytes encrypted_data = 1`).

### 94. Comparison with FlatBuffers?

| Feature | Protobuf | FlatBuffers |
| :--- | :--- | :--- |
| **Parsing** | Decoding step required (unpack to object). | No parsing (Zero-copy access). |
| **Memory** | Allocates objects. | Reads directly from buffer. |
| **Use Case** | Microservices, Storage. | Games, Real-time (no GC/alloc overhead). |

### 95. Comparison with Apache Avro?

| Feature | Protobuf | Avro |
| :--- | :--- | :--- |
| **Schema** | Explicitly generated code. | Schema stored with data (usually). |
| **Ecosystem** | Google/Microservices/gRPC. | Hadoop/Big Data/Kafka. |
| **Evolution** | Tag numbers. | Schema resolution rules. |

### 96. What is the `files` field in `FileDescriptorSet`?

It contains a list of `FileDescriptorProto` messages, representing the parsed content of each `.proto` file (including dependencies).

### 97. How to exclude a field from JSON output?

Use `json_name` option? No, usually fields are included.
*   Some JSON Printers have options to `printingDefaultValues` or `ignoringUnknownFields`.
*   To hide it, you might need a separate "DTO" proto.

### 98. Custom Options?

You can define your own options to annotate files, messages, or fields.
```protobuf
extend google.protobuf.FieldOptions {
  bool my_option = 50000;
}
string name = 1 [(my_option) = true];
```
*   Access these via Reflection at runtime.

### 99. Performance: String vs Bytes?

*   `string` requires UTF-8 validation during parsing and serialization.
*   `bytes` is raw copy.
*   If you have ASCII data or don't care about encoding validation, `bytes` is slightly faster.

### 100. Naming convention for repeated fields?

Usually plural.
*   `repeated string phone_numbers = 1;`
*   Generated Java: `getPhoneNumbersList()`, `getPhoneNumbers(index)`.

---
**End of Interview Questions**


## Study Guide

To deepen your understanding of these concepts, check out the following resources:

- **Official Documentation**: [Protocol Buffers Docs](https://protobuf.dev/)
