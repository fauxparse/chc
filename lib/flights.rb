require "uri"
require "active_support/time"
require "./lib/scraper"

class Flight
  attr_accessor :airline, :flight_numbers, :cities, :scheduled, :estimated, :gate, :status
  
  def initialize(attributes = {})
    attributes.each_pair do |key, value|
      send :"#{key}=", value
    end
  end
  
  def inspect
    "#{airline} flight #{flight_numbers.join("/")} #{description}#{" (#{status})" if status?}"
  end
  
  def status?
    !(status.nil? || status.empty?)
  end
  
  def scheduled=(value)
    Time.zone = "Auckland"
    @scheduled = Time.zone.parse(value.to_s)
  end
  
  def estimated=(value)
    Time.zone = "Auckland"
    @estimated = Time.zone.parse(value.to_s)
  end
  
  def to_json(*args)
    attributes.to_json
  end
  
  def attributes
    {
      "airline"        => airline,
      "flight_numbers" => flight_numbers,
      "cities"         => cities,
      "status"         => status,
      "scheduled"      => scheduled.to_time.to_i * 1000,
      "estimated"      => estimated.to_time.to_i * 1000,
      "gate"           => gate
    }
  end
  
  def self.all
    data = if (json = REDIS.get("flights"))
      JSON.parse(json)
    else
      flights = Scraper.flights
      REDIS.setex "flights", 60, flights.to_json
      flights
    end
  
    data.to_a.inject([]) do |memo, (key, flights)|
      memo + flights.map { |f| factory(f, key) }
    end
  end
  
  module Domestic
  end
  def domestic?; is_a?(Domestic); end

  module International
  end
  def international?; is_a?(International); end

  module Arrival
    def description
      "from #{cities.join(" and ")}, arriving at #{estimated.strftime("%H:%M")} at gate #{gate}"
    end
  end
  def arrival?; is_a?(Arrival); end

  module Departure
    def description
      "to #{cities.join(" and ")}, departing at #{estimated.strftime("%H:%M")} from gate #{gate}"
    end
  end
  def departure?; is_a?(Departure); end
  
  def self.factory(attributes, kind)
    new(attributes).tap do |flight|
      kind.split(/[_-]/).each do |k|
        mod = k.sub(/^(\w)/) { $1.upcase }.sub(/s$/, "")
        flight.extend const_get(mod)
      end
    end
  end
end

