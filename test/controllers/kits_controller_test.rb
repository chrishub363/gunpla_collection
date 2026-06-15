require "test_helper"

class KitsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url

    assert_response :success
  end

  test "should get pick" do
    get pick_url

    assert_response :success
  end
end
