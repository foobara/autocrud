RSpec.describe Foobara::Autocrud do
  describe ".create_type" do
    context "when creating an entity" do
      before do
        Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
      end

      after do
        Foobara.reset_alls
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

      it "creates a persisted type record and an entity class" do
        described_class.create_type(type_declaration:)
        expect(SomeOrg::SomeDomain::User).to be < Foobara::Entity
      end
    end
  end
end
