defmodule Bootleg.Strategies.Manage.RemoteSSHTest do
  use ExUnit.Case, async: false
  alias Bootleg.Strategies.Manage.RemoteSSH

  doctest RemoteSSH

  setup do
    %{
      config:
        %Bootleg.Config{
          app: "bootleg",
          version: "1.0.0",
          manage:
            %Bootleg.ManageConfig{
              identity: "identity",
              workspace: ".",
              hosts: "host",
              user: "user"
            }
        },
      bad_config:
        %Bootleg.Config{
          app: "Funky Monkey",
          version: "1.0.0",
          manage:
            %Bootleg.ManageConfig{
              identity: nil,
              "workspace": "what",
              hosts: nil
            }
          }
    }
  end

  test "init good", %{config: config} do
    RemoteSSH.init(config)
    assert_received({Bootleg.SSH, :start})
    assert_received({Bootleg.SSH, :connect, ["host", "user", [identity: "identity", workspace: "."]]})
  end

  test "init bad", %{bad_config: config} do
    assert_raise RuntimeError, ~r/This strategy requires "hosts", "user" to be configured/, fn ->
      RemoteSSH.init(config)
    end
  end

  test "start", %{config: %{app: app} = config} do
    RemoteSSH.start(:conn, config)
    assert_received({Bootleg.SSH, :"run!", [:conn, "bin/bootleg start"]})
  end

  test "stop", %{config: %{app: app} = config} do
    RemoteSSH.stop(:conn, config)
    assert_received({Bootleg.SSH, :"run!", [:conn, "bin/bootleg stop"]})
  end

  test "restart", %{config: %{app: app} = config} do
    RemoteSSH.restart(:conn, config)
    assert_received({Bootleg.SSH, :"run!", [:conn, "bin/bootleg restart"]})
  end

  test "ping", %{config: %{app: app} = config} do
    RemoteSSH.ping(:conn, config)
    assert_received({Bootleg.SSH, :"run!", [:conn, "bin/bootleg ping"]})
  end
end
