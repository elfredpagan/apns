defmodule APNS.FeedbackHandler do
  @callback handle_feedback(integer, integer, integer) :: none()
  def handle_feedback(command, status, identifier) do
    IO.puts "command = #{command} status = #{status}, identifier = #{identifier}"
  end

  defoverridable handle_feedback: 3
end
