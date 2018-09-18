defmodule Mix.Tasks.Bootleg.Init do
  use Bootleg.MixTask
  require Mix.Generator
  alias Bootleg.Env
  alias Mix.Generator

  @shortdoc "Initializes a project for use with Bootleg"

  @moduledoc """
    Initializes a project for use with Bootleg.
  """

  def run(_args) do
    production_file_path = Path.join(Env.deploy_config_dir(), "production.exs")
    Generator.create_directory("config")
    Generator.create_file(Env.deploy_config(), deploy_file_text())
    Generator.create_directory(Env.deploy_config_dir())
    Generator.create_file(production_file_path, production_file_text())
  end

  Generator.embed_text(:deploy_file, """
  use Bootleg.DSL

  # Configure the following roles to match your environment.
  # `build` defines what remote server your distillery release should be built on.
  #
  # Some available options are:
  #  - `user`: ssh username to use for SSH authentication to the role's hosts
  #  - `password`: password to be used for SSH authentication
  #  - `identity`: local path to an identity file that will be used for SSH authentication instead of a password
  #  - `workspace`: remote file system path to be used for building and deploying this Elixir project

  role :build, "build.example.com", workspace: "/tmp/bootleg/build"

  """)

  Generator.embed_text(:production_file, """
  use Bootleg.DSL

  # Configure the following roles to match your environment.
  # `app` defines what remote servers your distillery release should be deployed and managed on.
  #
  # Some available options are:
  #  - `user`: ssh username to use for SSH authentication to the role's hosts
  #  - `password`: password to be used for SSH authentication
  #  - `identity`: local path to an identity file that will be used for SSH authentication instead of a password
  #  - `workspace`: remote file system path to be used for building and deploying this Elixir project

  role :app, ["app1.example.com", "app2.example.com"], workspace: "/var/app/example"

  """)
end
