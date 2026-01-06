# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'rack/test'

require_relative '../app'

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

  def test_create_account
    post '/users/signup', { username: 'test', password: 'testsecret' }

    assert_equal 302, last_response.status
    assert_includes load_user_credentials, 'test'
  end

  def test_create_account_empty_username
    post '/users/signup', { username: '    ', password: 'testsecret' }

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username cannot be blank.'
  end

  def test_create_account_empty_password
    post '/users/signup', { username: 'test', password: '' }

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Password cannot be blank.'
  end

  def test_create_account_existing_username
    post '/users/signup', { username: 'test', password: 'testsecret' }
    assert_equal 302, last_response.status
    assert_includes load_user_credentials, 'test'

    post '/users/signup', { username: 'test', password: 'testsecret' }
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'That username is taken. Please choose another.'
  end

  def test_user_signin
    post '/users/signup', { username: 'test', password: 'testsecret' }
    assert_equal 302, last_response.status
    assert_includes load_user_credentials, 'test'

    post '/users/signin', { username: 'test', password: 'testsecret' }
    assert_equal 302, last_response.status
    assert_equal 'test', session[:username]
    assert_includes last_response['Location'], '/flights'
  end

  def test_user_signin_empty_username
    post '/users/signup', { username: 'test', password: 'testsecret' }
    assert_equal 302, last_response.status
    assert_includes load_user_credentials, 'test'

    post '/users/signin', { username: ' ', password: 'testsecret' }
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username cannot be blank.'
  end

  def test_user_signin_empty_password
    post '/users/signup', { username: 'test', password: 'testsecret' }
    assert_equal 302, last_response.status
    assert_includes load_user_credentials, 'test'

    post '/users/signin', { username: 'test', password: '' }
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Password cannot be blank.'
  end

  def test_user_signin_wrong_password
    post '/users/signup', { username: 'test', password: 'testsecret' }
    assert_equal 302, last_response.status
    assert_includes load_user_credentials, 'test'

    post '/users/signin', { username: 'test', password: 'wrongsecret' }
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username and password do not match.'
  end

  def test_user_signin_nonexistent_username
    post '/users/signin', { username: 'test', password: 'secret' }
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Username and password do not match.'
  end

  def test_flights_page
    get '/flights', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<table class="flights'
    assert_includes last_response.body, 'Airline</th>'
    assert_includes last_response.body, 'Flight Number</th>'
    assert_includes last_response.body, 'Destination</th>'
    assert_includes last_response.body, 'Departure Time</th>'
  end

  def test_flights_page_without_signin
    get '/flights'

    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/'
  end

  def test_new_flight_page
    get '/flights/new', {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<h3>Please enter the flight details'
    assert_includes last_response.body, '<form'
    assert_includes last_response.body, '<label for="airline"'
    assert_includes last_response.body, '<label for="flight-number"'
    assert_includes last_response.body, '<label for="destination"'
    assert_includes last_response.body, '<label>Departure Time'
  end

  def test_new_flight_page_without_signin
    get '/flights/new'

    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/'
  end

  def test_add_new_flight
    parameters = {
      airline: 'Air Tunisia',
      flight_number: 'TU28',
      destination: 'Prague',
      hour: '06',
      minute: '35'
    }

    post '/flights/new', parameters, admin_session

    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/flights'

    get last_response['Location'], {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<td>Air Tunisia</td>'
    assert_includes last_response.body, '<td>TU28</td>'
    assert_includes last_response.body, '<td>Prague</td>'
    assert_includes last_response.body, '<td>06:35</td>'
  end

  def test_add_new_flight_without_signin
    parameters = {
      airline: 'Air Tunisia',
      flight_number: 'TU28',
      destination: 'Prague',
      hour: '06',
      minute: '35'
    }

    post '/flights/new', parameters

    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/'
  end

  def test_add_new_flight_with_empty_airline
    parameters = {
      airline: '',
      flight_number: 'TU28',
      destination: 'Prague',
      hour: '06',
      minute: '35'
    }

    post '/flights/new', parameters, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Airline cannot be blank.'
  end

  def test_add_new_flight_with_empty_flight_number
    parameters = {
      airline: 'Air Tunisia',
      flight_number: '',
      destination: 'Prague',
      hour: '06',
      minute: '35'
    }

    post '/flights/new', parameters, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Flight Number cannot be blank.'
  end

  def test_add_new_flight_with_empty_destination
    parameters = {
      airline: 'Air Tunisia',
      flight_number: 'TU28',
      destination: '',
      hour: '06',
      minute: '35'
    }

    post '/flights/new', parameters, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Destination cannot be blank.'
  end

  def test_add_new_flight_with_invalid_flight_number
    parameters = {
      airline: 'Air Tunisia',
      flight_number: 'TUN1000',
      destination: 'Prague',
      hour: '06',
      minute: '35'
    }

    post '/flights/new', parameters, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Invalid Flight Number.'
  end

  def test_delete_flight
    parameters = {
      airline: 'Air Tunisia',
      flight_number: 'TU28',
      destination: 'Prague',
      hour: '06',
      minute: '35'
    }

    post '/flights/new', parameters, admin_session

    get last_response['Location'], {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<td>Air Tunisia</td>'
    assert_includes last_response.body, '<td>TU28</td>'
    assert_includes last_response.body, '<td>Prague</td>'
    assert_includes last_response.body, '<td>06:35</td>'

    flight = load_user_flights[session[:username]].find do |flight|
      flight[:flight_number] == 'TU28'
    end

    get "/flights/#{flight[:id]}/delete", {}, admin_session

    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/flights'
    assert_equal 'No longer tracking flight TU28.', session[:message]

    get last_response['Location'], {}, admin_session

    assert_equal 200, last_response.status
    refute_includes last_response.body, '<td>Air Tunisia</td>'
    refute_includes last_response.body, '<td>TU28</td>'
    refute_includes last_response.body, '<td>Prague</td>'
    refute_includes last_response.body, '<td>06:35</td>'
  end

  def test_delete_flight_without_signin
    parameters = {
      airline: 'Air Tunisia',
      flight_number: 'TU28',
      destination: 'Prague',
      hour: '06',
      minute: '35'
    }

    post '/flights/new', parameters, admin_session

    get last_response['Location'], {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<td>Air Tunisia</td>'
    assert_includes last_response.body, '<td>TU28</td>'
    assert_includes last_response.body, '<td>Prague</td>'
    assert_includes last_response.body, '<td>06:35</td>'

    flight = load_user_flights[session[:username]].find do |flight|
      flight[:flight_number] == 'TU28'
    end

    get "/flights/#{flight[:id]}/delete", {}, { 'rack.session' => { username: nil } }

    assert_equal 302, last_response.status
    refute_includes last_response['Location'], '/flights'
  end

  def test_user_signout
    post '/users/signup', { username: 'test', password: 'testsecret' }
    assert_equal 302, last_response.status
    assert_includes load_user_credentials, 'test'

    post '/users/signin', { username: 'test', password: 'testsecret' }
    assert_equal 302, last_response.status
    assert_equal 'test', session[:username]
    assert_includes last_response['Location'], '/flights'

    get '/users/signout'

    assert_equal 302, last_response.status
    assert_nil session[:username]

    get last_response['Location']

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<h3>Please sign in or sign up'
    assert_includes last_response.body, '<ul class="links"'
    assert_includes last_response.body, 'Sign In'
    assert_includes last_response.body, 'Sign Up'
  end

  def test_add_new_flight_with_existing_flight_number
    parameters = {
      airline: 'Air Tunisia',
      flight_number: 'TU28',
      destination: 'Prague',
      hour: '06',
      minute: '35'
    }

    post '/flights/new', parameters, admin_session

    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/flights'

    get last_response['Location'], {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<td>Air Tunisia</td>'
    assert_includes last_response.body, '<td>TU28</td>'
    assert_includes last_response.body, '<td>Prague</td>'
    assert_includes last_response.body, '<td>06:35</td>'

    parameters[:airline] = 'Air Turkey'
    parameters[:destination] = 'Rio de Janeiro'
    parameters[:hour] = '18'
    parameters[:minute] = '20'

    post '/flights/new', parameters, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Flight number TU28 is already being tracked.'
  end

  def test_edit_flight
    parameters = {
      airline: 'Air Tunisia',
      flight_number: 'TU28',
      destination: 'Prague',
      hour: '06',
      minute: '35'
    }

    post '/flights/new', parameters, admin_session

    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/flights'

    get last_response['Location'], {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, '<td>Air Tunisia</td>'
    assert_includes last_response.body, '<td>TU28</td>'
    assert_includes last_response.body, '<td>Prague</td>'
    assert_includes last_response.body, '<td>06:35</td>'

    parameters[:airline] = 'Air Turkey'
    parameters[:destination] = 'Rio de Janeiro'
    parameters[:hour] = '18'
    parameters[:minute] = '20'
    flight = load_user_flights[session[:username]].find do |current_flight|
      current_flight[:flight_number] == 'TU28'
    end

    post "/flights/#{flight[:id]}/edit", parameters, admin_session

    assert_equal 302, last_response.status

    get last_response['Location']

    assert_includes last_response.body, '<td>Air Turkey</td>'
    assert_includes last_response.body, '<td>TU28</td>'
    assert_includes last_response.body, '<td>Rio de Janeiro</td>'
    assert_includes last_response.body, '<td>18:20</td>'
  end
end
