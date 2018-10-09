alias Bootleg.{UI, Config}
use Bootleg.DSL

task :verify_repo_config do
  if config(:repo_url) == nil do
    raise "Error: repo_url is not set.\n" <>
            "# config(:repo_url, \"git@github.com/me/my_app.git\")"
  end
end

task :remote_build do
  UI.info("Starting remote build")
  build_role = Config.get_role(:build)
  invoke(:init)
  invoke(:clean)
  invoke :remote_scm_update
  invoke(:compile)
  invoke(:generate_release)

  if build_role.options[:release_workspace] do
    invoke(:copy_build_release)
  else
    invoke(:download_release)
  end
end

task :remote_scm_update do
  if config({:git_mode, :push}) == :pull do
    invoke :pull_remote
  else
    invoke :push_remote
    invoke :reset_remote
  end
end

task :generate_release do
  UI.info("Generating release")
  mix_env = config({:mix_env, "prod"})
  source_path = config({:ex_path, ""})

  remote :build, cd: source_path do
    "MIX_ENV=#{mix_env} mix release"
  end
end

task :init do
  remote :build do
    "git init"
    "git config receive.denyCurrentBranch ignore"
  end
end

task :compile do
  mix_env = config({:mix_env, "prod"})
  source_path = config({:ex_path, ""})
  UI.info("Compiling remote build")

  remote :build, cd: source_path do
    "MIX_ENV=#{mix_env} mix local.rebar --force"
    "MIX_ENV=#{mix_env} mix local.hex --force"
    "MIX_ENV=#{mix_env} mix deps.get --only=prod"
    "MIX_ENV=#{mix_env} mix deps.compile"
    "MIX_ENV=#{mix_env} mix compile"
  end
end

task :clean do
  locations =
    {:clean_locations, ["*"]}
    |> config()
    |> List.wrap()
    |> Enum.join(" ")

  if locations != "" do
    remote :build do
      "rm -rvf #{locations}"
    end
  end
end

task :copy_build_release do
  build_role = Config.get_role(:build)
  mix_env = config({:mix_env, "prod"})
  app_name = Config.app()
  app_version = Config.version()
  release_workspace = build_role.options[:release_workspace]
  source_path = "_build/#{mix_env}/rel/#{app_name}/releases/#{app_version}/#{app_name}.tar.gz"
  dest_path = Path.join(release_workspace, "#{app_version}.tar.gz")

  UI.info("Copying release archive to release workspace")

  remote :build do
    "mkdir -p #{release_workspace}"
    "cp #{source_path} #{dest_path}"
  end
end

task :download_release do
  mix_env = config({:mix_env, "prod"})
  source_path = config({:ex_path, ""})
  app_name = Config.app()
  app_version = Config.version()

  remote_path =
    Path.join(
      source_path,
      "_build/#{mix_env}/rel/#{app_name}/releases/#{app_version}/#{app_name}.tar.gz"
    )

  local_archive_folder = "#{File.cwd!()}/releases"
  local_path = Path.join(local_archive_folder, "#{app_version}.tar.gz")

  UI.info("Downloading release archive")
  File.mkdir_p!(local_archive_folder)

  download(:build, remote_path, local_path)
end

task :reset_remote do
  refspec = config({:refspec, "master"})
  UI.info("Resetting remote hosts to refspec \"#{refspec}\"")

  remote :build do
    "git reset --hard #{refspec}"
  end
end

task :push_remote do
  alias Bootleg.{SSH, Git}
  refspec = config({:refspec, "master"})
  build_role = Config.get_role(:build)

  build_host =
    build_role.hosts
    |> List.first()
    |> SSH.ssh_host_options()

  options = Keyword.merge(build_host.options, build_role.options)

  user_host = "#{build_role.user}@#{build_host.name}"
  port = options[:port]

  user_host_port =
    if port do
      "#{user_host}:#{port}"
    else
      user_host
    end

  workspace = options[:workspace]

  host_url =
    case Path.type(workspace) do
      :absolute -> "ssh://#{user_host_port}#{workspace}"
      _ -> "ssh://#{user_host_port}/~/#{workspace}"
    end

  push_options = config({:push_options, "-f"})

  git_ssh_options =
    options
    |> Enum.map(fn {key, value} ->
      case key do
        :identity -> "-i '#{value}'"
        :silently_accept_hosts -> "-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"
        _ -> nil
      end
    end)
    |> Enum.filter(fn v -> v end)

  git_env =
    case Enum.count(git_ssh_options) > 0 do
      true -> [{"GIT_SSH_COMMAND", "ssh #{Enum.join(git_ssh_options, " ")}"}]
      false -> []
    end

  UI.info("Pushing new commits with git to: #{user_host_port}")

  case Git.push(["--tags", push_options, host_url, refspec], env: git_env) do
    {"", 0} ->
      :ok

    {result, 0} ->
      UI.puts(result)
      :ok

    {result, status} ->
      UI.puts(result)
      {:error, status}
  end
end

task :pull_remote do
  refspec = config({:refspec, "master"})
  repo_url = config(:repo_url)
  build_role = Config.get_role(:build)
  workspace = build_role.options[:workspace]

  repo_path =
    if build_role.options[:repo_path], do: build_role.options[:repo_path], else: "/tmp/repos"

  remote :build do
    "mkdir -p #{repo_path}"
  end

  [{:ok, result, 0, _}] =
    remote :build, cd: repo_path do
      "ls -la"
    end

  result =
    result
    |> Keyword.get_values(:stdout)
    |> Enum.join("\n")

  unless result =~ "#{Config.app()}.git" do
    remote :build, cd: repo_path do
      "git clone --mirror #{repo_url} #{Config.app()}.git"
    end
  end

  workspace_path =
    case Path.type(workspace) do
      :absolute ->
        workspace

      _ ->
        "/home/#{build_role.user}/#{workspace}"
    end

  UI.info("Pulling new commits with git from: #{repo_url}")

  remote :build, cd: "#{repo_path}/#{Config.app()}.git" do
    "git remote set-url origin #{repo_url}"
    "git remote update --prune"
    "git archive #{refspec} | tar -x -f - -C #{workspace_path}"
  end
end

before_task(:pull_remote, :verify_repo_config)
