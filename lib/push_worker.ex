defmodule APNS.PushWorker do
  use Connection
  def start_link(_) do
    config = Application.get_env(:apns, :config)
    host = config[:push_host]
    port = config[:push_port]
    cert_path = config[:cert]
    key_path = config[:key]
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
      socket: nil
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

  def disconnect(info, %{socket: socket} = s) do
    :ok = :ssl.close(socket)
    case info do
      {:close, from} ->
        Connection.reply(from, :ok)
      {:error, :closed} ->
        :error_logger.format("Connection closed~n", [])
      {:error, reason} ->
        reason = :inet.format_error(reason)
        :error_logger.format("Connection error: ~s~n", [reason])
    end
    {:connect, :reconnect, %{s | socket: nil}}
  end

  def handle_info({:ssl, socket, msg}, %{socket: socket} = state) do
    << command :: size(8), status :: size(8), identifier :: size(32)>> = msg
    IO.puts "command = #{command} status = #{status}, identifier = #{identifier}"
    {:no_reply, state}
  end

  def handle_info({:ssl_closed, socket}, %{socket: socket} = state) do
    {:connect, :handle_info, %{state | socket: nil}}
  end

  def handle_info({:ssl_error, socket, _msg}, %{socket: socket} = state) do
    {:connect, :handle_info, %{state | socket: nil}}
  end

  def handle_call({:push, token, notification}, _from, %{socket: socket} = state) do
    data = encode_notification(token, notification)
    case :ssl.send(socket, data) do
      :ok ->
        {:reply, :ok, state}
      {:error, _} = error ->
        {:disconnect, error, state}
    end
  end

  def handle_call(_, _, %{socket: nil} = state) do
    {:reply, {:error, :closed}, state}
  end

  # private functions
  defp encode_notification(token, notification) do
    frame_data = << 1, 32 :: size(16), token::binary >>
    json = APNS.Notification.to_json(notification)
    frame_data = frame_data <> <<2, byte_size(json) :: size(16), json::binary >>

    frame_data =
    if notification.identifier do
      frame_data <> << 3, 4 :: size(16), notification.identifier :: size(32) >>
    else
      frame_data
    end

    frame_data =
    if notification.expiration_date do
      frame_data <> << 4, 4 :: size(16), notification.expiration_date :: size(32) >>
    else
      frame_data
    end

    frame_data =
    if notification.high_priority do
      frame_data <> << 5, 1, notification.high_priority && 10 || 5 >>
    else
      frame_data
    end

    << 2, byte_size(frame_data) :: size(32), frame_data :: binary >>

  end

end
