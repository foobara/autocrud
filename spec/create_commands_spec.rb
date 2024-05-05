RSpec.describe Foobara::Autocrud::CreateCommands do
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

  after do
    Foobara.reset_alls
    remove_automatically_created_constants
  end

  describe "#run" do
    context "when entities exist" do
      context "when creating crud commands" do
        let(:user_class) do
          review = review_class

          Foobara::GlobalDomain.foobara_register_entity(:User) do
            id :integer
            first_name :string
            last_name :string
            reviews [review], default: []
          end
        end
        let(:command) { described_class.new(inputs) }
        let(:outcome) { command.run }
        let(:result) { outcome.result }
        let(:inputs) { { entity_class: User, commands: [:create] } }

        let(:review_class) do
          Foobara::GlobalDomain.foobara_register_entity(
            :Review,
            id: :integer,
            rating: { type: :integer, required: true },
            thoughts: :string
          )
        end

        before do
          user_class
        end

        context "when auto-creating Create command" do
          it "creates a CreateUser command" do
            expect(outcome).to be_success

            expect(result).to eq([CreateUser])
            expect(CreateUser).to be < Foobara::Command
          end
        end
      end
    end
  end
end
