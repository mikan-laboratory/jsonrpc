import birdie
import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import gleam/string
import gleeunit
import gleeunit/should
import jsonrpcx

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
  jsonrpcx.request(method: "subtract", id: jsonrpcx.id(1))
  |> jsonrpcx.request_params([42, 23])
  |> test_case(
    title: "request with positional parameters",
    encode: jsonrpcx.request_to_json(_, json.array(_, json.int)),
    decoder: jsonrpcx.request_decoder(decode.list(decode.int)),
  )
}

pub fn request_with_named_parameters_test_to_json() {
  jsonrpcx.request(method: "subtract", id: jsonrpcx.id(3))
  |> jsonrpcx.request_params(Params(23, 42))
  |> test_case(
    title: "request with named parameters",
    encode: jsonrpcx.request_to_json(_, params_to_json),
    decoder: jsonrpcx.request_decoder(params_decoder()),
  )
}

pub fn response_to_json_test() {
  jsonrpcx.response(id: jsonrpcx.id(1), result: 19)
  |> test_case(
    title: "response",
    encode: jsonrpcx.response_to_json(_, json.int),
    decoder: jsonrpcx.response_decoder(decode.int),
  )
}

pub fn notification_to_json_with_params_test() {
  jsonrpcx.notification("update")
  |> jsonrpcx.notification_params([1, 2, 3, 4, 5])
  |> test_case(
    title: "notification with params",
    encode: jsonrpcx.notification_to_json(_, json.array(_, json.int)),
    decoder: jsonrpcx.notification_decoder(decode.list(decode.int)),
  )
}

pub fn notification_to_json_without_params_test() {
  jsonrpcx.notification("wibble")
  |> test_case(
    title: "notification without params",
    encode: jsonrpcx.notification_to_json(_, jsonrpcx.nothing_to_json),
    decoder: jsonrpcx.notification_decoder(jsonrpcx.nothing_decoder()),
  )
}

pub fn encode_error_with_no_data_test() {
  jsonrpcx.error_response(
    id: jsonrpcx.StringId("1"),
    error: jsonrpcx.method_not_found,
  )
  |> test_case(
    title: "error with no data",
    encode: jsonrpcx.error_response_to_json(_, jsonrpcx.nothing_to_json),
    decoder: jsonrpcx.error_response_decoder(jsonrpcx.nothing_decoder()),
  )
}

pub fn encode_error_with_data_test() {
  let app_error = jsonrpcx.application_error(-30_000, "Oops") |> should.be_ok

  jsonrpcx.error_response(id: jsonrpcx.NullId, error: app_error)
  |> jsonrpcx.error_response_data(Data(True, "wubble"))
  |> test_case(
    title: "error with data",
    encode: jsonrpcx.error_response_to_json(_, data_to_json),
    decoder: jsonrpcx.error_response_decoder(data_decoder()),
  )
}

pub fn json_error_test() {
  "{"
  |> json.parse(jsonrpcx.request_decoder(jsonrpcx.nothing_decoder()))
  |> should.be_error
  |> jsonrpcx.json_error
  |> should.equal(jsonrpcx.parse_error)

  "{}"
  |> json.parse(jsonrpcx.request_decoder(jsonrpcx.nothing_decoder()))
  |> should.be_error
  |> jsonrpcx.json_error
  |> should.equal(jsonrpcx.invalid_request)

  "{'jsonrpc':'2.0','id':1,'method':'subtract','params':['a', 'b']}"
  |> string.replace("'", "\"")
  |> json.parse(jsonrpcx.request_decoder(decode.list(decode.int)))
  |> should.be_error
  |> jsonrpcx.json_error
  |> should.equal(jsonrpcx.invalid_params)
}

pub fn batch_request_test() {
  let req = jsonrpcx.request(method: "test/request", id: jsonrpcx.id(1))
  let notif = jsonrpcx.notification("test/notification")

  let batch =
    jsonrpcx.batch_request()
    |> jsonrpcx.add_request(req, params_to_json)
    |> jsonrpcx.add_notification(notif, jsonrpcx.nothing_to_json)

  let json_string =
    batch
    |> jsonrpcx.batch_request_to_json
    |> json.to_string

  birdie.snap(json_string, "batch request to json")

  let items =
    json.parse(json_string, jsonrpcx.batch_request_decoder())
    |> should.be_ok
    |> jsonrpcx.batch_request_items()

  let assert [
    jsonrpcx.BatchRequestItemNotification(parsed_notif),
    jsonrpcx.BatchRequestItemRequest(parsed_req),
  ] = items

  parsed_notif.method |> should.equal(notif.method)
  parsed_notif.params |> should.be_none

  parsed_req.id |> should.equal(req.id)
  parsed_req.method |> should.equal(req.method)
  parsed_req.params |> should.be_none
}

pub fn batch_response_test() {
  let resp = jsonrpcx.response("result", jsonrpcx.id(1))
  let error = jsonrpcx.error_response(jsonrpcx.method_not_found, jsonrpcx.id(2))

  let batch =
    jsonrpcx.batch_response()
    |> jsonrpcx.add_response(resp, json.string)
    |> jsonrpcx.add_error_response(error, jsonrpcx.nothing_to_json)

  let json_string =
    batch
    |> jsonrpcx.batch_response_to_json
    |> json.to_string

  birdie.snap(json_string, "batch response to json")

  let items =
    json.parse(json_string, jsonrpcx.batch_response_decoder())
    |> should.be_ok
    |> jsonrpcx.batch_response_items()

  let assert [
    jsonrpcx.BatchResponseItemErrorResponse(parsed_error),
    jsonrpcx.BatchResponseItemResponse(parsed_resp),
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
