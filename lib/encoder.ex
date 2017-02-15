defmodule APNS.Encoder do

  def encode_notification(token, notification) do
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
