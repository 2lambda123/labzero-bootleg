defmodule Bootleg.Tasks.InvokeTaskTest do
  use Bootleg.TestCase
  alias Bootleg.Fixtures

  setup do
    location = Fixtures.inflate_project(:bootstraps)

    shell_env = [{"BOOTLEG_PATH", File.cwd!}]

    %{
      location: location,
      cmd_options: [env: shell_env, cd: location]
    }
  end

  test "mix bootleg.invoke", %{location: location, cmd_options: cmd_options} do
    location
    |> List.wrap
    |> Kernel.++(["config", "deploy.exs"])
    |> Path.join()
    |> File.write("""
      use Bootleg.Config
      task :hello, do: IO.puts "HELLO WORLD!"
    """, [:write])

    assert {_, 0} = System.cmd("mix", ["deps.get"], cmd_options)
    assert {out, 0} = System.cmd("mix", ["bootleg.invoke", "hello"], cmd_options)
    assert String.match?(out, ~r/HELLO WORLD!/)

    assert {_, 0} = System.cmd("mix", ["bootleg.invoke", "unknown"], cmd_options)

    assert {out, 1} = System.cmd("mix", ["bootleg.invoke"], cmd_options)
    assert String.match?(out, ~r/You must supply a task identifier as the first argument\./)
  end

  test "mix bootleg.invoke with env", %{location: location, cmd_options: cmd_options} do
    location
    |> List.wrap
    |> Kernel.++(["config", "deploy", "production.exs"])
    |> Path.join()
    |> File.write("""
      use Bootleg.Config
      task :foo, do: IO.puts "FOOBAR!"
    """, [:write])

    assert {_, 0} = System.cmd("mix", ["deps.get"], cmd_options)
    assert {out, 0} = System.cmd("mix", ["bootleg.invoke", "production", "foo"], cmd_options)
    assert String.match?(out, ~r/FOOBAR!/)
  end

  test "mix bootleg.invoke with env override", %{location: location, cmd_options: cmd_options} do
    location
    |> List.wrap
    |> Kernel.++(["config", "deploy.exs"])
    |> Path.join()
    |> File.write("""
      use Bootleg.Config
      task :foo, do: IO.puts "FOOBAR!"
    """, [:write])

    location
    |> List.wrap
    |> Kernel.++(["config", "deploy", "production.exs"])
    |> Path.join()
    |> File.write("""
      use Bootleg.Config
      task :foo, do: IO.puts "PRODWIZBANG!"
    """, [:write])

    assert {_, 0} = System.cmd("mix", ["deps.get"], cmd_options)
    assert {out, 0} = System.cmd("mix", ["bootleg.invoke", "production", "foo"], cmd_options)
    assert !String.match?(out, ~r/FOOBAR!/)
    assert String.match?(out, ~r/PRODWIZBANG!/)
  end

  test "mix bootleg.invoke with nonexisting env", %{cmd_options: cmd_options} do
    assert {_, 0} = System.cmd("mix", ["deps.get"], cmd_options)
    assert {out, 0} = System.cmd("mix", ["bootleg.invoke", "qa", "foo"], cmd_options)
    assert String.match?(out, ~r/there is no configuration defined/)
  end

  test "mix bootleg.invoke env set by default config as string", %{location: location, cmd_options: cmd_options} do
    location
    |> List.wrap
    |> Kernel.++(["config", "deploy.exs"])
    |> Path.join()
    |> File.write("""
      use Bootleg.Config
      config :env, "production"
    """, [:write])

    location
    |> List.wrap
    |> Kernel.++(["config", "deploy", "production.exs"])
    |> Path.join()
    |> File.write("""
      use Bootleg.Config
      task :foo, do: IO.puts "KATPOW!"
    """, [:write])

    assert {_, 0} = System.cmd("mix", ["deps.get"], cmd_options)
    assert {out, 0} = System.cmd("mix", ["bootleg.invoke", "production", "foo"], cmd_options)
    assert String.match?(out, ~r/KATPOW!/)
  end

  test "mix bootleg.invoke env set by default config as atom", %{location: location, cmd_options: cmd_options} do
    location
    |> List.wrap
    |> Kernel.++(["config", "deploy.exs"])
    |> Path.join()
    |> File.write("""
      use Bootleg.Config
      config :env, :production
    """, [:write])

    location
    |> List.wrap
    |> Kernel.++(["config", "deploy", "production.exs"])
    |> Path.join()
    |> File.write("""
      use Bootleg.Config
      task :foo, do: IO.puts "KATPOW!"
    """, [:write])

    assert {_, 0} = System.cmd("mix", ["deps.get"], cmd_options)
    assert {out, 0} = System.cmd("mix", ["bootleg.invoke", "production", "foo"], cmd_options)
    assert !String.match?(out, ~r/there is no configuration defined/)
    assert String.match?(out, ~r/KATPOW!/)
  end
end
