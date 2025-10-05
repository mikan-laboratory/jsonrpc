# jsonrpcx

Encoders and decoders for [JSON-RPC 2.0](https://www.jsonrpc.org/specification).

[![Package Version](https://img.shields.io/hexpm/v/jsonrpcx)](https://hex.pm/packages/jsonrpcx)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/jsonrpcx/)

```sh
gleam add jsonrpcx
```
```gleam
import gleam/dynamic/decode
import gleam/http/request.{type Request as HttpRequest}
import gleam/http/response
import gleam/httpc
import gleam/result
import gleeunit/should
import jsonrpc

pub fn send_subtract(base_request: HttpRequest(body), a: Int, b: Int) {
  let request =
    jsonrpcx.request(method: "subtract", id: jsonrpcx.id(1))
    |> jsonrpcx.request_params([a, b])

  let http_request =
    request
    |> jsonrpcx.request_to_json(json.array(_, json.int))
    |> json.to_string
    |> request.set_body(base_request, _)

  let response: jsonrpcx.Response(Int) =
    httpc.send(http_request)
    |> should.be_ok
    |> fn(resp) {resp.body}
    |> json.parse(jsonrpcx.response_decoder(decode.int))
    |> should.be_ok


  response.id |> should.equal(request.id)
  response.result |> should.equal(a - b)
}
```

Further documentation can be found at <https://hexdocs.pm/jsonrpcx>.
