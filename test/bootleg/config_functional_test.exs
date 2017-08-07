defmodule Bootleg.ConfigFunctionalTest do
  use Bootleg.FunctionalCase, async: false
  import ExUnit.CaptureIO

  setup %{hosts: hosts} do
    use Bootleg.Config

    app_host = hd(hosts)
    build_hosts = tl(hosts)

    role :app, app_host.ip, port: app_host.port, user: app_host.user,
      password: app_host.password, silently_accept_hosts: true, workspace: "workspace", foo: :bar

    build_hosts
    |> Enum.with_index
    |> Enum.each(fn {build_host, index} ->
      role :build, build_host.ip, port: build_host.port, user: build_host.user,
        password: build_host.password, silently_accept_hosts: true, workspace: "workspace", foo: index
    end)
  end

  @tag boot: 3
  test "remote/2" do
    use Bootleg.Config

    task :remote_functional_test do
      out = remote :app do
        "echo Hello World!"
        "uname -a"
      end
      assert [[{:ok, [stdout: "Hello World!\n"], 0, _}], [{:ok, [stdout: uname], 0, _}]] = out
      assert Regex.match?(~r/Linux$/mu, uname)
    end

    task :remote_functional_single_line_test do
      out = remote :app do
        "echo a single line!"
      end
      assert [{:ok, [stdout: "a single line!\n"], 0, _}] = out
    end

    task :remote_functional_stderr_test do
      out = remote :app do
        "echo a single line! && echo foo 1>&2"
      end
      assert [{:ok, [stdout: "a single line!\n", stderr: "foo\n"], 0, _}] = out
    end

    task :remote_multiple_hosts do
      out = remote :build do
        "echo a single line!"
      end
      assert [{:ok, [stdout: "a single line!\n"], 0, _}, {:ok, [stdout: "a single line!\n"], 0, _}] = out
    end

    task :remote_multiple_hosts_multiple_lines do
      out = remote :build do
        "echo a single line!"
        "echo another line"
      end
      assert [[{:ok, [stdout: "a single line!\n"], 0, _}, {:ok, [stdout: "a single line!\n"], 0, _}],
        [{:ok, [stdout: "another line\n"], 0, _}, {:ok, [stdout: "another line\n"], 0, _}]] = out
    end

    capture_io(fn ->
      assert :ok = invoke :remote_functional_test
      assert :ok = invoke :remote_functional_single_line_test
      assert :ok = invoke :remote_functional_stderr_test
      assert :ok = invoke :remote_multiple_hosts
      assert :ok = invoke :remote_multiple_hosts_multiple_lines
    end)
  end

  @tag boot: 2
  test "remote/2 multiple roles" do
    use Bootleg.Config

    task :remote_multiple_roles do
      out = remote [:app, :build] do
        "echo `hostname`"
      end
      assert [[{:ok, [stdout: hostname_1], 0, _}, {:ok, [stdout: hostname_2], 0, _}]] = out
      assert hostname_1 != hostname_2
    end

    task :remote_multiple_roles_multiple_commands do
      out = remote [:app, :build] do
        "echo `hostname`"
        "echo foo"
      end
      assert [[{:ok, [stdout: hostname_1], 0, _}, {:ok, [stdout: hostname_2], 0, _}],
        [{:ok, [stdout: foo_1], 0, _}, {:ok, [stdout: foo_2], 0, _}]] = out
      assert hostname_1 != hostname_2
      assert foo_1 == foo_2
    end

    task :remote_all_roles do
      out = remote :all do
        "echo `hostname`"
      end
      assert [[{:ok, [stdout: hostname_1], 0, _}, {:ok, [stdout: hostname_2], 0, _}]] = out
      assert hostname_1 != hostname_2
    end

    task :remote_all_roles_multiple_commands do
      out = remote :all do
        "echo `hostname`"
        "echo foo"
      end
      assert [[{:ok, [stdout: hostname_1], 0, _}, {:ok, [stdout: hostname_2], 0, _}],
        [{:ok, [stdout: foo_1], 0, _}, {:ok, [stdout: foo_2], 0, _}]] = out
      assert hostname_1 != hostname_2
      assert foo_1 == foo_2
    end

    capture_io(fn ->
      assert :ok = invoke :remote_multiple_roles
      assert :ok = invoke :remote_multiple_roles_multiple_commands
      assert :ok = invoke :remote_all_roles
      assert :ok = invoke :remote_all_roles_multiple_commands
    end)
  end

  test "remote/2 fails remotely" do
    use Bootleg.Config

    task :remote_functional_negative_test do
      remote :app do
        "false"
      end
    end

    capture_io(fn ->
      assert_raise SSHError, fn -> invoke :remote_functional_negative_test end
    end)
  end

  @tag boot: 3
  test "remote/3 filtering" do
    capture_io(fn ->
      use Bootleg.Config

      assert [{:ok, out_0, 0, _}] = remote :build, [foo: 0], "hostname"
      assert [{:ok, out_1, 0, _}] = remote :build, [foo: 1], do: "hostname"
      assert out_1 != out_0

      assert [] = remote :build, [foo: :bar], "hostname"
      assert [{:ok, out_all, 0, _}] = remote :all, [foo: :bar], "hostname"
      assert out_1 != out_0 != out_all

      remote :all, [foo: :bar] do "hostname" end
    end)
  end

  @tag boot: 3
  test "upload/3" do
    capture_io(fn ->
      use Bootleg.Config

      task :upload_single_role_single_host do
        path = Temp.open!("upload", &IO.write(&1, "upload_single_role"))
        upload :app, path, "single_role"
      end

      task :upload_single_role_multi_host do
        path = Temp.open!("upload", &IO.write(&1, "upload_single_role_multi"))
        upload :build, path, "single_role_multi"
      end

      task :upload_multi_role do
        path = Temp.open!("upload", &IO.write(&1, "upload_multi_role"))
        upload [:app, :build], path, "multi_role"
      end

      task :upload_all_role do
        path = Temp.open!("upload", &IO.write(&1, "upload_all_role"))
        upload :all, path, "all_role"
      end

      task :upload_role_filtered do
        path = Temp.open!("upload", &IO.write(&1, "upload_role_filtered"))
        upload [:all, primary: true], path, "role_filtered"
      end

      task :upload_directory do
        path = Temp.mkdir!("upload")
        File.write!(Path.join(path, "foo"), "some data")
        File.write!(Path.join(path, "bar"), "more data")
        File.mkdir!(Path.join(path, "some_dir"))
        File.write!(Path.join([path, "some_dir", "war"]), "different data")
        upload :app, path, "should_be_dir"
      end

      task :upload_absolute do
        path = Temp.open!("upload", &IO.write(&1, "absolute"))
        upload :app, path, "/tmp/absolute"
      end

      task :upload_preserve_name do
        path = Temp.open!("upload", &IO.write(&1, "same name"))
        upload :app, path, "."
        remote :app, do: "grep '^same name$' #{Path.basename(path)}"
      end

      invoke :upload_single_role_single_host
      remote :app, do: "grep '^upload_single_role$' single_role"

      invoke :upload_single_role_multi_host
      remote :build, do: "grep '^upload_single_role_multi$' single_role_multi"

      invoke :upload_multi_role
      remote [:app, :build], do: "grep '^upload_multi_role$' multi_role"

      invoke :upload_all_role
      remote :all, do: "grep '^upload_all_role$' all_role"

      invoke :upload_role_filtered
      assert_raise SSHError, fn ->
        # credo:disable-for-next-line Credo.Check.Consistency.MultiAliasImportRequireUse
        use Bootleg.Config
        remote :all, do: "grep '^upload_role_filtered$' role_filtered"
      end

      invoke :upload_directory
      remote :app, do: "[ -d should_be_dir ]"
      remote :app, do: "[ -d should_be_dir/some_dir ]"
      remote :app, do: "grep '^some data$' should_be_dir/foo"
      remote :app, do: "grep '^more data$' should_be_dir/bar"
      remote :app, do: "grep '^different data$' should_be_dir/some_dir/war"

      invoke :upload_absolute
      remote :app, do: "grep '^absolute$' /tmp/absolute"

      invoke :upload_preserve_name
    end)
  end
end
