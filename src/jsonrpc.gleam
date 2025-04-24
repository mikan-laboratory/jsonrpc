//// JSON-RPC is a stateless, light-weight remote procedure call (RPC) protocol.
//// Primarily this specification defines several data structures and the rules
//// around their processing. It is transport agnostic in that the concepts can be
//// used within the same process, over sockets, over http, or in many various
//// message passing environments. It uses JSON (RFC 4627) as data format.
////
//// The error codes from and including -32768 to -32000 are reserved for
//// pre-defined errors. Any code within this range, but not defined explicitly below
//// is reserved for future use.
////
//// | code | message | meaning |
//// | --- | --- | --- |
//// | -32700 | Parse error | Invalid JSON was received by the server. An error occurred on the server while parsing the JSON text. |
//// | -32600 | Invalid Request | The JSON sent is not a valid Request object. |
//// | -32601 | Method not found | The method does not exist / is not available. |
//// | -32602 | Invalid params | Invalid method parameter(s). |
//// | -32603 | Internal error | Internal JSON-RPC error. |
//// | -32000 to -32099 | Server error | Reserved for implementation-defined server-errors. |
////
//// The remainder of the space is available for application defined errors.

import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import gleam/option.{type Option, None, Some}

/// Specifies the version of the JSON-RPC protocol. Only 2.0 is supported.
pub type Version {
  V2
}

pub fn encode_version(_version: Version) -> Json {
  json.string("2.0")
}

pub fn version_decoder() -> Decoder(Version) {
  use v <- decode.then(decode.string)
  case v {
    "2.0" -> decode.success(V2)
    _ -> decode.failure(V2, "unsupported JSON-RPC version: " <> v)
  }
}

/// An identifier established by the Client that MUST contain a String, Number,
/// or NULL value. The value SHOULD normally not be Null.
pub type Id {
  StringId(String)
  IntId(Int)
  NullId
}

pub fn id(id: Int) -> Id {
  IntId(id)
}

pub fn encode_id(id: Id) -> Json {
  case id {
    IntId(id) -> json.int(id)
    NullId -> json.null()
    StringId(id) -> json.string(id)
  }
}

pub fn id_decoder() -> Decoder(Id) {
  let string_decoder = decode.string |> decode.map(StringId)
  let others =
    decode.optional(decode.int |> decode.map(IntId))
    |> decode.map(option.unwrap(_, NullId))

  decode.one_of(string_decoder, [others])
}

/// An RPC call to a server
pub type Request(params) {
  Request(
    /// Specifies the version of the JSON-RPC protocol. MUST be exactly "2.0".
    jsonrpc: Version,
    /// A String containing the name of the method to be invoked. Method names
    /// that begin with the word rpc followed by a period character (U+002E or
    /// ASCII 46) are reserved for rpc-internal methods and extensions and MUST
    /// NOT be used for anything else.
    method: String,
    /// An identifier established by the Client that MUST contain a String, Number,
    /// or NULL value. The value SHOULD normally not be Null.
    id: Id,
    /// A Structured value that holds the parameter values to be used during the
    /// invocation of the method. This member MAY be omitted.
    params: Option(params),
  )
}

pub fn request(method method: String, id id: Id) -> Request(params) {
  Request(jsonrpc: V2, method:, id:, params: None)
}

pub fn request_params(request: Request(a), params: params) -> Request(params) {
  Request(..request, params: Some(params))
}

