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
    json = APNS.Notification.to_json(notification)
    frame_data = <<>>
    |> encode_frame_data(1, byte_size(token), token)
    |> encode_frame_data(2, byte_size(json), json)
    |> encode_frame_data(3, 4, notification.identifier)
    |> encode_frame_data(4, 4, notification.expiration_date)
    |> encode_frame_data(5, 1, notification.priority)

    << 2 :: size(8), byte_size(frame_data) :: size(32), frame_data :: binary >>
  end

  # Not sure why I need the clauses with specific sizes.
  # It seems like I can't use dynamic values in a binary size() modifier?

  defp encode_frame_data(frame_data, _id, _size, nil) do
    frame_data
  end

  defp encode_frame_data(frame_data, id, size, data) when is_binary(data) do
    frame_data <> << id :: size(8), size :: size(16), data :: binary >>
  end

  defp encode_frame_data(frame_data, id, 1 = size, data) do
    frame_data <> << id :: size(8), size :: size(16), data :: size(8) >>
  end

  defp encode_frame_data(frame_data, id, 4 = size, data) do
    frame_data <> << id :: size(8), size :: size(16), data :: size(32) >>
  end

end
