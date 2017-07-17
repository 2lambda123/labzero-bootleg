defmodule Bootleg.Strategies.Build.DistilleryTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO
  import Mock
  alias Bootleg.{SSH, Git, Config, Strategies.Build.Distillery, Tasks}

  test "building without specified port" do
    use Bootleg.Config
    Tasks.load_tasks
    role :build, "build.example.com", user: "foo", workspace: "bar"
    ssh_host = :build
      |> Config.get_role
      |> Map.get(:hosts)
      |> List.first
      |> Map.get(:host)

    with_mocks([
      {SSH, [], [
        init: fn _ -> %SSHKit.Context{} end,
        run!: fn _, _ -> [{:ok, [stdout: ""], 0, ssh_host}] end,
        ssh_host_options: fn _ -> ssh_host end,
        download: fn _, _, _ -> :ok end
      ]},
      {
        Git, [], [
          push: fn _, _ -> {"", 0} end,
          push: fn [_, _, host_url, _], _ ->
            case host_url do
              "ssh://foo@build.example.com/~/bar" -> send(self(), :git_push_with_port)
              _ -> :ok
            end
            {"", 0}
          end
        ]
      }
    ]) do
      capture_io(fn ->
        Distillery.build()
        assert_received :git_push_with_port
      end)
    end
  end
end
