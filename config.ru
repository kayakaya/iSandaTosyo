require 'start.rb'

set :environment, :production
set :public, File.dirname(__FILE__) + '/public'
set :views, File.dirname(__FILE__) + '/public/views'
set :base_url, ''

run Sinatra::Application
