defmodule APNS.APS do
  defstruct [:alert, :badge, :sound, :content_available, :category, :thread_id, :mutable_content]

  def to_map(aps) when is_nil(aps) do
    %{}
  end

  def to_map(aps) do
    aps
    |> Map.from_struct
    |> Map.put(:alert, APNS.Alert.to_map(aps.alert))
    |> Map.put("content-available", aps.content_available)
    |> Map.put("thread-id", aps.thread_id)
    |> Map.put("mutable-content", aps.mutable_content)
    |> Map.drop([:content_available, :thread_id])
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.into(%{})
  end
end

defmodule APNS.Alert do
  defstruct [:title, :subtitle, :body, :title_loc_key, :title_loc_args, :action_loc_key, :loc_key, :loc_args, :launch_image]

  def to_map(alert) when is_map(alert) do
    alert
    |> Map.from_struct
    |> Map.put("title-loc-key", alert[:title_loc_key])
    |> Map.put("title-loc-args", alert[:title_loc_args])
    |> Map.put("action-loc-key", alert[:action_loc_key])
    |> Map.put("loc-key", alert[:loc_key])
    |> Map.put("loc-args", alert[:loc_args])
    |> Map.put("launch-image", alert[:launch_image])
    |> Map.drop([:title_loc_key, :title_loc_args, :action_loc_key, :loc_key, :loc_args, :launch_image])
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Enum.into(%{})
  end

  def to_map(alert) do
    alert
  end
end

defmodule APNS.Notification do
  defstruct [aps: nil, custom_map: nil, identifier: nil, expiration_date: nil, priority: 10, collapse_id: nil, topic: nil]

  def to_json(notification) do
    {:ok, json} = notification.custom_map || %{}
    |> Map.put(:aps, APNS.APS.to_map(notification.aps))
    |> Poison.encode
    json
  end

  def new do
    %APNS.Notification{}
  end

  def map(%APNS.Notification{} = notification, map) do
    struct(notification, custom_map: map)
  end

  def simple_alert(%APNS.Notification{} = notification, text) do
    struct(notification, aps: %{(notification.aps || %APNS.APS{}) | alert: text})
  end

  def alert(%APNS.Notification{} = notification, %APNS.Alert{} = alert) do
    struct(notification, aps: %{(notification.aps || %APNS.APS{}) | alert: alert})
  end

  def content_available(%APNS.Notification{} = notification, value) do
    struct(notification, aps: %APNS.APS{content_available: value})
  end

  def badge(%APNS.Notification{} = notification, count) do
    struct(notification, aps: %{(notification.aps || %APNS.APS{}) | badge: count})
  end

  def sound(%APNS.Notification{} = notification, sound) do
    struct(notification, aps: %{(notification.aps || %APNS.APS{}) | sound: sound})
  end

  def mutable_content(%APNS.Notification{} = notification, mutable_content) do
    struct(notification, aps: %{(notification.aps || %APNS.APS{}) | mutable_content: mutable_content})
  end

  def category(%APNS.Notification{} = notification, category) do
    struct(notification, aps: %{(notification.aps || %APNS.APS{}) | category: category})
  end

  def thread_id(%APNS.Notification{} = notification, thread_id) do
    struct(notification, aps: %{(notification.aps || %APNS.APS{}) | thread_id: thread_id})
  end
end
