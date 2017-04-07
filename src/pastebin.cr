require "logger"
require "ini"
require "route"

require "./storage.cr"
require "./http.cr"


private CONFIG_PATH_VAR_NAME = "PASTEBIN_CONFIG"
private CONFIG_FILE_NAME = "crystal_paste.ini"

# Splashpage
private VIEW_landing_page = <<-PAGE
paste.cr(1)                       PASTE.CR                          paste.cr(1)

NAME
   paste.cr: sprunge clone written in crystal

SYNOPSIS
   Submitting:
      <command> | curl -F paste=@- (host)
      curl -F paste=@/path/to/file (host)
      curl --data-binary @/path/to/file (host)
      <command> | curl --data-binary @- (host)

   Retrieving:
      https?://host/ab123
      https?://host/ab123?mime=mime/type

EXAMPLES
   $ curl -F paste=@/path/to/file
     aB123

SEE ALSO
   http://github.com/romanhargrave/pastebin.cr
PAGE

private class DefaultRouteHandler < Route::RouteHandler
   include Route

   def initialize()
      super() 

      @action_Default = API.new do |context|
         context.response << VIEW_landing_page
         context
      end

      draw(self) do 
         get "/", @action_Default
      end
   end
end


###############################################################################

log = Logger.new(STDERR)

# Try to locate a configuration file ($PWD/crystal_paste.ini or PASTEBIN_CONFIG)
config = if ENV.has_key?(CONFIG_PATH_VAR_NAME) && File.exists?(ENV[CONFIG_PATH_VAR_NAME])
            INI.parse(File.read(ENV[CONFIG_PATH_VAR_NAME]))
         elsif File.exists?(CONFIG_FILE_NAME)
            INI.parse(File.read(CONFIG_FILE_NAME))
         else
            log.fatal("No config file found either at ./#{CONFIG_FILE_NAME} or in the env var #{CONFIG_PATH_VAR_NAME}")
            raise "No config file found"
         end


# FileStorage will mkdir_p if the path doesn't exist
storage = Pastebin::FileStorage.new(config["storage"]["directory"], config["pastebin"]["name_length"].to_u64)
http_adapter = Pastebin::Storage2HTTP.new(storage, log)



server = HTTP::Server.new(config["network"]["address"], config["network"]["port"].to_i32,
                          [
                             HTTP::LogHandler.new,
                             http_adapter,
                             DefaultRouteHandler.new
                          ]);
server.listen
