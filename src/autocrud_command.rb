module Foobara
  module Autocrud
    class AutocrudCommand < Foobara::Command
      def validate
        validate_base!
      end

      def validate_base!
        raise NoBaseSetError unless Autocrud.base
      end
    end
  end
end
