RSpec.describe Foobara::Autocrud::CreateType do
  let(:command) { described_class.new(inputs) }
  let(:base) do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
    Foobara::Persistence.default_base
  end
  let(:inputs) do
    {
      type_declaration:,
      domain:,
      type_symbol:
    }
  end
  let(:type_symbol) { nil }
  let(:domain) { nil }
  let(:outcome) { command.run }
  let(:result) { outcome.result }
  let(:errors) { outcome.errors }

  before do
    Foobara::Autocrud.base = base
  end

  def remove_automatically_created_constants
    %i[
      RemoveFromUserReviews
      AppendToUserReviews
      QueryUser
      FindUserBy
      FindUser
      HardDeleteUser
      UpdateUserAggregate
      UpdateUserAtom
      CreateUser
      QueryReview
      FindReviewBy
      FindReview
      HardDeleteReview
      UpdateReviewAggregate
      UpdateReviewAtom
      CreateReview
      User
      Review
      SomeOrg
      CreateUser
      UpdateUserAtom
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

  describe "#run" do
    context "when creating a non-model type" do
      let(:type_symbol) { :whole_number }
      let(:type_declaration) do
        {
          type: :integer,
          min: 1
        }
      end
      let(:domain) { "SomeOrg::SomeDomain" }

      it "creates and registers the type and creates a persisted type record" do
        expect(outcome).to be_success

        persisted_type = Foobara::Autocrud::PersistedType.transaction do
          Foobara::Autocrud::PersistedType.all.to_a
        end
        expect(persisted_type.size).to eq(1)
        persisted_type = persisted_type.first
        expect(persisted_type.type_declaration).to eq(type_declaration)
        expect(persisted_type.full_domain_name).to eq(domain)
        expect(persisted_type.type_symbol).to eq(type_symbol)

        type = SomeOrg::SomeDomain.foobara_lookup_type!(:whole_number)
        expect(type.declaration_data).to eq(type_declaration)
      end
    end

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
          model_module: Foobara::Domain.create("SomeOrg::SomeDomain")
        }
      end

      context "when no base set" do
        let(:base) { nil }

        it "creates a persisted type record and an entity class" do
          expect {
            outcome
          }.to raise_error(Foobara::Persistence::NoTableOrCrudDriverError)
        end
      end

      context "when base set" do
        it "creates a persisted type record and an entity class" do
          expect(outcome).to be_success
          expect(SomeOrg::SomeDomain::User).to be < Foobara::Entity
        end

        context "when passing in domain name" do
          let(:domain) { "SomeOrg::SomeDomain" }
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
              model_module: domain
            }
          end

          it "creates a persisted type record and an entity class" do
            expect(outcome).to be_success

            expect(SomeOrg::SomeDomain::User).to be < Foobara::Entity
          end
        end
      end

      context "when autocreated crud commands without domain argument" do
        let(:role_type_declaration) do
          {
            type: :entity,
            name: "Role",
            model_module: "SomeOrg::SomeDomain",
            attributes_declaration: {
              id: :integer,
              name: { type: :string, required: true }
            },
            primary_key: :id
          }
        end

        let(:user_type_declaration) do
          {
            type: :entity,
            name: "User",
            attributes_declaration: {
              id: :integer,
              name: :string,
              email: :email,
              role: role_class
            },
            primary_key: :id,
            model_module: "SomeOrg::SomeDomain"
          }
        end

        let(:user_class) do
          described_class.run!(type_declaration: user_type_declaration)
        end

        let(:role_class) do
          described_class.run!(type_declaration: role_type_declaration)
        end

        let(:organization) do
          stub_module("SomeOrg") { foobara_organization! }
        end

        let(:domain) do
          stub_module("SomeOrg::SomeDomain") { foobara_domain! }
        end

        before do
          organization
          domain
          role_class
          user_class
        end

        it "creates commands in the proper domain" do
          expect(SomeOrg::SomeDomain::CreateUser).to be < Foobara::Command
          expect(SomeOrg::SomeDomain::CreateRole).to be < Foobara::Command
        end
      end
    end
  end
end
