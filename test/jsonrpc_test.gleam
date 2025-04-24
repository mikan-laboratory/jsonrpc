import birdie
import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import gleam/string
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
  jsonrpc.request(method: "subtract", id: jsonrpc.id(1))
  |> jsonrpc.request_params([42, 23])
  |> test_case(
    title: "request with positional parameters",
    encode: jsonrpc.encode_request(_, json.array(_, json.int)),
    decoder: jsonrpc.request_decoder(decode.list(decode.int)),
  )
}

pub fn encode_request_with_named_parameters_test() {
  jsonrpc.request(method: "subtract", id: jsonrpc.id(3))
  |> jsonrpc.request_params(Params(23, 42))
  |> test_case(
    title: "request with named parameters",
    encode: jsonrpc.encode_request(_, encode_params),
    decoder: jsonrpc.request_decoder(params_decoder()),
  )
}

pub fn encode_response_test() {
  jsonrpc.response(id: jsonrpc.id(1), result: 19)
  |> test_case(
    title: "response",
    encode: jsonrpc.encode_response(_, json.int),
    decoder: jsonrpc.response_decoder(decode.int),
  )
}

pub fn encode_notification_with_params_test() {
  jsonrpc.notification("update")
  |> jsonrpc.notification_params([1, 2, 3, 4, 5])
  |> test_case(
    title: "notification with params",
    encode: jsonrpc.encode_notification(_, json.array(_, json.int)),
    decoder: jsonrpc.notification_decoder(decode.list(decode.int)),
  )
}

pub fn encode_notification_without_params_test() {
  jsonrpc.notification("wibble")
  |> test_case(
    title: "notification without params",
    encode: jsonrpc.encode_notification(_, jsonrpc.encode_nothing),
    decoder: jsonrpc.notification_decoder(jsonrpc.nothing_decoder()),
  )
}

pub fn encode_error_with_no_data_test() {
  jsonrpc.error_response(
    id: jsonrpc.StringId("1"),
    error: jsonrpc.method_not_found,
  )
  |> test_case(
    title: "error with no data",
    encode: jsonrpc.encode_error_response(_, jsonrpc.encode_nothing),
    decoder: jsonrpc.error_response_decoder(jsonrpc.nothing_decoder()),
  )
}

pub fn encode_error_with_data_test() {
  let app_error = jsonrpc.application_error(-30_000, "Oops") |> should.be_ok

  jsonrpc.error_response(id: jsonrpc.NullId, error: app_error)
  |> jsonrpc.error_response_data(Data(True, "wubble"))
  |> test_case(
    title: "error with data",
    encode: jsonrpc.encode_error_response(_, encode_data),
    decoder: jsonrpc.error_response_decoder(data_decoder()),
  )
}

pub fn decode_error_test() {
  "{"
  |> json.parse(jsonrpc.request_decoder(jsonrpc.nothing_decoder()))
  |> should.be_error
  |> jsonrpc.decode_error
  |> should.equal(jsonrpc.parse_error)

  "{}"
  |> json.parse(jsonrpc.request_decoder(jsonrpc.nothing_decoder()))
  |> should.be_error
  |> jsonrpc.decode_error
  |> should.equal(jsonrpc.invalid_request)

  "{'jsonrpc':'2.0','id':1,'method':'subtract','params':['a', 'b']}"
  |> string.replace("'", "\"")
  |> json.parse(jsonrpc.request_decoder(decode.list(decode.int)))
  |> should.be_error
  |> jsonrpc.decode_error
  |> should.equal(jsonrpc.invalid_params)
}
