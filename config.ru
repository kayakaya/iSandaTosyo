require 'start.rb'

set :public, File.dirname(__FILE__) + '/public'
set :views, File.dirname(__FILE__) + '/public/views'
set :base_url, ''

run Sinatra::Application
