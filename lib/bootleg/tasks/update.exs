alias Bootleg.{Config, DSL}
use DSL

task :update do
  invoke(:build)
  invoke(:deploy)
  invoke(:stop_silent)
  invoke(:start)
end

task :stop_silent do
  nodetool = "bin/#{Config.app()}"

  remote :app, cd: "current" do
    "#{nodetool} describe && (#{nodetool} stop || true)"
  end
end
