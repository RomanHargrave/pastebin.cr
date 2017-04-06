require "logger"
require "ini"

require "./storage.cr"
require "./http.cr"

private CONFIG_PATH_VAR_NAME = "PASTEBIN_CONFIG"
private CONFIG_FILE_NAME = "crystal_paste.ini"

log = Logger.new(STDERR)

# Try to locate a configuration file ($PWD/crystal_paste.ini or PASTEBIN_CONFIG)
config = if ENV.has_key?(CONFIG_PATH_VAR_NAME) && File.exists?(ENV[CONFIG_PATH_VAR_NAME])
            INI.parse(File.read(ENV[CONFIG_PATH_VAR_NAME]))
         elsif File.exists?(CONFIG_FILE_NAME)
            INI.parse(File.read(CONFIG_FILE_NAME))
         else
            raise "No config file found"
         end


# FileStorage will mkdir_p if the path doesn't exist
storage = Pastebin::FileStorage.new(config["storage"]["directory"], config["pastebin"]["name_length"].to_u64)
http_adapter = Pastebin::Storage2HTTP.new(storage)

server = HTTP::Server.new(config["network"]["address"], config["network"]["port"].to_i32,
                          [
                             HTTP::LogHandler.new,
                             http_adapter
                          ]);
server.listen
