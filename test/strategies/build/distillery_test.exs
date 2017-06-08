defmodule Bootleg.Strategies.Build.DistilleryTest do
  use ExUnit.Case, async: false
  alias Bootleg.Strategies.Build.Distillery

  doctest Distillery

  setup do
    %{
      config: %Bootleg.Config{
                app: "bootleg",
                version: "1.0.0",
                build: %Bootleg.Config.BuildConfig{
                  strategy: Bootleg.Strategies.Build.Distillery,
                  identity: "identity",
                  workspace: "workspace",
                  host: "host",
                  user: "user",
                  mix_env: "test",
                  refspec: "master",
                  push_options: "-f"}
                }
    }
  end

  test "init", %{config: config} do
    Distillery.init(config)
    assert_received({
      Bootleg.SSH,
      :init,
      ["host", "user", [identity: "identity", workspace: "workspace", create_workspace: true]]
    })
    assert_received({Bootleg.SSH, :"run!", [:conn, "git config receive.denyCurrentBranch ignore"]})
  end

  test "build", %{config: config} do
    local_file = "#{File.cwd!}/releases/build.tar.gz"
    Distillery.build(config)
    assert_received({
      Bootleg.SSH,
      :init,
      ["host", "user", [identity: "identity", workspace: "workspace", create_workspace: true]]
    })
    assert_received({Bootleg.SSH, :"run!", [:conn, "git config receive.denyCurrentBranch ignore"]})
    assert_received({Bootleg.Git, :push,  [["--tags", "-f", "user@host:workspace", "master"], [env: [{"GIT_SSH_COMMAND", "ssh -i 'identity'"}]]]})
    assert_received({Bootleg.SSH, :"run!", [:conn, "git reset --hard master"]})
    assert_received({Bootleg.SSH, :run!, [:conn, ["APP=bootleg MIX_ENV=test mix local.rebar --force", "APP=bootleg MIX_ENV=test mix local.hex --force", "APP=bootleg MIX_ENV=test mix deps.get --only=prod"]]})
    assert_received({Bootleg.SSH, :run!, [:conn, ["APP=bootleg MIX_ENV=test mix deps.compile", "APP=bootleg MIX_ENV=test mix compile"]]})
    assert_received({Bootleg.SSH, :run!, [:conn, "APP=bootleg MIX_ENV=test mix release"]})
    assert_received({Bootleg.SSH, :download, [:conn, "_build/test/rel/bootleg/releases/1.0.0/bootleg.tar.gz", ^local_file, []]})
  end
end
