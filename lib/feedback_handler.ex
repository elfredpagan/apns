defmodule APNS.FeedbackHandler do
  @callback handle_feedback(APNS.Error, String.t, APNS.Notification) :: any
end
