require "rails_helper"

RSpec.describe User do
  describe "#change_role!" do
    let(:user) { create_user }

    it "switches the member to the requested plan" do
      user.change_role!("Premium")

      expect(user.reload).to be_premium
    end

    it "refuses an unknown plan and keeps the current one" do
      expect { user.change_role!("Bogus") }.to raise_error(ActiveRecord::RecordInvalid)
      expect(user.reload.role).to eq("Free")
    end
  end
end
