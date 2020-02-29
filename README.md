# JsClient

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

## Usage in phoneix

- Routes are added to the client according to the pipeline they use.
- `pipelines` can be `:"$all"`.
- Output directory must exist or compilation will fail.
- `write_to` can be `:stdout`.

```elixir
  use JsClient.Phoenix,
    pipelines: [:api],
    write_to: "assets/js/services/phx-client.js"
```

## Usage in javascript

The file written by the plugin exports a single factory function that
creates a web service with an adapter.

The client was made to work with axios as adapter but can work with
any code. The client itself does nothing http related.

Routes are defined in the client and accept:
- Url parameters (required if the route has url parameters)
- Data if the method supports data (everything besides GET or DELETE)
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

With these routes:

```elixir
  scope "/api", WowxWeb do
    pipe_through :api

    get "/", PageController, :index_json
    get "/:name", PageController, :index_name
    post "/:name", PageController, :create_name
  end
```

Here we will just log the request data passed to the adapter.

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
that can be directly passed to the `axios` function to make a request,
but is easily modifiable to implement other XHR libraries.

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
 * Wrap an axios request to always use our handlers
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
 * with our handleResponse and handleError handlers.
 * Finally this promise is returned
 */
export default function createClient() {
  const client = makeClient(function(request){
    const req = axios(request)
    return wrapAxiosReq(req)
  })
}
```
