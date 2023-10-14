RSpec.describe Foobara::Autocrud do
  before do
    described_class.base = base
  end

  after do
    Foobara.reset_alls
    Foobara::Autocrud::PersistedType.instance_variable_set("@entity_base", nil)
    if Object.constants.include?(:SomeOrg)
      Object.send(:remove_const, :SomeOrg)
    end
  end

  let(:base) do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
    Foobara::Persistence.default_base
  end

  describe ".create_type" do
    context "when creating an entity" do
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
        it "creates a persisted type record and an entity class" do
          Foobara::Autocrud::PersistedType.transaction do
            described_class.create_type(type_declaration:)
          end
          expect(SomeOrg::SomeDomain::User).to be < Foobara::Entity
          described_class.install!
        end

        context "when passing in domain name" do
          let(:type_declaration) do
            {
              type: :entity,
              attributes_declaration: {
                first_name: :string,
                last_name: :string,
                id: :integer
              },
              primary_key: :id,
              name: "User"
            }
          end

          it "creates a persisted type record and an entity class" do
            Foobara::Autocrud::PersistedType.transaction do
              described_class.create_type(type_declaration:, domain: "SomeOrg::SomeDomain")
            end
            expect(SomeOrg::SomeDomain::User).to be < Foobara::Entity
          end
        end
      end
    end
  end

  describe ".install!" do
    context "when a type is persisted" do
      before do
        Foobara::Autocrud::PersistedType.transaction do
          Foobara::Autocrud::PersistedType.create(
            type_declaration: {
              type: :entity,
              attributes_declaration: {
                first_name: :string,
                last_name: :string,
                id: :integer
              },
              primary_key: :id,
              name: "Person"
            },
            type_symbol: "Person",
            full_domain_name: "SomeOrg::SomeDomain"
          )
        end
      end

      it "loads the type" do
        described_class.install!
        expect(SomeOrg::SomeDomain::Person).to be < Foobara::Entity
      end
    end
  end
end
