//// | code             | message          | meaning                                                                                               |
//// | ---------------- | ---------------- | ----------------------------------------------------------------------------------------------------- |
//// | -32700           | Parse error      | Invalid JSON was received by the server. An error occurred on the server while parsing the JSON text. |
//// | -32600           | Invalid Request  | The JSON sent is not a valid Request object.                                                          |
//// | -32601           | Method not found | The method does not exist / is not available.                                                         |
//// | -32602           | Invalid params   | Invalid method parameter(s).                                                                          |
//// | -32603           | Internal error   | Internal JSON-RPC error.                                                                              |
//// | -32000 to -32099 | Server error     | Reserved for implementation-defined server-errors.                                                    |

/// Invalid JSON was received by the server.An error occurred on the server
/// while parsing the JSON text.
pub const parse_error = -32_700

/// The JSON sent is not a valid Request object.
pub const invalid_request = -32_600

/// The method does not exist / is not available.
pub const method_not_found = -32_601

/// Invalid method parameter(s).
pub const invalid_params = -32_602

/// Internal JSON-RPC error.
pub const internal_error = -32_603
