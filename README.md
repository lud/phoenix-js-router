# JsClient

<!-- mdoc -->

JsClient implements an Elixir macro to generate a javascript
webservice client from a Phoenix router module.

The code is fully functional but lacks documentation besides what is
shown in this document.

## Installation

```elixir
def deps do
  [
    {:js_client, "~> 1.0.0"}
  ]
end
```

## Usage in phoenix

Routes are added to the client according to the pipeline they use.

The `pipelines` option (notice the plural) define which routes to
export. Expected values are:

- `:"$all"` (default) to export all routes.
- A list of pipelines names (atoms): `[:api, :private_api]`. An empty
  list will still create the javascript file, without any route.
- A single pipeline name: `:api`.

The `write_to` option defines where the javascript file will be
outputted. Expected values are:

- A path to a file, e.g. `"assets/js/services/phx-client.js"`. **The
  directory must exist or the compilation will fail**.
- `:stdout` to write the javascript result to the console for debug
  purposes.
- Default is `nil` and does not write anything.

```elixir
  use JsClient.Phoenix,
    pipelines: [:api],
    write_to: "assets/js/services/phx-client.js"
```

The `global_name` option set the name of the routes client if directly
included through a `<script></script>` tag. It must be a valid
javascript variable name. Defaults to `"pxhRoutes"`.

## Usage in javascript

The javascript file created by the plugin exports a single factory
function that creates a web service with an adapter. The export is
defined with the UMD format and should work as a Common Js or module
import as well as if directly included with a `<script></script>` tag.

The client was made to work with the axios function itself as the
default adapter but can work with any code. The client itself does
nothing http related and just passes everything to the adapter
function.

Routes are defined in the client and accept:
- Url parameters (required if the route has url parameters)
- Data if the http method supports data (everything besides GET or
  DELETE)
- Options

```
client[routeName][method]([urlParams [,data]], [options])
```


```javascript
import makeClient from './services/phx-client'
import axios from 'axios'
const client = makeClient(axios)

client.myRoute.get()
    .then(response => handleResponse(response))
```

## Request options

The adapter is a simple function that will receive the route url,
query parameters, data, and options. Options are just merged on the
request object so it is possible to override the url, query parameters
or data.

These routes are used in the following example:

```elixir
  scope "/api", WowxWeb do
    pipe_through :api

    get "/", PageController, :index_json
    get "/:name", PageController, :index_name
    post "/:name", PageController, :create_name
  end
```

Will just log give request data to the console:

```javascript
import makeClient from './services/phx-client'
const client = makeClient(function(request) {
    console.log('request', JSON.stringify(request, 0, 2))
})

// GET route without URL paramerters
// get "/", PageController, :index_json

client.pageIndexJson.get({someOption: 1})

// request {
//   "method": "get",
//   "url": "/api",
//   "someOption": 1
// }


// GET route with URL parameters
// get "/:name", PageController, :index_name

client.pageIndexName.get({name: "Joe"}, {someOption: 1})

// request {
//   "method": "get",
//   "url": "/api/Joe",
//   "someOption": 1
// }


// POST route with URL parameters
// post "/:name", PageController, :create_name

client.pageCreateName.post({name: "Robert"}, {some: "data"}, {someOption: 1})

// request {
//   "method": "post",
//   "url": "/api/Robert",
//   "data": {
//     "some": "data"
//   },
//   "someOption": 1
// }
```

As you can see, our adapter receives a simple object of configuration
that can be directly passed to the `axios` function to make a request.

Thus it should be easy enough to implement a Superagent or a raw
`fetch()` adapter.

## Javascript client example

This code can be used as a template to create your own client and
customise how errors are handled.

```javascript
import axios from 'axios'
import ErrorResponse from './errors/ErrorResponse'
import makeClient from './services/phx-client'

/**
 * Handles XHR responses in the form of:
 * - {"status": "ok", "data": {}}
 * - {"status": "error", "reason": "Failed", "detail": "Somenthing went wrong …"}
 */
function handleResponse (res) {
  const body = res.data

  if (body.status === 'ok') {
    if (typeof body.data === 'undefined') {
      console.warn('Undefined response data')
    }
    return body.data
  }

  if (body.status === 'error') {
    const { reason, detail } = body
    throw new ErrorResponse(reason, detail)
  }

  throw new Error(`Bad response format, no status: ${body.status}`)
}

/**
 * Handle HTTP errors
 */
function handleError(err) {
  console.error('err', err)
  if (err.response && err.response.data) {
    throw new ErrorResponse(err.response.data.reason || err.toString(), err.response.data.detail)
  } else if (err.response) {
    throw new ErrorResponse(err.toString())
  }
  throw err
}

/**
 * Wraps an axios request to use the handlers
 */
function wrapAxiosReq(req) {
  return req
    .then(handleResponse)
    .catch(handleError)
}

/**
 * Create a client
 *
 * When a route is called, we pass the request data to axios.
 * Then we wrap our axios promise to handle the response (or error)
 * with the `handleResponse` and `handleError` handlers.
 * Finally this promise is returned
 */
export default function createClient() {
  return makeClient(function(request){
    const req = axios(request)
    return wrapAxiosReq(req)
  })
}
```
