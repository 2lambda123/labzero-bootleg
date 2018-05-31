alias Bootleg.{UI, Config}
use Bootleg.DSL

task :restart do
  remote :app, cd: "current" do
    "bin/#{Config.app()} restart"
  end

  UI.info("#{Config.app()} restarted")
  :ok
end
