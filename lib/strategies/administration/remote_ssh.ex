defmodule Bootleg.Strategies.Administration.RemoteSSH do
  @moduledoc ""

  alias Bootleg.Config
  alias Bootleg.AdministrationConfig
  alias Bootleg.SSH

  def init(%Config{administration: %AdministrationConfig{identity: identity, host: host, user: user} = config}) do
    with {:ok, _} <- check_config(config),
         :ok <- SSH.start(),
         {:ok, identity_file} <- File.open(identity) do
           host 
           |> SSH.connect(user, identity_file)  
    else
      {:error, msg} -> raise "Error: #{msg}"
    end
  end

  def start(conn, %Config{app: app, administration: %AdministrationConfig{workspace: workspace}}) do
    SSH.safe_run(conn, workspace, "bin/#{app} start")
    IO.puts "#{app} started"
    {:ok, conn}
  end

  def restart(conn, %Config{app: app, administration: %AdministrationConfig{workspace: workspace}}) do
    SSH.safe_run(conn, workspace, "bin/#{app} restart")
    IO.puts "#{app} restarted"
    {:ok, conn}
  end

  defp check_config(%AdministrationConfig{} = config) do
    missing =  Enum.filter(~w(host user workspace), &(Map.get(config, &1, 0) == nil))
    if Enum.count(missing) > 0 do
      raise "RemoteSSH administration strategy requires #{inspect Map.keys(missing)} to be set in the administration configuration"
    end
    {:ok, config}        
  end

end