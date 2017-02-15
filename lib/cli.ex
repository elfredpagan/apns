defmodule APNS.CLI do
  require Logger

  def main(args) do
    args
    |> parse_args
    |> process_options()
  end

  defp parse_args(args) do
    OptionParser.parse(args)
  end

  defp process_options(options) do
    case options do
      {[], [token, msg], []} ->
        send_push(token, msg)
      _ ->
        do_help
    end
  end

  defp do_help do
    IO.puts """
    Usage:
    apns token msg

    Example:
    ./apns xxxx hello
    """
    System.halt(0)
  end

  defp send_push(token, msg) do
    {:ok, token} = Base.decode64(token)
    push =
      APNS.Notification.new()
      |> APNS.Notification.alert(msg)
    APNS.push(token, push)
  end
end
