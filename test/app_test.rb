# frozen_string_literal: true

require 'minitest/autorun'
require 'rack/test'

require_relative '../app'

class SimpleFlightTrackerTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def admin_session
    { 'rack.session' => { username: 'admin' } }
  end

  def session
    last_request.env['rack.session']
  end
end
