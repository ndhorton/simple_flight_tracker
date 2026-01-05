# frozen_string_literal: true

require 'bcrypt'
require 'securerandom'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'yaml'

def credentials_pathname
  File.join(data_path, 'users.yaml')
end

def data_path
  if ENV['RACK_ENV'] == 'test'
    # rubocop:disable Style/ExpandPathArguments
    File.join(File.expand_path('..', __FILE__), File.join('data', 'test'))
    # rubocop:enable Style/ExpandPathArguments
  else
    # rubocop:disable Style/ExpandPathArguments
    File.join(File.expand_path('..', __FILE__), 'data')
    # rubocop:enable Style/ExpandPathArguments
  end
end

def encrypt_password(password)
  BCrypt::Password.create(password).to_s
end

def load_user_credentials
  File.exist?(credentials_pathname) ? YAML.load_file(credentials_pathname) : {}
end

def load_user_flights
  pathname = File.join(data_path, 'flights.yaml')
  File.exist?(pathname) ? YAML.load_file(pathname) : {}
end

def require_user_signin
  return if user_signed_in?

  session[:message] = 'You must be signed in to complete that action.'
  redirect '/'
end

def save_user_flights(flights)
  pathname = File.join(data_path, 'flights.yaml')
  File.write(pathname, YAML.dump(flights))
end

def save_user_credentials(credentials)
  File.write(credentials_pathname, YAML.dump(credentials))
end

def user_exists?(username)
  credentials = load_user_credentials
  credentials.key?(username)
end

def user_signed_in?
  !!session[:username]
end

def valid_credentials?(username, password)
  return false unless user_exists?(username)

  credentials = load_user_credentials
  BCrypt::Password.new(credentials[username]) == password
end

helpers do
  def previous_select(current_option, param_option)
    return '' unless param_option == format('%02d', current_option)

    'selected'
  end
end

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(64)
end

get '/' do
  redirect '/flights' if user_signed_in?

  erb :home
end

get '/users/signout' do
  session[:username] = nil
  redirect '/'
end

get '/users/signin' do
  erb :signin
end

post '/users/signin' do
  username = params[:username].strip
  password = params[:password]
  if username.empty?
    session[:message] = 'Username cannot be blank.'
    erb :signin
  elsif password.empty?
    session[:message] = 'Password cannot be blank.'
    erb :signin
  elsif valid_credentials?(username, password)
    session[:username] = username
    redirect '/flights'
  else
    session[:message] = 'Username and password do not match.'
    erb :signin
  end
end

get '/users/signup' do
  erb :signup
end

post '/users/signup' do
  username = params[:username].strip
  password = params[:password]
  if username.empty?
    session[:message] = 'Username cannot be blank.'
    erb :signup
  elsif user_exists?(username)
    session[:message] = 'That username is taken. Please choose another.'
    @previous_username = username
    erb :signup
  elsif password.empty?
    session[:message] = 'Password cannot be blank.'
    erb :signup
  else
    credentials = load_user_credentials
    credentials[username] = encrypt_password(password)
    save_user_credentials(credentials)
    session[:message] = 'Account created. Please sign in.'
    redirect '/'
  end
end

get '/flights' do
  require_user_signin

  all_flights = load_user_flights
  @flights = all_flights[session[:username]]
  erb :flights
end

get '/flights/new' do
  erb :new_flight
end

post '/flights/new' do
  params.each_pair do |key, value|
    next unless value.strip.empty?

    field = key.split('_').map(&:capitalize).join(' ')
    session[:message] = "#{field} cannot be blank."
    halt erb :new_flight
  end

  flight_number = params[:flight_number]
  unless flight_number.match?(/[a-zA-Z]{2}[0-9]{1,3}/)
    session[:message] = 'Invalid Flight Number.'
    halt erb :new_flight
  end

  flight = {
    id: SecureRandom.uuid,
    airline: params[:airline],
    flight_number: params[:flight_number],
    destination: params[:destination],
    departure_time: "#{params[:hour]}:#{params[:minute]}"
  }
  all_flights = load_user_flights
  user_flights = all_flights[session[:username]] || []
  user_flights << flight
  all_flights[session[:username]] = user_flights
  save_user_flights(all_flights)
  session[:message] = "Now tracking flight #{flight[:flight_number]}."
  redirect '/flights'
end

get '/flights/:flight_id/delete' do
  all_flights = load_user_flights
  user_flights = all_flights[session[:username]]
  flight = user_flights.find { |flight| flight[:id] == params[:flight_id] }
  flight_number = flight[:flight_number]
  all_flights[session[:username]] = user_flights.reject do |flight|
    flight[:id] == params[:flight_id]
  end
  save_user_flights(all_flights)

  session[:message] = "No longer tracking flight #{flight_number}."
  redirect '/flights'
end
