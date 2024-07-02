require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @join_code = accounts(:signal).join_code
  end

  test "new" do
    get join_url(@join_code)
    assert_response :success
  end

  test "new does not allow a signed in user" do
    sign_in :david

    get join_url(@join_code)
    assert_redirected_to root_url
  end

  test "new requires a join code" do
    get join_url("not")
    assert_response :not_found
  end

  test "create" do
    assert_difference -> { User.count }, 1 do
      post join_url(@join_code), params: { user: { name: "New Person", email_address: "new@37signals.com", password: "secret123456" } }
    end

    assert_redirected_to root_url

    user = User.last
    assert_equal user.id, Session.find_by(token: parsed_cookies.signed[:session_token]).user.id
  end

  test "edit is accessable to the current user" do
    sign_in :david

    get edit_user_url(users(:david))
    assert_response :success

    get edit_user_url(users(:kevin))
    assert_response :forbidden
  end

  test "update" do
    sign_in :david
    assert users(:david).administrator?

    put user_url(users(:kevin)), params: { user: { role: "administrator" } }

    assert_redirected_to users_url
    assert users(:kevin).reload.administrator?
  end

  test "update allows non-admin users to change their own settings" do
    sign_in :kevin
    assert_not users(:kevin).administrator?

    put user_url(users(:kevin)), params: { user: { name: "Bob" } }

    assert_redirected_to users_url
    assert_equal "Bob", users(:kevin).reload.name
  end

  test "update does not allow non-admins to change roles" do
    sign_in :kevin
    assert_not users(:kevin).administrator?

    put user_url(users(:kevin)), params: { user: { role: "administrator" } }

    assert_redirected_to users_url
    assert_not users(:kevin).reload.administrator?
  end

  test "update does not allow non-admins to change other user's settings" do
    sign_in :kevin
    assert_not users(:kevin).administrator?

    put user_url(users(:david)), params: { user: { name: "Bob" } }

    assert_response :forbidden
    assert_equal "David", users(:david).reload.name
  end

  test "destroy" do
    sign_in :david

    assert_difference -> { User.active.count }, -1 do
      delete user_url(users(:kevin))
    end

    assert_redirected_to users_url
    assert_nil User.active.find_by(id: users(:kevin).id)
  end

  test "non-admins cannot perform actions" do
    sign_in :kevin

    delete user_url(users(:david))
    assert_response :forbidden
  end

  test "creating a new user with an existing email address will redirect to login screen" do
    assert_no_difference -> { User.count } do
      post join_url(@join_code), params: { user: { name: "Another David", email_address: users(:david).email_address, password: "secret123456" } }
    end

    assert_redirected_to new_session_url(email_address: users(:david).email_address)
  end
end