pub fn encode_request(
  request: Request(params),
  encode_params: fn(params) -> Json,
) -> Json {
  let Request(jsonrpc:, method:, id:, params:) = request
  let params = case params {
    Some(params) -> [#("params", encode_params(params))]
    None -> []
  }
  json.object([
    #("jsonrpc", encode_version(jsonrpc)),
    #("method", json.string(method)),
    #("id", encode_id(id)),
    ..params
  ])
}

pub fn request_decoder(
  params_decoder: Decoder(params),
) -> Decoder(Request(params)) {
  use jsonrpc <- decode.field("jsonrpc", version_decoder())
  use method <- decode.field("method", decode.string)
  use id <- decode.field("id", id_decoder())
  use params <- decode.optional_field(
    "params",
    None,
    decode.optional(params_decoder),
  )
  decode.success(Request(jsonrpc:, method:, id:, params:))
}

/// A type that can help with type inference for RPC objects that omit optional
/// fields.
pub opaque type Nothing {
  Nothing
}

pub fn encode_nothing(_nothing: Nothing) -> Json {
  json.null()
}

pub fn nothing_decoder() -> Decoder(Nothing) {
  decode.failure(Nothing, "Attempted to decode a Nothing type.")
}

/// A notification signifies the Client's lack of interest in the corresponding
/// Response object, and as such no Response object needs to be returned to the
/// client. The Server MUST NOT reply to a Notification, including those that
/// are within a batch request.
///
/// Notifications are not confirmable by definition, since they do not have a
/// Response object to be returned. As such, the Client would not be aware of
/// any errors (like e.g. "Invalid params","Internal error").
pub type Notification(params) {
  Notification(
    /// Specifies the version of the JSON-RPC protocol. MUST be exactly "2.0".
    jsonrpc: Version,
    /// A String containing the name of the method to be invoked. Method names
    /// that begin with the word rpc followed by a period character (U+002E or
    /// ASCII 46) are reserved for rpc-internal methods and extensions and MUST
    /// NOT be used for anything else.
    method: String,
    /// A Structured value that holds the parameter values to be used during the
    /// invocation of the method. This member MAY be omitted.
    params: Option(params),
  )
}

pub fn notification(method: String) -> Notification(params) {
  Notification(jsonrpc: V2, method:, params: None)
}

pub fn notification_params(
  notification: Notification(a),
  params: params,
) -> Notification(params) {
  Notification(..notification, params: Some(params))
}

pub fn encode_notification(
  notification: Notification(params),
  encode_params: fn(params) -> Json,
) -> Json {
  let Notification(jsonrpc:, method:, params:) = notification
  let params = case params {
    Some(params) -> [#("params", encode_params(params))]
    None -> []
  }

  json.object([
    #("jsonrpc", encode_version(jsonrpc)),
    #("method", json.string(method)),
    ..params
  ])
}

pub fn notification_decoder(
  params_decoder: Decoder(params),
) -> Decoder(Notification(params)) {
  use jsonrpc <- decode.field("jsonrpc", version_decoder())
  use method <- decode.field("method", decode.string)
  use params <- decode.optional_field(
    "params",
    None,
    decode.optional(params_decoder),
  )
  decode.success(Notification(jsonrpc:, method:, params:))
}

/// When an RPC call is made, the Server MUST reply with a Response, except for
/// in the case of Notifications.
pub type Response(result) {
  Response(
    /// Specifies the version of the JSON-RPC protocol. MUST be exactly "2.0".
    jsonrpc: Version,
    /// It MUST be the same as the value of the id member in the Request Object.
    id: Id,
    /// The value of this member is determined by the method invoked on the
    /// Server.
    result: result,
  )
}

pub fn response(id id: Id, result result: result) -> Response(result) {
  Response(jsonrpc: V2, id:, result:)
}

pub fn encode_response(
  response: Response(result),
  encode_result: fn(result) -> Json,
) -> Json {
  let Response(jsonrpc:, id:, result:) = response
  json.object([
    #("jsonrpc", encode_version(jsonrpc)),
    #("id", encode_id(id)),
    #("result", encode_result(result)),
  ])
}

pub fn response_decoder(
  result_decoder: Decoder(result),
) -> Decoder(Response(result)) {
  use jsonrpc <- decode.field("jsonrpc", version_decoder())
  use id <- decode.field("id", id_decoder())
  use result <- decode.field("result", result_decoder)
  decode.success(Response(jsonrpc:, id:, result:))
}

/// When an RPC call encounters an error, the server MUST send an error
/// response, except in the case of Notifications.
pub type ErrorResponse(data) {
  ErrorResponse(
    /// Specifies the version of the JSON-RPC protocol. MUST be exactly "2.0".
    jsonrpc: Version,
    /// It MUST be the same as the value of the id member in the Request Object.
    /// If there was an error in detecting the id in the Request object (e.g.
    /// Parse error/Invalid Request), it MUST be Null.
    id: Id,
    /// When a rpc call encounters an error, the Response Object MUST contain
    /// the error member with a value that is a Object with the following
    /// members:
    error: ErrorBody(data),
  )
}

pub fn error_response(
  id id: Id,
  error error: JsonRpcError,
) -> ErrorResponse(data) {
  ErrorResponse(
    jsonrpc: V2,
    id:,
    error: ErrorBody(code: error.code, message: error.message, data: None),
  )
}

pub fn error_response_data(
  error_response: ErrorResponse(a),
  data: data,
) -> ErrorResponse(data) {
  let error = ErrorBody(..error_response.error, data: Some(data))
  ErrorResponse(..error_response, error:)
}

pub fn encode_error_response(
  error_response: ErrorResponse(data),
  encode_data: fn(data) -> Json,
) -> Json {
  let ErrorResponse(jsonrpc:, id:, error:) = error_response
  json.object([
    #("jsonrpc", encode_version(jsonrpc)),
    #("id", encode_id(id)),
    #("error", encode_error(error, encode_data)),
  ])
}

pub fn error_response_decoder(
  data_decoder: Decoder(data),
) -> Decoder(ErrorResponse(data)) {
  use jsonrpc <- decode.field("jsonrpc", version_decoder())
  use id <- decode.field("id", id_decoder())
  use error <- decode.field("error", error_decoder(data_decoder))
  decode.success(ErrorResponse(jsonrpc:, id:, error:))
}

/// When an RPC call encounters an error, the Response Object MUST contain the
/// error member
pub type ErrorBody(data) {
  ErrorBody(
    /// A Number that indicates the error type that occurred.
    code: Int,
    /// A String providing a short description of the error.
    /// The message SHOULD be limited to a concise single sentence.
    message: String,
    /// A Primitive or Structured value that contains additional information
    /// about the error.
    /// This may be omitted.
    /// The value of this member is defined by the Server (e.g. detailed error
    /// information, nested errors etc.).
    data: Option(data),
  )
}

pub fn encode_error(
  error: ErrorBody(data),
  encode_data: fn(data) -> Json,
) -> Json {
  let ErrorBody(code:, message:, data:) = error
  let data = case data {
    Some(data) -> [#("data", encode_data(data))]
    None -> []
  }
  json.object([
    #("code", json.int(code)),
    #("message", json.string(message)),
    ..data
  ])
}

pub fn error_decoder(data_decoder: Decoder(data)) -> Decoder(ErrorBody(data)) {
  use code <- decode.field("code", decode.int)
  use message <- decode.field("message", decode.string)
  use data <- decode.optional_field("data", None, decode.optional(data_decoder))
  decode.success(ErrorBody(code:, message:, data:))
}

// ERRORS ----------------------------------------------------------------------

/// Invalid JSON was received by the server. An error occurred on the server
/// while parsing the JSON text.
pub const parse_error = JsonRpcError(-32_700, "Parse error")

/// The JSON sent is not a valid Request object.
pub const invalid_request = JsonRpcError(-32_600, "Invalid Request")

/// The method does not exist / is not available.
pub const method_not_found = JsonRpcError(-32_601, "Method not found")

/// Invalid method parameter(s).
pub const invalid_params = JsonRpcError(-32_602, "Invalid params")

/// Internal JSON-RPC error.
pub const internal_error = JsonRpcError(-32_603, "Internal error")

pub opaque type JsonRpcError {
  JsonRpcError(code: Int, message: String)
}

pub fn error_code(error: JsonRpcError) {
  error.code
}

pub fn error_message(error: JsonRpcError) {
  error.message
}

/// An error defined for your specific application.
/// The error code MUST not be within the range -32768 to -32000, otherwise
/// `Error(Nil)` will be returned.
/// The message SHOULD be limited to a concise single sentence.
pub fn application_error(
  code: Int,
  message: String,
) -> Result(JsonRpcError, Nil) {
  case code >= -32_768 && code <= -32_000 {
    True -> Error(Nil)
    False -> Ok(JsonRpcError(code, message))
  }
}

/// An error reserved for implementation-defined server-errors.
/// The error code MUST be within the range -32099 to -32000, otherwise
/// `Error(Nil)` will be returned.
pub fn server_error(code: Int) -> Result(JsonRpcError, Nil) {
  case code >= -32_099 && code <= -32_000 {
    True -> Ok(JsonRpcError(code, "Server error"))
    False -> Error(Nil)
  }
}
