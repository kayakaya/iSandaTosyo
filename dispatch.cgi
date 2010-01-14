#!/home/kayakayaichthys/local/ruby191/bin/ruby1.9
load 'start.rb'

set :run, false
set :environment, :production
set :public, File.dirname(__FILE__) + '/public'
set :views, File.dirname(__FILE__) + '/public/views'
set :base_url, '/isandatosyo'
Rack::Handler::CGI.run Sinatra::Application
