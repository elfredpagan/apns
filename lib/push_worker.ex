defmodule APNS.PushWorker do
  import Joken
  use Connection
  def start_link(_) do
    config = Application.get_env(:apns, :config)
    host = config[:push_host]
    port = config[:push_port]
    kid = config[:kid]
    key_path = config[:key]
    app_id = config[:app_id]
    state = %{
      host: to_char_list(host),
      port: port,
      key: JOSE.JWK.from_pem_file(key_path),
      kid: kid,
      app_id: app_id,
      timeout: 60 * 1000,
      pid: nil,
    }
    Connection.start_link(__MODULE__, state)
  end

  def push(pid, token, notification) do
    Connection.cast(pid, {:push, token, notification})
  end

  def init(state) do
    {:connect, :init, state}
  end

  def connect(_, %{pid: nil, host: host, port: port} = state) do
    case :gun.open(to_charlist(host), port, %{protocols: [:http2]}) do
      {:ok, pid} ->
        case :gun.await_up(pid) do
          {:ok, :http2} ->
            {:ok, %{state | pid: pid}}
          _ ->
            :gun.close(pid)
            {:backoff, 1000, state}
        end
      {:error, reason} ->
          :error_logger.format("unable to connect: #{reason} backing off~n", [])
        {:backoff, 1000, state}
    end
  end

  def disconnect(_info, %{pid: pid} = state) do
    :ok = :gun.close(pid)
    {:connect, :reconnect, %{state | pid: nil}}
  end

  def handle_cast({:push, token, notification}, %{pid: pid, app_id: app_id, key: key, kid: kid} = state) do
    token = Base.encode16(token)
    jwt = generate_token(app_id, key, kid)
    json = to_charlist(APNS.Notification.to_json(notification))

    headers = generate_headers(notification, jwt)
    stream_ref = :gun.post(pid, to_charlist("/3/device/#{token}"), headers, json)
    case :gun.await(pid, stream_ref) do
      {:response, :fin, 200, _headers} ->
        {:noreply, state}
      {:response, :nofin, status, _headers} ->
        :error_logger.format("status code #{status}~n", [])
        {:ok, body} = :gun.await_body(pid, stream_ref)
        {:ok, error} = Poison.decode(body, as: %APNS.Error{})
        error = %{error | status: status}
        if state[:handler] do
          apply(state[:handler], :handle_feedback, {error, token, notification})
        end
        {:noreply, state}
      {:error, reason} ->
        :error_logger.format("http/2 error #{reason} disconnecting~n", [])
        {:disconnect, state}
    end
  end

  def handle_cast(_, state) do
    {:reply, {:error, :closed}, state}
  end

  def handle_info({:gun_down, pid, _, _, _, _}, %{pid: pid} = state) do
    {:connect, %{state | pid: nil}}
  end

  # private functions
  defp generate_headers(notification, jwt) do
    []
    |> build_header_list({"authorization", "bearer #{jwt}"})
    |> build_header_list({"apns-id", notification.identifier})
    |> build_header_list({"apns-expiration", notification.expiration_date})
    |> build_header_list({"apns-priority", notification.priority})
    |> build_header_list({"apns-topic", notification.topic})
    |> build_header_list({"apns-collapse-id", notification.collapse_id})
  end

  defp build_header_list(headers, {_, nil}) do
    headers
  end

  defp build_header_list(headers, {key, value}) do
    # clean up the header format for gun
    [{<< "#{key}" >>, to_charlist("#{value}")} | headers]
  end

  defp generate_token(app_id, key, kid) do
    token()
    |> with_header_arg("kid", kid)
    |> with_iss(app_id)
    |> with_signer(es256(key))
    |> sign
    |> get_compact
  end
end
