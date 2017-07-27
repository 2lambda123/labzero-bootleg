defmodule Bootleg.TasksFunctionalTest do
  use Bootleg.TestCase, async: false
  alias Bootleg.Fixtures

  setup do
    %{
      provider_location: Fixtures.inflate_project(:task_provider),
      consumer_location: Fixtures.inflate_project(:task_consumer)
    }
  end

  test "packages can supply tasks", %{provider_location: provider, consumer_location: consumer} do
    shell_env = [
      {"BOOTLEG_PATH", File.cwd!},
      {"TASK_PROVIDER_PATH", provider}
    ]

    assert {_, 0} = System.cmd("mix", ["deps.get"], [env: shell_env, cd: consumer])
    assert {out, _} = System.cmd("mix", ["bootleg.build"], [env: shell_env, cd: consumer, stderr_to_stdout: true])
    assert String.match?(out, ~r/~~OTHER TASK~~/)
    assert String.match?(out, ~r/~~EXAMPLE TASK~~/)
  end
end
