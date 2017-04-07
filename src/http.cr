require "route"
require "logger"

require "./storage.cr"


module Pastebin

   # HTTP adapter for text storage
   class Storage2HTTP < Route::RouteHandler
      include Route

      private def find_client_ip(rq : HTTP::Request) : String
         # No field exists for native client IP, luckily the application will be run behind an LB/RP
         case ip = rq.headers["X-Forwarded-For"]?
         when String
            ip
         else
            "(IP Unknown)"
         end
      end

      def initialize(@storage : ::Pastebin::Storage, @logger : ::Logger)
         super()

         @action_Submit = API.new do |context|
            # NOTE implicit type "comprehension" of unions only works on true fields, not "synthetic" fields 
            case body = context.request.body
            when Nil
               @logger.warn("Client sent an empty request to submit endpoint")
               context.response.respond_with_error("No request body")
            when IO
               # Figure out what the uploader is giving us, and how they are going to do it
               paste_handle = case content_header = context.request.headers["Content-Type"]?
                              when .=~ %r(^multipart/form-data)
                                 @logger.debug("Recieving upload as form data")

                                 # Pick the first file/field in the form
                                 handle = ""
                                 HTTP::Multipart.parse(context.request) do |hdr, io|
                                    @logger.debug("Selected form file is of type '#{hdr["Content-Type"]}' with disposition '#{hdr["Content-Disposition"]}'")
                                    handle = @storage.store(io)
                                    break
                                 end
                                 handle 
                              else
                                 @logger.debug("Recieving raw data (request body -> file)")
                                 @storage.store(body)
                              end

               puts "paste_handle #{paste_handle.class} #{typeof(paste_handle)} #{paste_handle}"

               @logger.info("Client #{find_client_ip(context.request)} uploaded to handle #{paste_handle}")

               context.response.headers["Location"] = "/#{paste_handle}"
               context.response << paste_handle
            end

            context
         end

         @action_View = API.new do |context, params|
            # Try to get the paste from storage
            begin
               paste = @storage.get(params["pasteid"])
               IO.copy(paste, context.response)
               paste.close()
            rescue notFound : Storage::UnassociatedHandleError
               context.response.respond_with_error(notFound.message, 404)
            end

            context.response.headers["Content-Type"] = case requested = params["mime"]?
                                                       when String
                                                          requested
                                                       else
                                                          "text/plain"
                                                       end

            context
         end

         draw(self) do
            post "/",          @action_Submit
            get  "/:pasteid",  @action_View
         end
      end
   end

end
