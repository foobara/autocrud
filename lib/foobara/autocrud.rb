require "foobara/all"

module Foobara
  Util.require_directory(__dir__)

  module Autocrud
    foobara_domain!

    class << self
      attr_accessor :base

      def create_type(declaration_data:, type_symbol: nil, domain: nil)
        type = load_type(declaration_data:, type_symbol:, domain:)

        domain = Domain.to_domain(type)

        unless domain.global?
          full_domain_name = domain.full_domain_name
        end

        PersistedType.transaction do
          PersistedType.create(
            type_declaration: type.declaration_data,
            type_symbol: type.type_symbol,
            full_domain_name:
          )
        end
      end

      def load(persisted_type)
        full_domain_name = persisted_type.full_domain_name
        domain = begin
          Domain.to_domain(full_domain_name)
        rescue Foobara::Domain::NoSuchDomain
          Domain.create(full_domain_name)
        end

        domain.name
      end

      def load_type(declaration_data:, type_symbol: nil, domain: nil)
        domain = begin
          Domain.to_domain(domain)
        rescue Foobara::Domain::NoSuchDomain
          Domain.create(domain)
        end

        type = domain.namespace.type_for_declaration(declaration_data)

        if type.registered?
          if type_symbol && type_symbol.to_sym != type.type_symbol
            raise "Type symbol mismatch: #{type_symbol} versus #{type.type_symbol}"
          end

          type_symbol = type.type_symbol
        else
          domain.namespace.register_type(type_symbol, type)
        end

        type
      end

      def install!
        raise NoBaseSetError unless base

        base.register_entity_class(PersistedType, table_name: :persisted_types)

        PersistedType.all do |persisted_type|
          load_type(
            declaration_data: persisted_type.declaration_data,
            type_symbol: persisted_type.type_symbol,
            domain: persisted_type.full_domain_name
          )

          create_autocrud_commands(type)
        end
      end

      def create_autocrud_commands(type)
        # TODO: autocrud commands!
      end
    end
  end
end
