require "./lib/flights"

configure do
  REDIS = if config = ENV['REDISTOGO_URL']
    uri = URI.parse(ENV["REDISTOGO_URL"])
    Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  else
    Redis.new
  end
end

set :haml, {
  :format       => :html5,
  :attr_wrapper => '"'
}

get "/" do
  haml :index
end

%w(domestic international).each do |terminal|
  %w(arrival departure).each do |kind|
    get "/#{terminal}/#{kind}s" do
      content_type :json
      headers['Cache-Control'] = 'max-age=30, must-revalidate'
      Flight.all.select { |f| f.send(:"#{terminal}?") && f.send(:"#{kind}?") }.to_json
    end
  end
end
