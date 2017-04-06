require "crouter"

require "./storage.cr"

require "route"

module Pastebin

   # HTTP adapter for text storage
   class Storage2HTTP < Route::RouteHandler
      include Route

      @action_Submit = API.new do |context|
         case context.request.body()
         when Nil
            context.response.respond_with_error("No request body")
         when IO
            paste_handle = @storage.store(context.request.body.as(IO))
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

         context
      end

      def initialize(@storage : ::Pastebin::Storage)
         super()

         draw(self) do
            post "/",          @action_Submit
            get  "/:pasteid",  @action_View
         end
      end
   end

end
