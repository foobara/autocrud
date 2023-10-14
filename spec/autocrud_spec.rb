RSpec.describe Foobara::Autocrud do
  describe ".create_type" do
    context "when creating an entity" do
      before do
        if base
          described_class.base = base
        end
      end

      let(:type_declaration) do
        {
          type: :entity,
          attributes_declaration: {
            first_name: :string,
            last_name: :string,
            id: :integer
          },
          primary_key: :id,
          name: "User",
          model_module: Foobara::Domain.create("SomeOrg::SomeDomain").mod
        }
      end

      context "when no base set" do
        let(:base) { nil }

        it "creates a persisted type record and an entity class" do
          expect {
            described_class.create_type(type_declaration:)
          }.to raise_error(Foobara::Autocrud::NoBaseSetError)
        end
      end

      context "when base set" do
        let(:base) do
          Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
          Foobara::Persistence.default_base
        end

        after do
          Foobara.reset_alls
        end

        it "creates a persisted type record and an entity class" do
          Foobara::Autocrud::PersistedType.transaction do
            described_class.create_type(type_declaration:)
          end
          expect(SomeOrg::SomeDomain::User).to be < Foobara::Entity
          described_class.install!
        end
      end
    end
  end
end
