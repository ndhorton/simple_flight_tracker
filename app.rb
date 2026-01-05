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

def require_user_signin
  return if user_signed_in?

  session[:message] = 'You must be signed in to complete that action.'
  redirect '/'
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

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(64)
end

get '/' do
  redirect '/flights' if user_signed_in?

  erb :home
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

  erb :flights
end
