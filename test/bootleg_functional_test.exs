defmodule Bootleg.FunctionalTest do
  use Bootleg.FunctionalCase, async: false
  alias Bootleg.Fixtures
  import ExUnit.CaptureIO

  @tag boot: 3, ui_verbosity: :info, timeout: 120_000
  test "build, deploy, and manage", %{hosts: hosts} do
    location = Fixtures.inflate_project()
    File.cd!(location, fn ->
      use Bootleg.Config

      build_host = List.first(hosts)
      app_hosts = hosts -- [build_host]

      role :build, build_host.ip, port: build_host.port, user: build_host.user,
        silently_accept_hosts: true, workspace: "workspace", identity: build_host.private_key_path

      Enum.each(app_hosts, fn host ->
        role :app, host.ip, port: host.port, user: host.user,
          silently_accept_hosts: true, workspace: "workspace", identity: host.private_key_path
      end)

      config :app, :build_me
      config :version, "0.1.0"

      assert String.match?(capture_io(fn ->
        # credo:disable-for-next-line Credo.Check.Consistency.MultiAliasImportRequireUse
        use Bootleg.Config

        invoke :build
        invoke :deploy
        invoke :start
      end), ~r/build_me started/)
    end)
  end

  @tag boot: 3, ui_verbosity: :info, timeout: 120_000
  test "update: build, deploy, manage roll-up", %{hosts: hosts} do
    location = Fixtures.inflate_project()
    File.cd!(location, fn ->
      use Bootleg.Config

      build_host = List.first(hosts)
      app_hosts = hosts -- [build_host]

      role :build, build_host.ip, port: build_host.port, user: build_host.user,
        silently_accept_hosts: true, workspace: "workspace", identity: build_host.private_key_path

      Enum.each(app_hosts, fn host ->
        role :app, host.ip, port: host.port, user: host.user,
          silently_accept_hosts: true, workspace: "workspace", identity: host.private_key_path
      end)

      config :app, :build_me
      config :version, "0.1.0"

      assert String.match?(capture_io(fn ->
        # credo:disable-for-next-line Credo.Check.Consistency.MultiAliasImportRequireUse
        use Bootleg.Config

        invoke :update
      end), ~r/build_me started/)

      capture_io(fn ->
        # credo:disable-for-next-line Credo.Check.Consistency.MultiAliasImportRequireUse
        use Bootleg.Config

        remote :app do
          "wait-for-app build_me"
        end

        [{:ok, [stdout: pid_1], 0, _}, {:ok, [stdout: pid_2], 0, _}] = remote :app do
          "bin/build_me pid"
        end

        invoke :update

        remote :app do
          "wait-for-app build_me"
        end

        [{:ok, [stdout: new_pid_1], 0, _}, {:ok, [stdout: new_pid_2], 0, _}] = remote :app do
          "bin/build_me pid"
        end

        assert pid_1 != new_pid_1
        assert pid_2 != new_pid_2
      end)
    end)
  end

  @tag boot: 3, timeout: 120_000
  test "bootleg as a dependency", %{hosts: hosts} do
    shell_env = [{"BOOTLEG_PATH", File.cwd!}]
    build_host = List.first(hosts)
    app_hosts = hosts -- [build_host]
    location = Fixtures.inflate_project(:bootstraps)

    File.open!(Path.join([location, "config", "deploy.exs"]), [:write], fn file ->
      IO.write(file, """
        use Bootleg.Config

        role :build, "#{build_host.ip}", port: #{build_host.port}, user: "#{build_host.user}",
          silently_accept_hosts: true, workspace: "workspace", identity: "#{build_host.private_key_path}"
      """)
      Enum.each(app_hosts, fn host ->
        IO.write(file, """
          role :app, "#{host.ip}", port: #{host.port}, user: "#{host.user}",
            silently_accept_hosts: true, workspace: "workspace", identity: "#{host.private_key_path}"
        """)
      end)
    end)

    Enum.each(["deps.get", "bootleg.build", "bootleg.deploy", "bootleg.start"], fn cmd ->
      assert {_, 0} = System.cmd("mix", [cmd], [env: shell_env, cd: location])
    end)
  end

  @tag boot: 0
  test "init" do
    shell_env = [{"BOOTLEG_PATH", File.cwd!}]
    location = Fixtures.inflate_project(:n00b)
    Enum.each(["deps.get", "bootleg.init"], fn cmd ->
      assert {_, 0} = System.cmd("mix", [cmd], [env: shell_env, cd: location])
    end)
    assert File.regular?(Path.join([location, "config", "deploy.exs"]))
  end

end
