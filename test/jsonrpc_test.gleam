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

fn params_to_json(params: Params) -> json.Json {
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

fn data_to_json(data: Data) -> json.Json {
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

pub fn request_with_positional_parameters_test_to_json() {
  jsonrpc.request(method: "subtract", id: jsonrpc.id(1))
  |> jsonrpc.request_params([42, 23])
  |> test_case(
    title: "request with positional parameters",
    encode: jsonrpc.request_to_json(_, json.array(_, json.int)),
    decoder: jsonrpc.request_decoder(decode.list(decode.int)),
  )
}

pub fn request_with_named_parameters_test_to_json() {
  jsonrpc.request(method: "subtract", id: jsonrpc.id(3))
  |> jsonrpc.request_params(Params(23, 42))
  |> test_case(
    title: "request with named parameters",
    encode: jsonrpc.request_to_json(_, params_to_json),
    decoder: jsonrpc.request_decoder(params_decoder()),
  )
}

pub fn response_to_json_test() {
  jsonrpc.response(id: jsonrpc.id(1), result: 19)
  |> test_case(
    title: "response",
    encode: jsonrpc.response_to_json(_, json.int),
    decoder: jsonrpc.response_decoder(decode.int),
  )
}

pub fn notification_to_json_with_params_test() {
  jsonrpc.notification("update")
  |> jsonrpc.notification_params([1, 2, 3, 4, 5])
  |> test_case(
    title: "notification with params",
    encode: jsonrpc.notification_to_json(_, json.array(_, json.int)),
    decoder: jsonrpc.notification_decoder(decode.list(decode.int)),
  )
}

pub fn notification_to_json_without_params_test() {
  jsonrpc.notification("wibble")
  |> test_case(
    title: "notification without params",
    encode: jsonrpc.notification_to_json(_, jsonrpc.nothing_to_json),
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
    encode: jsonrpc.error_response_to_json(_, jsonrpc.nothing_to_json),
    decoder: jsonrpc.error_response_decoder(jsonrpc.nothing_decoder()),
  )
}

pub fn encode_error_with_data_test() {
  let app_error = jsonrpc.application_error(-30_000, "Oops") |> should.be_ok

  jsonrpc.error_response(id: jsonrpc.NullId, error: app_error)
  |> jsonrpc.error_response_data(Data(True, "wubble"))
  |> test_case(
    title: "error with data",
    encode: jsonrpc.error_response_to_json(_, data_to_json),
    decoder: jsonrpc.error_response_decoder(data_decoder()),
  )
}

pub fn json_error_test() {
  "{"
  |> json.parse(jsonrpc.request_decoder(jsonrpc.nothing_decoder()))
  |> should.be_error
  |> jsonrpc.json_error
  |> should.equal(jsonrpc.parse_error)

  "{}"
  |> json.parse(jsonrpc.request_decoder(jsonrpc.nothing_decoder()))
  |> should.be_error
  |> jsonrpc.json_error
  |> should.equal(jsonrpc.invalid_request)

  "{'jsonrpc':'2.0','id':1,'method':'subtract','params':['a', 'b']}"
  |> string.replace("'", "\"")
  |> json.parse(jsonrpc.request_decoder(decode.list(decode.int)))
  |> should.be_error
  |> jsonrpc.json_error
  |> should.equal(jsonrpc.invalid_params)
}

pub fn batch_request_test() {
  let req = jsonrpc.request(method: "test/request", id: jsonrpc.id(1))
  let notif = jsonrpc.notification("test/notification")

  let batch =
    jsonrpc.batch_request()
    |> jsonrpc.add_request(req, params_to_json)
    |> jsonrpc.add_notification(notif, jsonrpc.nothing_to_json)

  let json_string =
    batch
    |> jsonrpc.batch_request_to_json
    |> json.to_string

  birdie.snap(json_string, "batch request to json")

  let items =
    json.parse(json_string, jsonrpc.batch_request_decoder())
    |> should.be_ok
    |> jsonrpc.batch_request_items()

  let assert [
    jsonrpc.BatchRequestItemNotification(parsed_notif),
    jsonrpc.BatchRequestItemRequest(parsed_req),
  ] = items

  parsed_notif.method |> should.equal(notif.method)
  parsed_notif.params |> should.be_none

  parsed_req.id |> should.equal(req.id)
  parsed_req.method |> should.equal(req.method)
  parsed_req.params |> should.be_none
}

pub fn batch_response_test() {
  let resp = jsonrpc.response("result", jsonrpc.id(1))
  let error = jsonrpc.error_response(jsonrpc.method_not_found, jsonrpc.id(2))

  let batch =
    jsonrpc.batch_response()
    |> jsonrpc.add_response(resp, json.string)
    |> jsonrpc.add_error_response(error, jsonrpc.nothing_to_json)

  let json_string =
    batch
    |> jsonrpc.batch_response_to_json
    |> json.to_string

  birdie.snap(json_string, "batch response to json")

  let items =
    json.parse(json_string, jsonrpc.batch_response_decoder())
    |> should.be_ok
    |> jsonrpc.batch_response_items()

  let assert [
    jsonrpc.BatchResponseItemErrorResponse(parsed_error),
    jsonrpc.BatchResponseItemResponse(parsed_resp),
  ] = items

  parsed_error.id |> should.equal(error.id)
  parsed_error.error.code |> should.equal(error.error.code)
  parsed_error.error.message |> should.equal(error.error.message)
  parsed_error.error.data |> should.be_none

  parsed_resp.id |> should.equal(resp.id)
  parsed_resp.result
  |> decode.run(decode.string)
  |> should.be_ok
  |> should.equal(resp.result)
}
