defmodule JsClient.Phoenix do
  defmacro __using__(opts) do
    quote do
      @before_compile unquote(__MODULE__)
      @js_client_pipelines unquote(opts[:pipelines]) || :"$all"
      @js_client_output unquote(opts[:write_to]) || nil
      @js_client_global_name unquote(opts[:global_name]) || "phxRoutes"
    end
  end

  defmacro __before_compile__(env) do
    pipelines = env.module |> Module.get_attribute(:js_client_pipelines)
    routes = env.module |> Module.get_attribute(:phoenix_routes)
    output = env.module |> Module.get_attribute(:js_client_output)
    global_name = env.module |> Module.get_attribute(:js_client_global_name)

    specs =
      case pipelines do
        :"$all" ->
          routes

        pl when is_atom(pl) ->
          routes |> Enum.filter(&:lists.member(pl, &1.pipe_through))

        [] ->
          []

        pipes when is_list(pipes) ->
          routes |> Enum.filter(&intersercts?(&1.pipe_through, pipes))

        other ->
          raise "Invalid value #{inspect(other)} for #{inspect(__MODULE__)} option :pipelines in #{
                  inspect(env.module)
                }"
      end
      |> Enum.map(&to_define/1)

    js_code = to_js_module(specs, global_name)

    case output do
      :stdout ->
        IO.puts(js_code)

      path when is_binary(path) ->
        File.write!(output, js_code)

      nil ->
        IO.warn("#{inspect(__MODULE__)} option :write_to is not set in #{inspect(env.module)}")
        :ok

      other ->
        raise "Invalid value #{inspect(other)} for #{inspect(__MODULE__)} option :write_to in #{
                inspect(env.module)
              }"
    end
  end

  defp to_define(%{helper: helper, plug_opts: action, verb: verb, path: path})
       when is_atom(action) do
    action = to_string(action)
    verb = to_string(verb)

    # example path_match = ["ttt", "ttt", {:id, [], nil}]
    # example params_defs [{"id", {:id, [], nil}}]
    {_, _, path_match, params_defs, _, _, _, _} = Plug.Router.__route__(verb, path, [], [])

    {to_camel(helper) <> to_pascal(action), verb, path, path_match, params_defs}
  end

  defp to_js_module(specs, global_name) do
    definers =
      specs
      |> Enum.map(fn {route, method, path, path_match, params_defs} ->
        case params_defs do
          [] ->
            "  addRoute(false, '#{route}', '#{method}', '#{path}')\n"

          _list ->
            path_functions =
              path_match
              |> Enum.map(fn
                segment when is_binary(segment) ->
                  "    function() { return \"#{segment}\" }"

                {param, _, _} ->
                  "    function(params) { return requireParam(params, '#{param}') }"
              end)
              |> Enum.join(",\n")

            """
              addRoute(true, '#{route}', '#{method}', [
            #{path_functions}
              ])
            """
        end
      end)

    """
    (function (global, factory) {
      typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory() :
      typeof define === 'function' && define.amd ? define(factory) :
      (global = global || self, global.#{global_name} = factory());
    }(this, (function () { 'use strict';

    function makeUrl(segments, urlParams) {
      return '/'
        + segments
          .map(function(f) { return f(urlParams) })
          .join('/')
    }

    function requireParam(params, key) {
      if (params && typeof params[key] !== 'undefined') {
        return params[key]
      }
      throw new Error(`Url parameter '${key}' is required`)
    }

    return function makeWebService(xhr) {
      if (typeof xhr !== 'function') {
        throw new Error('An xhr function is required')
      }
      var routes = {}

      function addRoute(hasUrlParams, name, method, segmentsOrPath) {
        if (!routes[name]) {
          routes[name] = {}
        }
        
        var acceptsData = ['get', 'delete'].indexOf(method) === -1

        var getUrl = hasUrlParams 
          ? function(args) { return makeUrl(segmentsOrPath, args[0]) }
          : function() { return segmentsOrPath }

        var getData = !acceptsData 
          ? function(){}
          : hasUrlParams
            ? function(args) { return args[1] }
            : function(args) { return args[0] }

        var optsIndex = 0
        if (hasUrlParams) optsIndex += 1
        if (acceptsData) optsIndex += 1

        console.log(`${name} optsIndex`, optsIndex)

        var getOpts = function(args) { return args[optsIndex] }

        routes[name][method] = function() {
          var args = Array.prototype.slice.call(arguments)
          var url = getUrl(args)
          var opts = Object.assign({
            method: method, 
            url: url, 
            data: getData(args),
          }, getOpts(args))
          return xhr(opts)
        }

        routes[name][method].url = function(urlParams) {
          return getUrl([urlParams])
        }
      }

    #{definers}

      return routes
    }
    })));
    """
  end

  defp intersercts?(a, b) do
    try do
      Enum.each(a, fn el ->
        if Enum.member?(b, el) do
          throw(:found)
        end
      end)

      false
    catch
      :found -> true
    end
  end

  defp to_camel(name) do
    name
    |> Macro.camelize()
    |> lcfirst()
  end

  defp to_pascal(name), do: Macro.camelize(name)

  defp lcfirst(<<h::utf8, t::binary>>),
    do: String.downcase(<<h::utf8>>) <> t
end
