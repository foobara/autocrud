module Foobara
  module Autocrud
    # TODO: delete this error once everything is implemented as commands
    class NoBaseSetError < StandardError
      def initialize
        super(
          "You need to set Foobara::Autocrud.base. " \
          "Try `Autocrud.base = Foobara::Persistence.default_base` if you just want to use the default base."
        )
      end
    end
  end
end
