import birdie
import gleam/json
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import jsonrpc

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn request_with_positional_parameters_test() {
  jsonrpc.Request(
    jsonrpc: jsonrpc.V2,
    method: "subtract",
    id: jsonrpc.IntId(1),
    params: Some([42, 23]),
  )
  |> jsonrpc.encode_request(json.array(_, json.int))
  |> json.to_string
  |> birdie.snap(title: "request with positional parameters")
}

type Params {
  Params(subtrahend: Int, minuend: Int)
}

fn encode_params(params: Params) -> json.Json {
  let Params(subtrahend:, minuend:) = params
  json.object([
    #("subtrahend", json.int(subtrahend)),
    #("minuend", json.int(minuend)),
  ])
}

pub fn request_with_named_parameters_test() {
  jsonrpc.Request(
    jsonrpc: jsonrpc.V2,
    method: "subtract",
    id: jsonrpc.IntId(3),
    params: Some(Params(23, 42)),
  )
  |> jsonrpc.encode_request(encode_params)
  |> json.to_string
  |> birdie.snap(title: "request with named parameters")
}

pub fn response_test() {
  jsonrpc.Response(jsonrpc: jsonrpc.V2, id: jsonrpc.IntId(1), result: 19)
  |> jsonrpc.encode_response(json.int)
  |> json.to_string
  |> birdie.snap(title: "response")
}

pub fn notification_with_params_test() {
  jsonrpc.Notification(
    jsonrpc: jsonrpc.V2,
    method: "update",
    params: Some([1, 2, 3, 4, 5]),
  )
  |> jsonrpc.encode_notification(json.array(_, json.int))
  |> json.to_string
  |> birdie.snap(title: "notification with params")
}

pub fn notification_without_params_test() {
  jsonrpc.Notification(jsonrpc: jsonrpc.V2, method: "wibble", params: None)
  |> jsonrpc.encode_notification(jsonrpc.encode_nothing)
  |> json.to_string
  |> birdie.snap(title: "notification without params")
}

pub fn error_with_no_data_test() {
  jsonrpc.ErrorResponse(
    jsonrpc: jsonrpc.V2,
    id: jsonrpc.StringId("1"),
    error: jsonrpc.ErrorBody(
      code: -32_601,
      message: "Method not found",
      data: None,
    ),
  )
  |> jsonrpc.encode_error_response(jsonrpc.encode_nothing)
  |> json.to_string
  |> birdie.snap(title: "error with no data")
}

type Data {
  Data(wibble: Bool, wobble: String)
}

fn encode_data(data: Data) -> json.Json {
  let Data(wibble:, wobble:) = data
  json.object([#("wibble", json.bool(wibble)), #("wobble", json.string(wobble))])
}

pub fn error_with_data_test() {
  let _app_error = jsonrpc.application_error(-30_000, "Oops") |> should.be_ok

  let data = Data(True, "wubble")
  jsonrpc.ErrorResponse(
    jsonrpc: jsonrpc.V2,
    id: jsonrpc.NullId,
    error: jsonrpc.ErrorBody(code: -30_000, message: "Oops", data: Some(data)),
  )
  |> jsonrpc.encode_error_response(encode_data)
  |> json.to_string
  |> birdie.snap(title: "error with data")
}
