defmodule Bootleg do

  @moduledoc """
  Documentation for Bootleg.
  """

  alias Mix.Project
  
  defmodule BuildConfig do

    defstruct [:identity, :host, :mix_env, :revision, :strategy, :user, :workspace]

    def init(config) do
      %__MODULE__{
        identity: config[:identity],
        strategy: config[:strategy],
        revision: Application.get_env(:bootleg, :revision), # TODO read from args      
        user: config[:user],
        host: config[:host],
        workspace: config[:workspace],      
        revision: config[:revision],        
        mix_env: Application.get_env(:bootleg, :mix_env, "prod")      
      }      
    end
  end

  defmodule DeployConfig do

    defstruct [:deploy_to, :identity, :host, :strategy, :user]

    def init(config) do
      %__MODULE__{
        deploy_to: config[:identity],
        identity: config[:identity],
        host: config[:host],
        strategy: config[:strategy],
        user: config[:user]
      }      
    end

  end

  defmodule AdministrationConfig do
    defstruct [:workspace, :identity, :host, :strategy, :user]

    def init(config) do
      %__MODULE__{
        workspace: config[:workspace],
        identity: config[:identity],
        host: config[:host],
        strategy: config[:strategy],
        user: config[:user]
      }      
    end
  end

  defmodule Config do

    defstruct [:app, :version, :build, :deploy, :archive, :administration]

    def init do
      %__MODULE__{
        app: Application.get_env(:bootleg, :app),
        version: Project.config[:version],            
        build: Bootleg.BuildConfig.init(Application.get_env(:bootleg, :build)),
        deploy: Bootleg.DeployConfig.init(Application.get_env(:bootleg, :deploy)),
        administration: Bootleg.AdministrationConfig.init(Application.get_env(:bootleg, :administration))
      }
    end
  end

  def config do
    Bootleg.Config.init()
  end
end