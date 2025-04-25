# jsonrpc

Encoders and decoders for [JSON-RPC 2.0](https://www.jsonrpc.org/specification).

[![Package Version](https://img.shields.io/hexpm/v/jsonrpc)](https://hex.pm/packages/jsonrpc)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/jsonrpc/)

```sh
gleam add jsonrpc@1
```
```gleam
import gleam/dynamic/decode
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/httpc
import gleam/result
import gleeunit/should
import jsonrpc

pub fn send_subtract(base_request: Request(a)) {
  let rpc_req =
    jsonrpc.request(method: "subtract", id: jsonrpc.id(1))
    |> jsonrpc.request_params([42, 23])

  let body =
  rpc_req
  |> jsonrpc.encode_request(json.array(_, json.int))
  |> json.to_string

  let req =
    rpc_req
    |> jsonrpc.encode_request(json.array(_, json.int))
    |> json.to_string
    |> request.set_body(base_request, _)

  let assert Ok(resp) = httpc.send(req)
  let decoder = jsonrpc.response_decoder(decode.int)
  let assert Ok(rpc_resp) = json.parse(resp.body, decoder)

  rpc_resp.id |> should.equal(rpc_req.id)
  rpc_resp.result |> should.equal(19)
}
```

Further documentation can be found at <https://hexdocs.pm/jsonrpc>.
