require "test_helper"

class KitsControllerTest < ActionDispatch::IntegrationTest
  # -- index --

  test "should get index" do
    get root_url

    assert_response :success
  end

  test "index with tab=wishlist" do
    get root_url, params: { tab: "wishlist" }

    assert_response :success
  end

  test "index with grade filter" do
    get root_url, params: { grade: "HG" }

    assert_response :success
  end

  test "index with search param" do
    get root_url, params: { search: "Gundam" }

    assert_response :success
  end

  # -- pick --

  test "should get pick" do
    get pick_url

    assert_response :success
  end

  test "pick without roll param shows no result" do
    get pick_url

    assert_select "h2", count: 0
  end

  test "pick with roll picks an unbuilt kit" do
    get pick_url, params: { roll: "1" }

    assert_response :success
    assert_select "h2"
  end

  test "pick with roll and grade filter restricts selection" do
    # RG is not in fixtures, so only this kit can be picked
    Kit.create!(title: "RG Aile Strike", status: "unbuilt", grade: "Real Grade")

    get pick_url, params: { roll: "1", grade: "RG" }

    assert_select "h2", text: /RG Aile Strike/
  end

  test "pick with roll and no matching kits shows empty state" do
    get pick_url, params: { roll: "1", brand: "Nobody Makes This Brand" }

    assert_response :success
    assert_select "h2", count: 0
  end
end
