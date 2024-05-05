RSpec.describe Foobara::Autocrud::CreateType do
  let(:base) do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
    Foobara::Persistence.default_base
  end

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
    context "when creating an entity" do
      context "when autocreating crud commands" do
        let(:user_class) do
          review = review_class

          Foobara::Autocrud::CreateEntity.run!(name: :User, domain:, attributes_declaration: proc {
            id :integer
            first_name :string
            last_name :string
            reviews [review], default: []
          })
        end

        let(:review_class) do
          Foobara::Autocrud::CreateEntity.run!(name: :Review, domain:, attributes_declaration: {
                                                 id: :integer,
                                                 rating: { type: :integer, required: true },
                                                 thoughts: :string
                                               })
        end

        let(:domain) { "SomeOrg::SomeDomain" }

        before do
          user_class
        end

        context "when autocreating Create command" do
          it "creates a CreateUser command" do
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

              expect(user).to be_a(User)
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
                  context: { criteria: 1, data_path: "",
                             entity_class: "SomeOrg::SomeDomain::User" },
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

        context "when autocreating QueryUser command" do
          it "Creates a QueryUser command" do
            expect(SomeOrg::SomeDomain::QueryUser).to be < Foobara::Command

            user1 = SomeOrg::SomeDomain::CreateUser.run!(first_name: "same_first", last_name: "different")
            user2 = SomeOrg::SomeDomain::CreateUser.run!(first_name: "same_first", last_name: "last")

            users = SomeOrg::SomeDomain::QueryUser.run!(first_name: "same_first")

            expect(users).to contain_exactly(user1, user2)
          end
        end

        context "when autocreating AppendToUserReviews command" do
          it "Creates a AppendToUserReviews command that works with existing records to append" do
            expect(SomeOrg::SomeDomain::AppendToUserReviews).to be < Foobara::Command

            review = SomeOrg::SomeDomain::CreateReview.run!(rating: 1, thoughts: "t")
            new_review = SomeOrg::SomeDomain::CreateReview.run!(rating: 2, thoughts: "t2")

            user = SomeOrg::SomeDomain::CreateUser.run!(first_name: "f", last_name: "l", reviews: [review])

            expect(user.reviews.size).to be(1)

            outcome = SomeOrg::SomeDomain::AppendToUserReviews.run(user: user.id, element_to_append: new_review)

            expect(outcome).to be_success
            expect(outcome.result).to eq(new_review)

            SomeOrg::SomeDomain::User.transaction do
              user = SomeOrg::SomeDomain::FindUser.run!(id: user.id)

              expect(user.reviews.size).to be(2)

              first_review = user.reviews.first
              last_review = user.reviews.last

              expect(first_review.rating).to be(1)
              expect(last_review.rating).to be(2)
            end
          end

          context "when creating a new record through appending" do
            it "creates a new record" do
              review = SomeOrg::SomeDomain::CreateReview.run!(rating: 1, thoughts: "t")
              new_review = { rating: 2, thoughts: "t2" }

              user = SomeOrg::SomeDomain::CreateUser.run!(first_name: "f", last_name: "l", reviews: [review])

              expect(user.reviews.size).to be(1)

              outcome = SomeOrg::SomeDomain::AppendToUserReviews.run(user: user.id, element_to_append: new_review)

              expect(outcome).to be_success

              SomeOrg::SomeDomain::User.transaction do
                user = SomeOrg::SomeDomain::FindUser.run!(id: user.id)

                expect(user.reviews.size).to be(2)

                first_review = user.reviews.first
                last_review = user.reviews.last

                expect(first_review.rating).to be(1)
                expect(first_review.thoughts).to eq("t")
                expect(last_review.rating).to be(2)
                expect(last_review.thoughts).to eq("t2")
              end
            end
          end
        end

        context "when autocreating RemoveFromUserReviews command" do
          it "Creates a RemoveFromUserReviews command that works with existing records to append" do
            expect(SomeOrg::SomeDomain::RemoveFromUserReviews).to be < Foobara::Command

            review1 = SomeOrg::SomeDomain::CreateReview.run!(rating: 1, thoughts: "t")
            review2 = SomeOrg::SomeDomain::CreateReview.run!(rating: 2, thoughts: "t2")

            user = SomeOrg::SomeDomain::CreateUser.run!(first_name: "f", last_name: "l", reviews: [review1, review2])

            expect(user.reviews.size).to be(2)

            outcome = SomeOrg::SomeDomain::RemoveFromUserReviews.run(user: user.id, element_to_remove: review1)

            expect(outcome).to be_success
            expect(outcome.result).to eq(review1)

            SomeOrg::SomeDomain::User.transaction do
              user = SomeOrg::SomeDomain::FindUser.run!(id: user.id)

              expect(user.reviews.size).to be(1)

              review = user.reviews.first

              expect(review).to eq(review2)
            end
          end

          context "when element is not in the collection" do
            it "is not success" do
              review1 = SomeOrg::SomeDomain::CreateReview.run!(rating: 1, thoughts: "t")
              review2 = SomeOrg::SomeDomain::CreateReview.run!(rating: 2, thoughts: "t2")

              user = SomeOrg::SomeDomain::CreateUser.run!(first_name: "f", last_name: "l", reviews: [review1])

              outcome = SomeOrg::SomeDomain::RemoveFromUserReviews.run(user: user.id, element_to_remove: review2)

              expect(outcome).to_not be_success
              expect(outcome.errors_hash).to eq(
                "runtime.element_not_in_collection" => {
                  category: :runtime,
                  context: {},
                  is_fatal: true,
                  key: "runtime.element_not_in_collection",
                  message: "Element not in collection so can't remove it.",
                  path: [],
                  runtime_path: [],
                  symbol: :element_not_in_collection
                }
              )
            end
          end
        end
      end
    end
  end
end
