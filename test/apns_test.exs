defmodule ApnsTest do
  use ExUnit.Case
  import APNS.Notification

  doctest APNS

  test "create simple notification" do
    push =
      new()
      |> alert("hello world")

    assert push.aps.alert == "hello world"
    assert push.priority == 10
  end

  test "test stacking" do
    push =
      new()
      |> alert("hello world")
      |> badge(5)
      |> sound("sound.aiff")
      |> category("hello")
      |> mutable_content(true)
      |> thread_id(1)

    assert push.aps.alert == "hello world"
    assert push.aps.badge == 5
    assert push.aps.sound == "sound.aiff"
    assert push.aps.category == "hello"
    assert push.aps.mutable_content
    assert push.aps.thread_id == 1
    assert push.priority == 10
  end

  test "true content available clears dictionary" do
    push =
      new()
      |> alert("hello world")
      |> badge(5)
      |> sound("sound.aiff")
      |> category("hello")
      |> mutable_content(true)
      |> thread_id(1)
      |> content_available(true)


    assert push.aps.alert == nil
    assert push.aps.badge == nil
    assert push.aps.sound == nil
    assert push.aps.category == nil
    assert push.aps.mutable_content == nil
    assert push.aps.thread_id == nil
    assert push.aps.content_available == true
    assert push.priority == 10
  end

  test "false content available does not clear dictionary" do
    push =
      new()
      |> alert("hello world")
      |> badge(5)
      |> sound("sound.aiff")
      |> category("hello")
      |> mutable_content(true)
      |> thread_id(1)
      |> content_available(false)


    assert push.aps.alert == "hello world"
    assert push.aps.badge == 5
    assert push.aps.sound == "sound.aiff"
    assert push.aps.category == "hello"
    assert push.aps.mutable_content
    assert push.aps.thread_id == 1
    assert push.priority == 10
  end

  test "to json" do
    push =
      new()
      |> alert("hello world")
      |> badge(5)
      |> sound("sound.aiff")
      |> category("hello")
      |> mutable_content(true)
      |> thread_id(1)
      |> map(%{hello: "world"})

    json = to_json(push)
    {:ok, map} = Poison.decode(json)

    assert map["aps"]["alert"] == "hello world"
    assert map["aps"]["badge"] == 5
    assert map["aps"]["sound"] == "sound.aiff"
    assert map["aps"]["category"] == "hello"
    assert map["aps"]["thread-id"] == 1
    assert map["aps"]["mutable-content"] == true
    assert map["hello"] == "world"
    assert Map.has_key?(map, "content-available") == false
  end
end
