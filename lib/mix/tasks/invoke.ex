defmodule Mix.Tasks.Bootleg.Invoke do
  use Bootleg.MixTask
  alias Bootleg.{UI, Config, Tasks}

  @shortdoc "Calls an arbitrary Bootleg task"

  @moduledoc """
  #{@shortdoc}

  # Usage:

    * mix bootleg.invoke <:task>

  """

  def run([]) do
    UI.error("You must supply a task identifier as the first argument.")
    System.halt(1)
  end

  def run(args) do
    use Config

    {env, task} = Tasks.parse_env_task(args)

    if env do
      Config.env(env)
    end

    invoke(task)
  end
end
