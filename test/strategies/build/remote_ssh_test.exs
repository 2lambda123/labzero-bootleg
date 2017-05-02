defmodule Bootleg.Strategies.Build.RemoteSSHTest do
  use ExUnit.Case, async: false

  doctest Bootleg.Strategies.Build.RemoteSSH

  setup do   
    %{
      config: %Bootleg.Config{
                app: "bootleg",
                version: "1.0.0",
                build: %Bootleg.BuildConfig{
                  identity: "identity",
                  workspace: "workspace",
                  host: "host",
                  user: "user",
                  mix_env: "test",
                  revision: "1"}
                }
    }
  end
  
  test "init", %{config: config} do
    Bootleg.Strategies.Build.RemoteSSH.init(config)
    assert_received({Bootleg.SSH, :start})
    assert_received({Bootleg.SSH, :connect, ["host", "user", "identity", "workspace"]})
    assert_received({Bootleg.SSH, :"run!", [:conn, "git config receive.denyCurrentBranch ignore", nil]})        
  end

  test "build", %{config: config} do
    local_file = "#{File.cwd!}/releases/build.tar.gz"
    Bootleg.Strategies.Build.RemoteSSH.build(config)
    assert_received({Bootleg.SSH, :start})
    assert_received({Bootleg.SSH, :connect, ["host", "user", "identity", "workspace"]})
    assert_received({Bootleg.SSH, :"run!", [:conn, "git config receive.denyCurrentBranch ignore", nil]})
    assert_received({Bootleg.Git, :push,  [["--tags", "-f", "user@host:workspace", "master"], [env: [{"GIT_SSH_COMMAND", "ssh -i 'identity'"}]]]})
    assert_received({Bootleg.SSH, :"run!", [:conn, "git reset --hard 1", nil]})
    assert_received({Bootleg.SSH, :run!, [:conn, ["APP=bootleg MIX_ENV=test mix local.rebar --force", "APP=bootleg MIX_ENV=test mix local.hex --force", "APP=bootleg MIX_ENV=test mix deps.get --only=prod"], nil]})
    assert_received({Bootleg.SSH, :run!, [:conn, ["APP=bootleg MIX_ENV=test mix deps.compile", "APP=bootleg MIX_ENV=test mix compile"], nil]})
    assert_received({Bootleg.SSH, :run!, [:conn, "APP=bootleg MIX_ENV=test mix release", nil]})
    assert_received({Bootleg.SSH, :download, [:conn, "_build/test/rel/bootleg/releases/1.0.0/bootleg.tar.gz", ^local_file, []]})
  end
end
