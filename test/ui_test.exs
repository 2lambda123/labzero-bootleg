defmodule Bootleg.UITest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Bootleg.UI
  alias SSHKit.{Context, Host}

  doctest UI

  setup do
    %{
      conn: %Context{
        pwd: ".",
        hosts: [
          %Host{name: "localhost.1", options: []},
          %Host{name: "localhost.2", options: []}
        ]
      },
      verbosity: :info
    }
  end

  test "puts restricts output based on verbosity level" do
    # :info is "set" as the verbosity level
    assert :ok == UI.puts(:info, "", :info)
    assert nil == UI.puts(:warning, "", :info)
    assert nil == UI.puts(:debug, "", :info)

    # :warning is set now
    assert :ok == UI.puts(:info, "", :warning)
    assert :ok == UI.puts(:warning, "", :warning)
    assert nil == UI.puts(:debug, "", :warning)

    # :debug is set now and should unrestrict output
    assert :ok == UI.puts(:info, "", :debug)
    assert :ok == UI.puts(:warning, "", :debug)
    assert :ok == UI.puts(:debug, "", :debug)
  end

  test "verbosity is validated and defaults to :info" do
    assert :info == UI.verbosity(:foo)
  end

  test "puts helpers can be used as shorthand" do
    assert capture_io(fn ->
      UI.info("foo", :info)
    end) == "foo\n"

    assert capture_io(fn ->
      UI.warn("bar", :warning)
    end) == "bar\n"

    assert capture_io(fn ->
      UI.debug("baz", :debug)
    end) == "baz\n"
  end

  # SSH-specific output tests

  test "ssh puts upload", %{conn: conn} do
    local_path = "/tmp/foo"
    remote_path = "/tmp/bar"
    assert capture_io(fn ->
      UI.puts_upload(conn, local_path, remote_path)
    end) == "\e[1m\e[32m[localhost.1] \e[0m\e[33mUPLOAD \e[0m/tmp/foo\e[0m\e[33m -> \e[0m./tmp/bar\e[0m\n\e[1m\e[32m[localhost.2] \e[0m\e[33mUPLOAD \e[0m/tmp/foo\e[0m\e[33m -> \e[0m./tmp/bar\e[0m\n"
  end

  test "ssh puts download", %{conn: conn} do
    remote_path = "/tmp/bar"
    local_path = "/tmp/foo"
    assert capture_io(fn ->
      UI.puts_download(conn, remote_path, local_path)
    end) == "\e[1m\e[32m[localhost.1] \e[0m\e[33mDOWNLOAD \e[0m./tmp/bar\e[0m\e[33m -> \e[0m/tmp/foo\e[0m\n\e[1m\e[32m[localhost.2] \e[0m\e[33mDOWNLOAD \e[0m./tmp/bar\e[0m\e[33m -> \e[0m/tmp/foo\e[0m\n"
  end

  test "ssh puts send to context", %{conn: conn} do
    assert capture_io(fn ->
      UI.puts_send(conn, "ls -l")
    end) == "\e[1m\e[32m[localhost.1] \e[0mls -l\e[0m\n\e[1m\e[32m[localhost.2] \e[0mls -l\e[0m\n"
  end

  test "ssh puts send to host" do
    assert capture_io(fn ->
      UI.puts_send(%SSHKit.Host{name: "localhost.1"}, "hostname")
    end) == "\e[1m\e[32m[localhost.1] \e[0mhostname\e[0m\n"
  end

  test "ssh puts receive list", %{conn: conn} do
    data = [{:ok, [stdout: "hello world!"], 0, List.first(conn.hosts)}]
    assert capture_io(fn ->
      UI.puts_recv(data)
    end) == "\e[0m\e[1m\e[34m[localhost.1] \e[0mhello world!\e[0m\n"
  end

  test "ssh puts receive tuple", %{conn: conn} do
    data = {:ok, [stdout: "hello world!"], 0, List.first(conn.hosts)}
    assert capture_io(fn ->
      UI.puts_recv(data)
    end) == "\e[0m\e[1m\e[34m[localhost.1] \e[0mhello world!\e[0m\n"
  end

  test "ssh puts receive from context", %{conn: conn} do
    assert capture_io(fn ->
      UI.puts_recv(conn, "hello world!")
    end) == "\e[0m\e[1m\e[34m[localhost.1] \e[0mhello world!\e[0m\n\e[0m\e[1m\e[34m[localhost.2] \e[0mhello world!\e[0m\n"
  end

  test "ssh puts receive from host", %{conn: conn} do
    host = List.first(conn.hosts)
    assert capture_io(fn ->
      UI.puts_recv(host, "hello world!")
    end) == "\e[0m\e[1m\e[34m[localhost.1] \e[0mhello world!\e[0m\n"
  end
end
