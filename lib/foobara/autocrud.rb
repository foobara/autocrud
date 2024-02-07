require "foobara/all"

module Foobara
  module Autocrud
    foobara_domain!

    Util.require_directory(__dir__)

    class << self
      attr_accessor :base

      def create_type(type_declaration:, type_symbol: nil, domain: nil)
        raise NoBaseSetError unless base

        type = load_type(type_declaration:, type_symbol:, domain:)

        domain = Domain.to_domain(type)

        PersistedType.transaction(mode: :use_existing) do
          PersistedType.create(
            Util.remove_blank(
              type_declaration: type.declaration_data,
              type_symbol: type.type_symbol,
              full_domain_name: domain.scoped_full_name
            )
          )
        end

        type
      end

      def create_entity(name, domain: nil, &)
        attributes_type_declaration = Foobara::TypeDeclarations::Dsl::Attributes.to_declaration(&)

        domain = find_or_create_domain(domain)

        create_type(
          type_declaration: {
            type: :entity,
            attributes_declaration: attributes_type_declaration,
            name:,
            primary_key: attributes_type_declaration[:element_type_declarations].keys.first,
            model_module: domain
          }
        ).target_class
      end

      def load_type(type_declaration:, type_symbol: nil, domain: GlobalDomain)
        domain = find_or_create_domain(domain)

        type = domain.foobara_type_from_declaration(type_declaration)

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
        # FindUser
        # FindUserBy
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
        create_update_atom_command(entity_class)
        create_update_aggregate_command(entity_class)
        create_hard_delete_command(entity_class)
        create_find_command(entity_class)
        create_find_by_command(entity_class)
      end

      def create_update_atom_command(entity_class)
        domain = entity_class.domain
        command_name = [*domain.scoped_full_path, "Update#{entity_class.entity_name}Atom"].join("::")

        Util.make_class command_name, Foobara::Command do
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

      def create_update_aggregate_command(entity_class)
        domain = entity_class.domain
        command_name = [*domain.scoped_full_path, "Update#{entity_class.entity_name}Aggregate"].join("::")

        Util.make_class command_name, Foobara::Command do
          define_method :entity_class do
            entity_class
          end

          # TODO: does this work with User instead of :User ?
          # We can't come up with a cleaner way to do this?
          inputs Foobara::Command::EntityHelpers.type_declaration_for_record_aggregate_update(entity_class)
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
            Foobara::Command::EntityHelpers.update_aggregate(record, inputs)
          end
        end
      end

      def create_create_command(entity_class)
        domain = entity_class.domain
        command_name = [*domain.scoped_full_path, "Create#{entity_class.entity_name}"].join("::")

        Util.make_class(command_name, Foobara::Command) do
          define_method :entity_class do
            entity_class
          end

          # TODO: does this work with User instead of :User ?
          # We can't come up with a cleaner way to do this?
          # TODO: we should be allowed to just pass the type instead of transforming it to declaration_data
          inputs entity_class.attributes_type
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

      def create_hard_delete_command(entity_class)
        domain = entity_class.domain
        command_name = [*domain.scoped_full_path, "HardDelete#{entity_class.entity_name}"].join("::")

        Util.make_class(command_name, Foobara::Command) do
          singleton_class.define_method :record_method_name do
            @record_method_name ||= Util.underscore(entity_class.entity_name)
          end

          foobara_delegate :record_method_name, to: :class

          def record
            send(record_method_name)
          end

          # TODO: does this work with User instead of :User ?
          # We can't come up with a cleaner way to do this?
          # TODO: make this work with entity classes!! no reason not to and very inconvenient
          inputs Util.underscore(entity_class.entity_name) => entity_class
          result entity_class

          load_all

          def execute
            delete_record

            record
          end

          def delete_record
            record.hard_delete!
          end
        end
      end

      def create_find_command(entity_class)
        domain = entity_class.domain
        command_name = [*domain.scoped_full_path, "Find#{entity_class.entity_name}"].join("::")

        Util.make_class(command_name, Foobara::Command) do
          define_method :entity_class do
            entity_class
          end

          # TODO: should be able to just use the type for convenience
          inputs entity_class.primary_key_attribute => entity_class.primary_key_type.declaration_data
          result entity_class

          possible_error Entity::NotFoundError

          def execute
            load_record

            record
          end

          attr_accessor :record

          def load_record
            self.record = entity_class.load(record_id)
          rescue Entity::NotFoundError => e
            add_runtime_error e
          end

          def primary_key_attribute
            entity_class.primary_key_attribute
          end

          def record_id
            inputs[primary_key_attribute]
          end
        end
      end

      def create_find_by_command(entity_class)
        domain = entity_class.domain
        command_name = [*domain.scoped_full_path, "Find#{entity_class.entity_name}By"].join("::")

        # we want the attributes with no defaults or required entries.

        Util.make_class(command_name, Foobara::Command) do
          define_method :entity_class do
            entity_class
          end

          # TODO: can't use attributes: :attributes but should be able to.
          inputs Command::EntityHelpers.type_declaration_for_find_by(entity_class)
          result entity_class

          possible_error Entity::NotFoundError

          def execute
            load_record

            record
          end

          attr_accessor :record

          def load_record
            self.record = entity_class.find_by(inputs)

            unless record
              add_runtime_error Entity::NotFoundError.new(inputs, entity_class:)
            end
          end
        end
      end

      private

      def find_or_create_domain(domain)
        Domain.to_domain(domain)
      rescue Domain::NoSuchDomain => e
        if domain.is_a?(::String) || domain.is_a?(::Symbol)
          Domain.create(domain)
        else
          # :nocov:
          raise e
          # :nocov:
        end
      end
    end
  end
end
