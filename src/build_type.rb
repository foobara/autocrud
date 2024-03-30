module Foobara
  module Autocrud
    class BuildType < AutocrudCommand
      inputs do
        type_declaration :associative_array, :required
        domain :duck
        type_symbol :symbol, :allow_nil
      end

      def execute
        determine_domain
        build_type
        register_type_if_needed
        create_autocrud_commands_if_needed

        type
      end

      attr_accessor :domain, :type

      def determine_domain
        domain = inputs[:domain]

        # TODO: remove global domain from here...
        self.domain = Domain.to_domain(domain)
      rescue Domain::NoSuchDomain => e
        if domain.is_a?(::String) || domain.is_a?(::Symbol)
          self.domain = Domain.create(domain)
        else
          # :nocov:
          raise e
          # :nocov:
        end
      end

      def build_type
        self.type = (domain || GlobalDomain).foobara_type_from_declaration(type_declaration)
      end

      def register_type_if_needed
        if type.registered?
          if type_symbol && type_symbol.to_sym != type.type_symbol
            # :nocov:
            raise "Type symbol mismatch: #{type_symbol} versus #{type.type_symbol}"
            # :nocov:
          end
        else
          type.type_symbol = type_symbol
          type.foobara_parent_namespace ||= domain
          type.foobara_parent_namespace.foobara_register(type)
        end
      end

      def create_autocrud_commands_if_needed
        if type.extends?(:entity)
          Autocrud.create_autocrud_commands(type.target_class)
        end
      end
    end
  end
end
