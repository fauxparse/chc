require "rubygems"
require "bundler"

Bundler.require

require './chc'
run Sinatra::Application
