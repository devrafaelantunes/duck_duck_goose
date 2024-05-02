defmodule DuckDuckGoose.Handler do
  @moduledoc """
  Handles HTTP requests for the DuckDuckGoose application.

  This module processes specific endpoints, encoding the necessary information into JSON
  and responding to HTTP requests appropriately. It primarily interacts with the NodeManager API.
  """

  alias DuckDuckGoose.NodeManager.API
  require Jason
  require Logger

  @doc """
  Initializes the request by setting response headers, fetching the node's role, and encoding it into JSON.

  This function fetches the role of the node from the API, checks if it includes the necessary keys,
  encodes it to JSON, and prepares the HTTP response.

  ## Parameters
  - `request`: The Cowboy request object.
  - `opts`: Options containing the endpoint configuration.

  ## Returns
  - `{:ok, response, encoded_data}` on successful encoding and reply setup.
  - `{:error, response, error_message}` on failure.

  ## Examples

      iex> DuckDuckGoose.Handler.init(request, %{endpoint: :status})
      {:ok, response, "{\"role\":\"leader\", \"node\":\"node@hostname\"}"}
  """
  @spec init(any(), %{endpoint: atom()}) :: {:ok | :error, any(), String.t()}
  def init(request, %{endpoint: :status}) do
    request =
      :cowboy_req.set_resp_header("content-type", "application/json; charset=utf-8", request)

    role_map = API.fetch_role()

    if valid_role_map?(role_map) do
      case Jason.encode(role_map) do
        {:ok, json} ->
          response = set_reply(request, json, 200)
          {:ok, response, json}

        {:error, reason} ->
          Logger.error("JSON encoding failed: #{inspect(reason)}")
          set_error_response(request, "Internal Server Error", 500)
      end
    else
      Logger.error("Invalid or incomplete role data received")
      set_error_response(request, "Invalid role data", 400)
    end
  end

  defp valid_role_map?(map) do
    is_map(map) and Map.has_key?(map, :role) and Map.has_key?(map, :node)
  end

  defp set_reply(request, body, status_code) do
    :cowboy_req.reply(status_code, %{}, body, request)
  end

  defp set_error_response(request, message, status_code) do
    error_body = Jason.encode!(%{error: message})
    :cowboy_req.reply(status_code, %{}, error_body, request)
  end
end
