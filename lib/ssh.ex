defmodule Bootleg.SSH do
  @moduledoc "Provides SSH related tools for use in `Bootleg.Strategies`."

  alias SSHKit.SSH.ClientKeyAPI

  @runner Application.get_env(:bootleg, :sshkit) || SSHKit

  def start, do: :ssh.start()

  def connect(hosts, user, options \\ []) do
      workspace = Keyword.get(options, :workspace, ".")
      IO.puts "Creating remote context at '#{workspace}'"
      hosts
      |> List.wrap
      |> Enum.map(fn(host) -> %SSHKit.Host{name: host, options: ssh_opts(user, options)} end)
      |> SSHKit.context
      |> SSHKit.pwd(workspace)
  end

  def run(conn, cmd, working_directory \\ nil) do
    IO.puts " -> $ #{cmd}"
    @runner.run(conn, cmd)
  end

  def run!(conn, cmd, working_directory \\ nil)

  def run!(conn, cmd, working_directory) when is_list(cmd) do
    Enum.map(cmd, fn c -> run!(conn, c, working_directory) end)
  end

  def run!(conn, cmd, working_directory) do
    case run(conn, cmd) do
      [{:ok, output, 0}|_] = result -> result
      [{:ok, output, status}|_] -> raise SSHError, [cmd, output, status]
    end
  end

  def download(conn, remote_path, local_path) do
    IO.puts " -> downloading #{remote_path} --> #{local_path}"
    case @runner.download(conn, remote_path, as: local_path) do
      [:ok|_] -> :ok
      [{_, msg}|_] -> raise "SCP download error: #{inspect msg}"
    end
  end

  def upload(conn, local_path, remote_path) do
    IO.puts " -> uploading #{local_path} --> #{remote_path}"
    case @runner.upload(conn, local_path, as: remote_path) do
      [:ok|_] -> :ok
      [{_, msg}|_] -> raise "SCP upload error #{inspect msg}"
    end
  end

  defp ssh_opts(user, options) when is_list(options) do
    identity_file = Keyword.get(options, :identity, nil)
    case File.open(identity_file) do
      {:ok, identity} ->
        key_cb = ClientKeyAPI.with_options(identity: identity, accept_hosts: true)
        Keyword.merge(default_opts(), [user: user, key_cb: key_cb])
      {_, msg} -> raise "Error: #{msg}"
    end
  end

  defp ssh_opts(user, _), do: Keyword.merge(default_opts(), [user: user])

  defp default_opts do
    [
      connect_timeout: 5000,
    ]
  end
end
