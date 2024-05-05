require "foobara/all"

module Foobara
  module Autocrud
    foobara_domain!

    class << self
      attr_accessor :base

      def install!
        raise NoBaseSetError unless base

        base.register_entity_class(PersistedType, table_name: :persisted_types)

        PersistedType.transaction do
          PersistedType.all do |persisted_type|
            BuildType.run!(
              type_declaration: persisted_type.type_declaration,
              type_symbol: persisted_type.type_symbol,
              domain: persisted_type.full_domain_name
            )
          end
        end
      end
    end
  end
end
