defmodule APNS.FeedbackWorker do
  use Connection

  def start_link(_) do
    config = Application.get_env(:apns, :config)
    host = config[:feedback_host]
    port = config[:feedback_port]
    cert_path = config[:cert]
    key_path = config[:key]
    handler = config[:feedback_handler]
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
      handler: handler
    }
    Connection.start_link(__MODULE__, state, name: APNS.FeedbackWorker)
  end

  def init(state) do
    {:connect, :init, state}
  end

  def latest_feedback(pid) do
    Connection.call(pid, {:latest_feedback})
  end

  def handle_call({:latest_feedback}, _from, state) do
    IO.puts "no feedback"
    {:reply, %{}, state}
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
    IO.puts "hello #{IO.inspect msg}"
    {:no_reply, state}
  end

  def handle_info({:ssl_closed, socket}, %{socket: socket} = state) do
    {:connect, :handle_info, %{state | socket: nil}}
  end

  def handle_info({:ssl_error, socket, _msg}, %{socket: socket} = state) do
    {:connect, :handle_info, state}
  end
end
