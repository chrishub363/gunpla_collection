require "test_helper"

class KitsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get kits_index_url

    assert_response :success
  end

  test "should get pick" do
    get kits_pick_url

    assert_response :success
  end
end
