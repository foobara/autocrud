module Foobara
  module Autocrud
    class PersistedType < Entity
      attributes type: :attributes,
                 element_type_declarations: {
                   id: :integer,
                   type_declaration: :duck,
                   type_symbol: :symbol,
                   full_domain_name: :string
                 },
                 required: %i[type_declaration type_symbol]

      primary_key :id
    end
  end
end
