defmodule APNS.Error do
  defstruct [:reason, :timestamp, :token, :identifier, :status]
end
