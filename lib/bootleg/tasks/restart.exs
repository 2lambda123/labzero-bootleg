alias Bootleg.{UI, Config}
use Bootleg.Config

task :restart do
  remote :app do
    "bin/#{Config.app} restart"
  end
  UI.info "#{Config.app} restarted"
  :ok
end
