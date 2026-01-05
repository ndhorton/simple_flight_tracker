# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'

require_relative '../app'

# TODO: test for signup page
# TODO: test for signin page
# TODO: test account creation
# TODO: test user sign in

class SimpleFlightTrackerTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def admin_session
    { 'rack.session' => { username: 'admin' } }
  end

  def session
    last_request.env['rack.session']
  end

  def test_home_page
    get '/'

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<h3>Please sign in or sign up'
    assert_includes last_response.body, '<ul class="links"'
    assert_includes last_response.body, 'Sign In'
    assert_includes last_response.body, 'Sign Up'
  end

  def test_signup_page
    get '/users/signup'

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<h3>Sign Up</h3>'
    assert_includes last_response.body, '<h4>Please choose a username and password'
    assert_includes last_response.body, '<form'
    assert_includes last_response.body, '<div class="form-field"'
  end

  def test_signin_page
    get '/users/signin'

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<h3>Sign In</h3>'
    assert_includes last_response.body, '<h4>Please enter your username and password'
    assert_includes last_response.body, '<form'
    assert_includes last_response.body, '<div class="form-field"'
  end
end
