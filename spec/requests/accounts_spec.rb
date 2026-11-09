require "rails_helper"

RSpec.describe "My account", type: :request do
  let(:user) { create_user }

  it "asks signed-out visitors to sign in" do
    get account_path

    expect(response).to redirect_to(new_session_path)
  end

  it "shows the member's email and plan" do
    sign_in(user)

    get account_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(user.email, "Free", "Upgrade to Premium")
  end

  it "upgrades a Free member to Premium" do
    sign_in(user)

    patch account_path, params: { role: "Premium" }

    expect(response).to redirect_to(account_path)
    expect(flash[:notice]).to eq("You're now on Premium.")
    expect(user.reload).to be_premium
  end

  it "downgrades a Premium member to Free" do
    premium = create_user(email: "premium@example.com", role: "Premium")
    sign_in(premium)

    patch account_path, params: { role: "Free" }

    expect(premium.reload.role).to eq("Free")
  end

  it "rejects a plan that does not exist" do
    sign_in(user)

    patch account_path, params: { role: "Admin" }

    expect(response).to redirect_to(account_path)
    expect(flash[:alert]).to eq("That plan isn't available.")
    expect(user.reload.role).to eq("Free")
  end

  it "rejects a request without a plan" do
    sign_in(user)

    patch account_path

    expect(flash[:alert]).to eq("That plan isn't available.")
    expect(user.reload.role).to eq("Free")
  end
end
