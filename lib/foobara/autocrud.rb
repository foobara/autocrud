require "foobara/all"

module Foobara
  Util.require_directory(__dir__)

  module Autocrud
    foobara_domain!

    class << self
      attr_accessor :base

      def create_type(type_declaration:, type_symbol: nil, domain: nil)
        raise NoBaseSetError unless base

        type = load_type(type_declaration:, type_symbol:, domain:)

        domain = Domain.to_domain(type)

        unless domain.global?
          full_domain_name = domain.full_domain_name
        end

        PersistedType.transaction(mode: :use_existing) do
          PersistedType.create(
            Util.remove_blank(
              type_declaration: type.declaration_data,
              type_symbol: type.type_symbol,
              full_domain_name:
            )
          )
        end
      end

      def load_type(type_declaration:, type_symbol: nil, domain: nil)
        # TODO: do we need this?
        # if domain.nil?
        #   desugarizer = Foobara::TypeDeclarations::Handlers::ExtendModelTypeDeclaration::
        #       AttributesHandlerDesugarizer.instance
        #
        #   domain = if desugarizer.applicable?(type_declaration)
        #              desugarizer.desugarize(type_declaration)[:model_module]
        #            else
        #              desugarizer = Foobara::TypeDeclarations::Handlers::ExtendEntityTypeDeclaration::
        #                  AttributesHandlerDesugarizer.instance
        #
        #              if desugarizer.applicable?(type_declaration)
        #                desugarizer.desugarize(type_declaration)[:model_module]
        #              end
        #            end
        # end

        domain = begin
          Domain.to_domain(domain)
        rescue Foobara::Domain::NoSuchDomain
          Domain.create(domain)
        end

        type = domain.type_namespace.type_for_declaration(type_declaration)

        if type.registered?
          if type_symbol && type_symbol.to_sym != type.type_symbol
            # :nocov:
            raise "Type symbol mismatch: #{type_symbol} versus #{type.type_symbol}"
            # :nocov:
          end
        else
          domain.type_namespace.register_type(type_symbol, type)
        end

        if type.extends_symbol?(:entity)
          create_autocrud_commands(type.target_class)
        end

        type
      end

      def install!
        raise NoBaseSetError unless base

        base.register_entity_class(PersistedType, table_name: :persisted_types)

        PersistedType.transaction do
          PersistedType.all do |persisted_type|
            load_type(
              type_declaration: persisted_type.type_declaration,
              type_symbol: persisted_type.type_symbol,
              domain: persisted_type.full_domain_name
            )
          end
        end
      end

      def create_autocrud_commands(entity_class)
        # TODO: autocrud commands!
        # commands:
        #
        # CreateUser
        # UpdateUserAtom
        # UpdateUserAggregate
        #   can records be created in this situation?? or only updated?
        # HardDeleteUser
        # AppendToUserRatings
        # RemoveFromUserRatings
        # QueryUser
        #
        # types:
        #
        # User
        #   UserAttributes
        #   UserCreateAttributes
        #   UserUpdateAtomAttributes
        #     remove all required and defaults
        #     primary key required
        #   UserUpdateAggregateAttributes
        #     convert all associations to their XUpdateAggregateAttributes types??
        #   UserPrimaryKeyType ??
        # if primary key created by db
        #   no primary key in UserCreateAttributes
        # if primary key created externally
        #   primary key in UserCreateAttributes and is required
        # TODO: make types usable in type declarations...
        create_create_command(entity_class)
        create_update_user_atom_command(entity_class)
      end

      def create_update_user_atom_command(entity_class)
        command_class = Class.new(Foobara::Command)

        domain = entity_class.domain

        # TODO: make domain and domain_module the same thing to simplify some concepts
        domain_module = if domain.global?
                          Object
                        else
                          domain.mod
                        end

        domain_module.const_set("Update#{entity_class.entity_name}Atom", command_class)

        command_class.class_eval do
          define_method :entity_class do
            entity_class
          end

          # TODO: make this work with just inputs :UserAttributesForAtomUpdate
          # Should this be moved to this project instead of living in entities?
          inputs Foobara::Command::EntityHelpers.type_declaration_for_record_atom_update(entity_class)
          result entity_class # seems like we should just use nil?

          def execute
            update_record

            record
          end

          attr_accessor :record

          def load_records
            self.record = entity_class.load(id)
          end

          def update_record
            inputs.each_pair do |attribute_name, value|
              record.write_attribute(attribute_name, value)
            end
          end
        end
      end

      def create_create_command(entity_class)
        command_class = Class.new(Foobara::Command)

        domain = entity_class.domain

        # TODO: make domain and domain_module the same thing to simplify some concepts
        domain_module = if domain.global?
                          Object
                        else
                          domain.mod
                        end

        domain_module.const_set("Create#{entity_class.entity_name}", command_class)

        command_class.class_eval do
          define_method :entity_class do
            entity_class
          end

          # TODO: does this work with User instead of :User ?
          # We can't come up with a cleaner way to do this?
          # TODO: we should be allowed to just pass the type instead of transforming it to declaration_data
          inputs entity_class.attributes_type.declaration_data
          result entity_class

          def execute
            create_record

            record
          end

          attr_accessor :record

          def create_record
            self.record = entity_class.create(inputs)
          end
        end
      end
    end
  end
end
