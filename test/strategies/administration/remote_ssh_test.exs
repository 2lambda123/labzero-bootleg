defmodule Bootleg.Strategies.Administration.RemoteSSHTest do
  use ExUnit.Case, async: false
  alias Bootleg.Strategies.Administration.RemoteSSH

  doctest RemoteSSH

  setup do
    %{
      config:
        %Bootleg.Config{
          app: "bootleg",
          version: "1",
          administration:
            %Bootleg.AdministrationConfig{
              identity: "identity",
              workspace: ".",
              host: "host",
              user: "user"
            }
        }
    }
  end

  test "init", %{config: config} do
    RemoteSSH.init(config)
    assert_received({Bootleg.SSH, :start})
    assert_received({Bootleg.SSH, :connect, ["host", "user", [identity: "identity", workspace: "."]]})
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
end
