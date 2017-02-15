defmodule APNS.PushWorker do
  use Connection
  def start_link(_) do
    config = Application.get_env(:apns, :config)
    host = config[:push_host]
    port = config[:push_port]
    cert_path = config[:cert]
    key_path = config[:key]
    feedback_handler = config[:feedback_handler]
    opts = [
      reuse_sessions: false,
      mode: :binary,
      certfile: to_char_list(cert_path),
      keyfile: to_char_list(key_path),
      active: :once
    ]
    state = %{
      host: to_char_list(host),
      port: port,
      opts: opts,
      timeout: 60 * 1000,
      socket: nil,
      feedback_handler: feedback_handler
    }
    Connection.start_link(__MODULE__, state)
  end

  def push(pid, token, notification) do
    Connection.call(pid, {:push, token, notification})
  end

  def init(state) do
    {:connect, :init, state}
  end

  def connect(_, %{socket: nil, host: host, port: port, opts: opts,
  timeout: timeout} = state) do
    case :ssl.connect(host, port, opts, timeout) do
      {:ok, socket} ->
        {:ok, %{state | socket: socket}}
      {:error, _} ->
        {:backoff, 1000, state}
      end
  end

  def disconnect(info, %{socket: socket} = state) do
    :ok = :ssl.close(socket)
    case info do
      {:close, from} ->
        Connection.reply(from, :ok)
      {:error, :closed} ->
        :error_logger.format("Connection closed~n", [])
      {:error, reason} ->
        reason = :inet.format_error(reason)
        :error_logger.format("Connection error: ~s state: ~s ~n", [reason, inspect(state)])
    end
    {:connect, :reconnect, %{state | socket: nil}}
  end

  def handle_info({:ssl, socket, _msg}, %{socket: socket, feedback_handler: nil} = state) do
    {:no_reply, state}
  end

  def handle_info({:ssl, socket, << command :: size(8), status :: size(8), identifier :: size(32)>> = msg}, %{socket: socket, feedback_handler: handler} = state) do
    handler.handle_feedback(command, status, identifier)
    {:no_reply, state}
  end

  def handle_info({:ssl_closed, socket}, %{socket: socket} = state) do
    {:connect, :handle_info, %{state | socket: nil}}
  end

  def handle_info({:ssl_error, socket, _msg}, %{socket: socket} = state) do
    {:connect, :handle_info, %{state | socket: nil}}
  end

  def handle_call({:push, token, notification}, _from, %{socket: socket} = state) do
    data = APNS.Encoder.encode_notification(token, notification)
    case :ssl.send(socket, data) do
      :ok ->
        {:reply, :ok, state}
      {:error, reason} = error ->
        reason = :inet.format_error(reason)
        :error_logger.format("connection error: ~s~n", [reason])
        {:disconnect, error, state}
    end
  end

  def handle_call(_, _, %{socket: nil} = state) do
    {:reply, {:error, :closed}, state}
  end

end
