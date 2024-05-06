module Foobara
  module Autocrud
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
    # TODO: consider moving helper methods here into their own commands?
    class CreateCommands < Foobara::Command
      ALLOWED_COMMANDS = %i[
        create
        update_atom
        update_aggregate
        hard_delete
        find
        find_by
        query
        query_all
        append
      ].freeze

      inputs do
        # TODO: give a way to specify union types? We would like an array of one_of: or one_of: or :all here.
        # But no way to specify that.
        # TODO: append and remove commands should be split up
        # TODO: append and remove commands should be able to be narrowed down by association but inputs currently
        # just supports creating all append/remove commands for all associations.
        commands :duck
        # TODO: give a way to specify subclass of Foobara::Entity here
        entity_class Class
      end

      def execute
        create_commands

        created_commands
      end

      attr_writer :created_commands

      def create_commands
        commands_to_create.each do |command_symbol|
          method = if command_symbol == :append
                     "create_append_commands"
                   else
                     "create_#{command_symbol}_command"
                   end

          created_commands << send(method)
        end

        self.created_commands = created_commands.flatten
      end

      def created_commands
        @created_commands ||= []
      end

      def commands_to_create
        @commands_to_create ||= if commands == :all || commands.nil?
                                  ALLOWED_COMMANDS
                                else
                                  Util.array(commands)
                                end
      end

      # rubocop:disable Lint/NestedMethodDefinition
      def create_update_atom_command
        entity_class = self.entity_class
        domain = entity_class.domain
        command_name = [*domain.scoped_full_path, "Update#{entity_class.entity_type.scoped_short_name}Atom"].join("::")

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

      def create_update_aggregate_command
        entity_class = self.entity_class
        domain = entity_class.domain
        command_name = [*domain.scoped_full_path,
                        "Update#{entity_class.entity_type.scoped_short_name}Aggregate"].join("::")

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

      def create_create_command
        entity_class = self.entity_class
        domain = entity_class.domain
        command_name = [*domain.scoped_full_path, "Create#{entity_class.entity_type.scoped_short_name}"].join("::")

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

      def create_hard_delete_command
        entity_class = self.entity_class
        domain = entity_class.domain
        command_name = [*domain.scoped_full_path, "HardDelete#{entity_class.entity_type.scoped_short_name}"].join("::")

        Util.make_class(command_name, Foobara::Command) do
          singleton_class.define_method :record_method_name do
            @record_method_name ||= Util.underscore(entity_class.entity_type.scoped_short_name)
          end

          foobara_delegate :record_method_name, to: :class

          def record
            send(record_method_name)
          end

          # TODO: does this work with User instead of :User ?
          # We can't come up with a cleaner way to do this?
          # TODO: make this work with entity classes!! no reason not to and very inconvenient
          inputs Util.underscore(entity_class.entity_type.scoped_short_name) => entity_class
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

      def create_find_command
        entity_class = self.entity_class
        domain = entity_class.domain
        command_name = [*domain.scoped_full_path, "Find#{entity_class.entity_type.scoped_short_name}"].join("::")

        Util.make_class(command_name, Foobara::Command) do
          define_method :entity_class do
            entity_class
          end

          inputs entity_class.primary_key_attribute => entity_class.primary_key_type
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

      def create_find_by_command
        entity_class = self.entity_class
        domain = entity_class.domain
        command_name = [*domain.scoped_full_path, "Find#{entity_class.entity_type.scoped_short_name}By"].join("::")

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

      def create_query_command
        entity_class = self.entity_class
        domain = entity_class.domain
        command_name = [*domain.scoped_full_path, "Query#{entity_class.entity_type.scoped_short_name}"].join("::")

        Util.make_class(command_name, Foobara::Command) do
          define_method :entity_class do
            entity_class
          end

          # TODO: can't use attributes: :attributes but should be able to.
          inputs Command::EntityHelpers.type_declaration_for_find_by(entity_class)
          result [entity_class]

          def execute
            run_query

            records
          end

          attr_accessor :records

          def run_query
            self.records = entity_class.find_many_by(inputs)
          end
        end
      end

      def create_query_all_command
        entity_class = self.entity_class
        domain = entity_class.domain
        command_name = [*domain.scoped_full_path, "QueryAll#{entity_class.entity_type.scoped_short_name}"].join("::")

        Util.make_class(command_name, Foobara::Command) do
          define_method :entity_class do
            entity_class
          end

          # TODO: can't use attributes: :attributes but should be able to.
          inputs({})
          result [entity_class]

          def execute
            run_query

            records
          end

          attr_accessor :records

          def run_query
            self.records = entity_class.all
          end
        end
      end

      def create_append_commands
        commands = []

        entity_class.associations.each_pair do |data_path, type|
          data_path = DataPath.parse(data_path)
          if data_path.simple_collection?
            path = data_path.path[0..-2]
            commands << create_append_command(path, type)
            commands << create_remove_command(path, type)
          end
        end

        commands
      end

      def create_append_command(path_to_collection, association_type)
        entity_class = self.entity_class
        start = path_to_collection.size - 2
        start = 0 if start < 0
        collection_name = path_to_collection[start..start + 1]
        collection_name = collection_name.map { |part| Util.classify(part) }.join

        domain = entity_class.domain
        # TODO: group these by entity name?
        command_name = [*domain.scoped_full_path,
                        "AppendTo#{entity_class.entity_type.scoped_short_name}#{collection_name}"].join("::")

        entity_input_name = Util.underscore_sym(entity_class.entity_type.scoped_short_name)

        Util.make_class(command_name, Foobara::Command) do
          define_method :path_to_collection do
            path_to_collection
          end

          define_method :entity_input_name do
            entity_input_name
          end

          # TODO: can't use attributes: :attributes but should be able to.
          # Allow a hash to create these these things?
          inputs type: :attributes,
                 element_type_declarations: {
                   entity_input_name => entity_class,
                   element_to_append: association_type.target_class
                 },
                 required: [entity_input_name, :element_to_append]

          result association_type.target_class

          to_load entity_input_name

          def execute
            append_record_to_collection

            element_to_append
          end

          attr_accessor :new_collection

          def append_record_to_collection
            collection = DataPath.value_at(path_to_collection, record)

            self.new_collection = [*collection, element_to_append]

            DataPath.set_value_at(record, new_collection, path_to_collection)
          end

          def record
            inputs[entity_input_name]
          end
        end
      end

      def create_remove_command(path_to_collection, association_type)
        entity_class = self.entity_class
        start = path_to_collection.size - 2
        start = 0 if start < 0
        collection_name = path_to_collection[start..start + 1]
        collection_name = collection_name.map { |part| Util.classify(part) }.join

        domain = entity_class.domain
        # TODO: group these by entity name?
        command_name = [*domain.scoped_full_path,
                        "RemoveFrom#{entity_class.entity_type.scoped_short_name}#{collection_name}"].join("::")

        entity_input_name = Util.underscore_sym(entity_class.entity_type.scoped_short_name)

        Util.make_class(command_name, Foobara::Command) do
          Util.make_class("#{command_name}::ElementNotInCollectionError", Foobara::RuntimeError) do
            class << self
              # TODO: make this the default
              def context_type_declaration
                {}
              end
            end
          end

          define_method :path_to_collection do
            path_to_collection
          end

          define_method :entity_input_name do
            entity_input_name
          end

          # TODO: can't use attributes: :attributes but should be able to.
          # Allow a hash to create these these things?
          inputs type: :attributes,
                 element_type_declarations: {
                   entity_input_name => entity_class,
                   element_to_remove: association_type.target_class
                 },
                 required: [entity_input_name, :element_to_remove]

          result association_type.target_class

          to_load entity_input_name

          def execute
            remove_record_from_collection

            element_to_remove
          end

          attr_accessor :new_collection

          def remove_record_from_collection
            collection = DataPath.value_at(path_to_collection, record)

            self.new_collection = collection.reject { |element| element == element_to_remove }

            if collection == new_collection
              add_runtime_error(
                self.class::ElementNotInCollectionError.new(
                  message: "Element not in collection so can't remove it.",
                  context: {} # TODO: make this the default
                )
              )
            end

            DataPath.set_value_at(record, new_collection, path_to_collection)
          end

          def record
            inputs[entity_input_name]
          end
        end
      end
      # rubocop:enable Lint/NestedMethodDefinition
    end
  end
end
