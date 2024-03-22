require_relative "create_type"

module Foobara
  module Autocrud
    class CreateEntity < AutocrudCommand
      depends_on CreateType

      inputs do
        name :string, :required
        attributes_declaration :duck, :required
        domain :duck
      end

      result :duck

      def execute
        determine_domain
        desugarize_attributes_declaration

        build_type_declaration
        create_type

        entity_class
      end

      attr_accessor :domain, :type_declaration, :type, :desugarized_attributes_declaration

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

      def desugarize_attributes_declaration
        self.desugarized_attributes_declaration = if attributes_declaration.is_a?(Proc)
                                                    TypeDeclarations::Dsl::Attributes.to_declaration(
                                                      &attributes_declaration
                                                    )
                                                  else
                                                    attributes_handler.desugarize(attributes_declaration)
                                                  end
      end

      def build_type_declaration
        self.type_declaration = {
          type: :entity,
          attributes_declaration: desugarized_attributes_declaration,
          name:,
          primary_key: desugarized_attributes_declaration[:element_type_declarations].keys.first
        }

        if domain && domain != GlobalDomain
          type_declaration[:model_module] = domain
        end
      end

      def create_type
        self.type = run_subcommand!(CreateType, type_declaration:)
      end

      def entity_class
        type.target_class
      end

      def attributes_handler
        domain.foobara_type_builder.handler_for_class(TypeDeclarations::Handlers::ExtendAttributesTypeDeclaration)
      end
    end
  end
end
