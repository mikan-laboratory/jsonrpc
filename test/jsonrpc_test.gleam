import birdie
import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import jsonrpc

pub fn main() -> Nil {
  gleeunit.main()
}

type Params {
  Params(subtrahend: Int, minuend: Int)
}

fn params_decoder() -> Decoder(Params) {
  use subtrahend <- decode.field("subtrahend", decode.int)
  use minuend <- decode.field("minuend", decode.int)
  decode.success(Params(subtrahend:, minuend:))
}

fn encode_params(params: Params) -> json.Json {
  let Params(subtrahend:, minuend:) = params
  json.object([
    #("subtrahend", json.int(subtrahend)),
    #("minuend", json.int(minuend)),
  ])
}

type Data {
  Data(wibble: Bool, wobble: String)
}

fn data_decoder() -> Decoder(Data) {
  use wibble <- decode.field("wibble", decode.bool)
  use wobble <- decode.field("wobble", decode.string)
  decode.success(Data(wibble:, wobble:))
}

fn encode_data(data: Data) -> json.Json {
  let Data(wibble:, wobble:) = data
  json.object([#("wibble", json.bool(wibble)), #("wobble", json.string(wobble))])
}

fn test_case(
  msg msg: msg,
  title title: String,
  encode encode: fn(msg) -> Json,
  decoder decoder: Decoder(msg),
) -> Nil {
  let json_string =
    msg
    |> encode
    |> json.to_string

  json_string |> birdie.snap(title:)

  json_string
  |> json.parse(using: decoder)
  |> should.equal(Ok(msg))
}

pub fn encode_request_with_positional_parameters_test() {
  jsonrpc.Request(
    jsonrpc: jsonrpc.V2,
    method: "subtract",
    id: jsonrpc.IntId(1),
    params: Some([42, 23]),
  )
  |> test_case(
    title: "request with positional parameters",
    encode: jsonrpc.encode_request(_, json.array(_, json.int)),
    decoder: jsonrpc.request_decoder(decode.list(decode.int)),
  )
}

pub fn encode_request_with_named_parameters_test() {
  jsonrpc.Request(
    jsonrpc: jsonrpc.V2,
    method: "subtract",
    id: jsonrpc.IntId(3),
    params: Some(Params(23, 42)),
  )
  |> test_case(
    title: "request with named parameters",
    encode: jsonrpc.encode_request(_, encode_params),
    decoder: jsonrpc.request_decoder(params_decoder()),
  )
}

pub fn encode_response_test() {
  jsonrpc.Response(jsonrpc: jsonrpc.V2, id: jsonrpc.IntId(1), result: 19)
  |> test_case(
    title: "response",
    encode: jsonrpc.encode_response(_, json.int),
    decoder: jsonrpc.response_decoder(decode.int),
  )
}

pub fn encode_notification_with_params_test() {
  jsonrpc.Notification(
    jsonrpc: jsonrpc.V2,
    method: "update",
    params: Some([1, 2, 3, 4, 5]),
  )
  |> test_case(
    title: "notification with params",
    encode: jsonrpc.encode_notification(_, json.array(_, json.int)),
    decoder: jsonrpc.notification_decoder(decode.list(decode.int)),
  )
}

pub fn encode_notification_without_params_test() {
  jsonrpc.Notification(jsonrpc: jsonrpc.V2, method: "wibble", params: None)
  |> test_case(
    title: "notification without params",
    encode: jsonrpc.encode_notification(_, jsonrpc.encode_nothing),
    decoder: jsonrpc.notification_decoder(jsonrpc.nothing_decoder()),
  )
}

pub fn encode_error_with_no_data_test() {
  jsonrpc.ErrorResponse(
    jsonrpc: jsonrpc.V2,
    id: jsonrpc.StringId("1"),
    error: jsonrpc.ErrorBody(
      code: -32_601,
      message: "Method not found",
      data: None,
    ),
  )
  |> test_case(
    title: "error with no data",
    encode: jsonrpc.encode_error_response(_, jsonrpc.encode_nothing),
    decoder: jsonrpc.error_response_decoder(jsonrpc.nothing_decoder()),
  )
}

pub fn encode_error_with_data_test() {
  let _app_error = jsonrpc.application_error(-30_000, "Oops") |> should.be_ok

  jsonrpc.ErrorResponse(
    jsonrpc: jsonrpc.V2,
    id: jsonrpc.NullId,
    error: jsonrpc.ErrorBody(
      code: -30_000,
      message: "Oops",
      data: Some(Data(True, "wubble")),
    ),
  )
  |> test_case(
    title: "error with data",
    encode: jsonrpc.encode_error_response(_, encode_data),
    decoder: jsonrpc.error_response_decoder(data_decoder()),
  )
}
