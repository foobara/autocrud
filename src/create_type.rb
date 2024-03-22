require_relative "build_type"

module Foobara
  module Autocrud
    class CreateType < AutocrudCommand
      depends_on BuildType
      depends_on_entity PersistedType

      inputs do
        type_declaration :associative_array, :required
        domain :duck
        type_symbol :symbol, :allow_nil
      end

      def execute
        build_type
        persist_type

        type
      end

      attr_accessor :type

      def build_type
        self.type = run_subcommand!(BuildType, type_declaration:, domain:, type_symbol:)
      end

      def persist_type
        PersistedType.create(
          Util.remove_blank(
            type_declaration: type.declaration_data,
            type_symbol: type.type_symbol,
            full_domain_name: type.foobara_domain.scoped_full_name
          )
        )
      end
    end
  end
end
