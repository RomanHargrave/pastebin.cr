# Used in handle generation
private ALPHABET_TABLE = ('0'...'9').to_a + ('a'...'z').to_a + ('A'...'Z').to_a

# Generate nonsense n characters long
private def rand_chars(len : UInt64): String
   String::Builder.build do |builder|
      len.times do 
         builder << ALPHABET_TABLE[rand(ALPHABET_TABLE.size)]
      end
   end
end

module Pastebin

   # Abstraction over storing a blob of text and assigning a name to it
   #
   # Caller workflow -
   #   Storage#store(data : IO) -> handle : String
   #   Storage#get(handle : String) -> data : IO
   abstract class Storage
      abstract def store(data : IO) : String
      abstract def get(handle : Sring) : IO

      class UnassociatedHandleError < IO::Error
         def initialize(handle : String)
            super("No data for that handle (#{handle})");
         end
      end
   end

   class FileStorage < Storage
      private def path_for_handle(handle : String) : String
         "#{@folder}/#{handle}"
      end

      # storageFolder - path to folder
      def initialize(storageFolder : String, handleLength : UInt64)
         if !Dir.exists?(storageFolder) && !File.exists?(storageFolder)
            Dir.mkdir_p(storageFolder)
         elsif !File.directory?(storageFolder)
            raise "The specified storage path (#{storageFolder}) exists, but is not a directory"
         end

         @folder         = storageFolder
         @handle_length  = handleLength
      end

      def store(data : IO) : String
         # Collision avoidance
         handle = ::rand_chars(@handle_length) 
         until !File.exists?(path_for_handle(handle))
            handle = ::rand_chars(@handle_length)
         end

         filePath = path_for_handle(handle)
         file = File.new(filePath, mode = "w")
         IO.copy(data, file)
         file.close()

         handle
      end

      def get(handle : String) : IO
         filePath = path_for_handle(handle)
         if File.exists?(filePath)
            File.open(filePath)
         else
            raise Storage::UnassociatedHandleError.new(handle)
         end
      end
   end
end
