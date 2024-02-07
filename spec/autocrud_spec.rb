RSpec.describe Foobara::Autocrud do
  before do
    described_class.base = base
  end

  def remove_automatically_created_constants
    %i[
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

  let(:base) do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
    Foobara::Persistence.default_base
  end

  describe ".create_type" do
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
        described_class.create_type(type_declaration:, type_symbol:, domain:)

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
            Foobara::Autocrud::PersistedType.transaction do
              described_class.create_type(type_declaration:, domain:)
            end

            expect(SomeOrg::SomeDomain::User).to be < Foobara::Entity
          end
        end
      end

      context "when autocreating crud commands" do
        let(:user_class) do
          review = review_class

          described_class.create_entity(:User, domain:) do
            id :integer
            first_name :string
            last_name :string
            reviews [review], default: []
          end
        end

        let(:review_class) do
          described_class.create_entity(:Review, domain: "SomeOrg::SomeDomain") do
            id :integer
            rating :integer, :required
            thoughts :string
          end
        end

        let(:domain) { "SomeOrg::SomeDomain" }

        before do
          user_class
        end

        context "when autocreating Create command" do
          it "Creates a CreateUser command" do
            expect(SomeOrg::SomeDomain::CreateUser).to be < Foobara::Command

            outcome = SomeOrg::SomeDomain::CreateUser.run(first_name: "f", last_name: "l")

            expect(outcome).to be_success

            user = outcome.result

            expect(user).to be_a(SomeOrg::SomeDomain::User)
            expect(user.first_name).to eq("f")
            expect(user.last_name).to eq("l")
            expect(user.id).to be_a(Integer)
          end

          context "without a domain" do
            let(:domain) { nil }

            it "Creates a CreateUser command" do
              expect(CreateUser).to be < Foobara::Command

              outcome = CreateUser.run(first_name: "f", last_name: "l")

              expect(outcome).to be_success

              user = outcome.result

              # TODO: just put this in the global namespace if not using domains?
              expect(user).to be_a(Foobara::GlobalDomain::User)
              expect(user.first_name).to eq("f")
              expect(user.last_name).to eq("l")
              expect(user.id).to be_a(Integer)
            end
          end
        end

        context "when autocreating HardDelete command" do
          it "Creates a HardDeleteUser command" do
            expect(SomeOrg::SomeDomain::HardDeleteUser).to be < Foobara::Command

            SomeOrg::SomeDomain::User.transaction do
              user = SomeOrg::SomeDomain::CreateUser.run!(first_name: "f", last_name: "l")

              outcome = SomeOrg::SomeDomain::HardDeleteUser.run(user:)

              expect(outcome).to be_success
              user = outcome.result

              expect(user).to be_a(SomeOrg::SomeDomain::User)
              expect(user).to be_hard_deleted
            end
          end
        end

        context "when autocreating UpdateAtom command" do
          it "Creates a UpdateUserAtom command" do
            expect(SomeOrg::SomeDomain::UpdateUserAtom).to be < Foobara::Command

            user = SomeOrg::SomeDomain::CreateUser.run!(first_name: "f", last_name: "l")

            outcome = SomeOrg::SomeDomain::UpdateUserAtom.run(first_name: "ff", id: user.id)

            expect(outcome).to be_success
            user = outcome.result

            expect(user.first_name).to eq("ff")
            expect(user.last_name).to eq("l")
            expect(user.id).to be_a(Integer)
          end
        end

        context "when autocreating UpdateAggregate command" do
          it "Creates a UpdateUserAggregate command" do
            expect(SomeOrg::SomeDomain::UpdateUserAggregate).to be < Foobara::Command

            review = SomeOrg::SomeDomain::CreateReview.run!(rating: 1, thoughts: "t")
            user = SomeOrg::SomeDomain::CreateUser.run!(first_name: "f", last_name: "l", reviews: [review])

            outcome = SomeOrg::SomeDomain::UpdateUserAggregate.run(first_name: "ff", id: user.id)

            expect(outcome).to be_success
            user = outcome.result

            expect(user.first_name).to eq("ff")
            expect(user.last_name).to eq("l")
            expect(user.id).to be_a(Integer)
          end
        end

        context "when autocreating FindUser command" do
          it "Creates a FindUser command" do
            expect(SomeOrg::SomeDomain::FindUser).to be < Foobara::Command

            review = SomeOrg::SomeDomain::CreateReview.run!(rating: 1, thoughts: "t")
            user = SomeOrg::SomeDomain::CreateUser.run!(first_name: "f", last_name: "l", reviews: [review])

            outcome = SomeOrg::SomeDomain::FindUser.run(id: user.id)

            expect(outcome).to be_success
            user = outcome.result

            expect(user.first_name).to eq("f")
            expect(user.last_name).to eq("l")
            expect(user.id).to be_a(Integer)
            review = user.reviews.first

            review = SomeOrg::SomeDomain::FindReview.run!(id: review.id)

            expect(review.rating).to be(1)
            expect(review.thoughts).to eq("t")
          end

          context "when user doesn't exist" do
            it "is not success" do
              outcome = SomeOrg::SomeDomain::FindUser.run(id: 1)
              expect(outcome).to_not be_success

              expect(outcome.errors_hash).to eq(
                "runtime.not_found" => {
                  category: :runtime,
                  context: { criteria: 1, data_path: "", entity_class: "SomeOrg::SomeDomain::User" },
                  is_fatal: true,
                  key: "runtime.not_found",
                  message: "Could not find SomeOrg::SomeDomain::User for 1",
                  path: [],
                  runtime_path: [],
                  symbol: :not_found
                }
              )
            end
          end
        end

        context "when autocreating FindUserBy command" do
          it "Creates a FindUserBy command" do
            expect(SomeOrg::SomeDomain::FindUserBy).to be < Foobara::Command

            review = SomeOrg::SomeDomain::CreateReview.run!(rating: 1, thoughts: "t")
            user = SomeOrg::SomeDomain::CreateUser.run!(first_name: "f", last_name: "l", reviews: [review])
            user_id = user.id

            user = SomeOrg::SomeDomain::FindUserBy.run!(id: user_id)
            expect(user.id).to be(user_id)

            user = SomeOrg::SomeDomain::FindUserBy.run!(first_name: "f")
            expect(user.id).to be(user_id)

            user = SomeOrg::SomeDomain::FindUserBy.run!(first_name: "f", last_name: "l")
            expect(user.id).to be(user_id)

            outcome = SomeOrg::SomeDomain::FindUserBy.run(first_name: "bad first name")

            expect(outcome).to_not be_success

            expect(outcome.errors_hash).to eq(
              "runtime.not_found" => {
                category: :runtime,
                context: { criteria: { first_name: "bad first name" },
                           data_path: "",
                           entity_class: "SomeOrg::SomeDomain::User" },
                is_fatal: true,
                key: "runtime.not_found",
                message: "Could not find SomeOrg::SomeDomain::User for {:first_name=>\"bad first name\"}",
                path: [],
                runtime_path: [],
                symbol: :not_found
              }
            )
          end
        end

        context "when autocreating AppendToUserReviews command" do
          it "Creates a AppendToUserReviews command that works with existing records to append", :focus do
            expect(SomeOrg::SomeDomain::AppendToUserReviews).to be < Foobara::Command

            review = SomeOrg::SomeDomain::CreateReview.run!(rating: 1, thoughts: "t")
            new_review = SomeOrg::SomeDomain::CreateReview.run!(rating: 2, thoughts: "t2")

            user = SomeOrg::SomeDomain::CreateUser.run!(first_name: "f", last_name: "l", reviews: [review])

            expect(user.reviews.size).to be(1)

            outcome = SomeOrg::SomeDomain::AppendToUserReviews.run(user: user.id, review: new_review)

            expect(outcome).to be_success
            user = outcome.result

            expect(user.reviews.size).to be(2)

            first_review = user.reviews.first
            last_review = user.reviews.last

            expect(first_review.rating).to be(1)
            expect(last_review.rating).to be(2)
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
              name: "Person",
              model_module: "SomeOrg::SomeDomain"
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
