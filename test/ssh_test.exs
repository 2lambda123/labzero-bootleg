defmodule Bootleg.SSHTest do
  use ExUnit.Case, async: false

  alias Bootleg.SSH
  alias SSHKit.{Context, Host}

  doctest SSH

  setup do
    %{
      conn: %Context{
        pwd: ".",
        hosts: [
          %Host{name: "localhost.1", options: []},
          %Host{name: "localhost.2", options: []}
        ]
      }
    }
  end

  test "init", %{conn: conn} do
    assert %Context{} = conn, "Connection isn't a context"
  end

  test "run!", %{conn: conn} do
    assert [{:ok, _, 0, %{name: "localhost.1"}},
            {:ok, _, 0, %{name: "localhost.2"}}] = SSH.run!(conn, "hello")
  end

  test "upload", %{conn: conn} do
    assert_raise RuntimeError, fn ->
      SSH.upload(conn, "nonexistant_file", "new_remote_file")
    end

    assert :ok == SSH.upload(conn, "existing_local_file", "new_remote_file")
  end

  test "download", %{conn: conn} do
    assert_raise RuntimeError, fn ->
      SSH.download(conn, "nonexistant_file", "new_local_file")
    end

    assert :ok == SSH.download(conn, "existing_remote_file", "new_local_file")
  end
end
