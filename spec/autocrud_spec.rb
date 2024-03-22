RSpec.describe Foobara::Autocrud do
  before do
    described_class.base = base
  end

  def remove_automatically_created_constants
    %i[
      SomeOrg
    ].each do |const|
      if Object.constants.include?(const)
        Object.send(:remove_const, const)
      end
    end
  end

  def reset_alls
    Foobara.reset_alls
    Foobara::Autocrud::PersistedType.instance_variable_set("@entity_base", nil)

    remove_automatically_created_constants
  end

  after do
    reset_alls
  end

  let(:base) do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
    Foobara::Persistence.default_base
  end

  describe ".install!" do
    context "when a type is persisted" do
      before do
        Foobara::Autocrud::PersistedType.transaction do
          Foobara::Autocrud::PersistedType.create(persisted_type_attributes)
        end
      end

      let(:persisted_type_attributes) do
        {
          type_declaration: {
            type: :entity,
            attributes_declaration: {
              first_name: :string,
              last_name: :string,
              id: :integer
            },
            primary_key: :id,
            name: "Person",
            model_module: "SomeOrg::SomeDomain"
          },
          type_symbol: "Person",
          full_domain_name: "SomeOrg::SomeDomain"
        }
      end

      it "loads the type" do
        described_class.install!
        expect(SomeOrg::SomeDomain::Person).to be < Foobara::Entity
      end

      context "when it's not an entity or model" do
        let(:persisted_type_attributes) do
          {
            type_declaration: {
              type: :string,
              downcase: true
            },
            type_symbol: :always_downcase,
            full_domain_name: "SomeOrg::SomeDomain"
          }
        end

        it "loads and registers the type" do
          described_class.install!

          type = Foobara.foobara_lookup_type("SomeOrg::SomeDomain::always_downcase")

          expect(type).to be_a(Foobara::Types::Type)

          expect(type.process_value!("FooBar")).to eq("foobar")
        end
      end
    end

    context "when no base set" do
      let(:base) { nil }

      it "raises an error" do
        expect {
          described_class.install!
        }.to raise_error(described_class::NoBaseSetError)
      end
    end
  end
end
