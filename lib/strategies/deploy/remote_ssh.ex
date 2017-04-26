defmodule Bootleg.Strategies.Deploy.RemoteSSH do
  @moduledoc ""

  alias Bootleg.Config
  alias Bootleg.DeployConfig
  alias Bootleg.SSH

  @config_keys ~w(host user workspace)

  def deploy(%Config{version: version, app: app, deploy: %DeployConfig{workspace: workspace}} = config) do
    conn = init(config)
    deploy_release_archive(conn, workspace, app, version)
  end

  defp deploy_setup_script(workspace) do
      "
      set -e
      mkdir -p #{workspace}
      "
  end

  defp init(%Config{deploy: %DeployConfig{identity: identity, workspace: workspace, host: host, user: user} = config}) do
    with :ok <- Bootleg.check_config(config, @config_keys),
         :ok <- SSH.start(),
         {:ok, identity_file} <- File.open(identity) do
            host 
            |> SSH.connect(user, identity_file)
            |> SSH.run(deploy_setup_script(workspace))
    else
      {:error, msg} -> raise "Error: #{msg}"
    end
  end

  defp deploy_release_archive(conn, workspace, app, version) do
    remote_path = "#{workspace}/#{app}.tar.gz"
    local_archive_folder = "#{File.cwd!}/releases"
    local_path = Path.join(local_archive_folder, "#{app}-#{version}.tar.gz")

    IO.puts "Uploading release archive"
    IO.puts " <-  local: #{local_path}"
    IO.puts " -> remote: #{remote_path}"

    case SSH.upload(conn, local_path, remote_path) do
      :ok -> conn
      {:error, msg} -> raise "Error: uploading of release archive failed: #{msg}"
    end
    unpack_cmd = "tar -zxvf #{remote_path}"
    SSH.safe_run(conn, workspace, unpack_cmd)
    IO.puts "Unpacked release archive"
  end
end
