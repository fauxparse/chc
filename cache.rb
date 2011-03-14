require "open-uri"
require "date"
require "net/http"
require "cgi"
require "uri"
require "active_support/time"
require "./lib/scraper"

class Cache
  def initialize
    Time.zone = "Auckland"
    @url = "http://www.christchurchairport.co.nz"
  end
  
  def parsed
    @parsed ||= begin
      http = Net::HTTP.new("www.christchurchairport.co.nz", 80)
      headers = {
        "Content-Type"=>"application/x-www-form-urlencoded; charset=UTF-8",
        "Referer"=>"http://www.christchurchairport.co.nz/",
        "User-Agent"=>"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_6; en-US) AppleWebKit/534.16 (KHTML, like Gecko) Chrome/10.0.648.127 Safari/534.16",
        "X-MicrosoftAjax" => "Delta=true"
      }
      short_name = self.class.name.sub(/^([A-Z][a-z]{2})[a-z]*([A-Z][a-z]{2})[a-z]*/, "\\1\\2")
      button_name = "ctl00$ctl00$SitePlaceHolder$ContentHolder$ctl03$#{short_name}"
      button_value = self.class.name.gsub(/([a-z])([A-Z])/, "\\1 \\2")
      encoded_data = form_params.merge({button_name => button_value}).to_a.map { |k, v|
        "#{k}=#{CGI::escape(v)}"
      }.join("&")
      response, data = http.post("/Default.aspx", encoded_data, headers)
      Hpricot.parse data
    end
  end

  def flights
    @flights ||= begin
      tbody = parsed.at ".results table tbody"
      (tbody/"tr").map do |tr|
        td = tr/"td"
        {
          "airline"        => (td[0]/"a")[0].attributes["title"],
          "flight_numbers" => td[1].children.select(&:text?).map { |n| n.to_s.strip },
          "cities"         => td[2].children.select(&:text?).map { |n| n.to_s.strip },
          "scheduled"      => Time.zone.parse(td[3].inner_text),
          "estimated"      => Time.zone.parse(td[4].inner_text),
          "gate"           => td[5].inner_text,
          "status"         => td[6].inner_text.gsub(/^\*|\*$/, "")
        }
      end
    end
  end
  
  def form_params
    @form_params ||= DomesticArrivals.new.form_params
  end
  
  def to_json
    json = REDIS.get(self.class.name) || begin
      json = flights.to_json
      REDIS.setex(self.class.name, 60, json)
      json
    end
  end
  
  def self.to_json
    REDIS.get(name) || new.to_json
  end
  
  def self.with(terminal, kind)
    "#{terminal}_#{kind}s".classify.constantize
  end
end

class DomesticArrivals < Cache
  def parsed
    @parsed ||= Hpricot(open(@url)).tap do |doc|
      load_form_params_from doc
    end
  end
  
  def form_params
    if params = REDIS.get('form_params')
      JSON.parse(params)
    else
      parsed
      @form_params
    end
  end
  
  def load_form_params_from(doc)
    @form_params = {}
    (doc/"input").each do |input|
      unless input.attributes["type"].downcase == "submit"
        @form_params[input.attributes["name"]] = input.attributes["value"]
      end
    end
    REDIS.setex('form_params', 120, @form_params.to_json)
  end
end

class DomesticDepartures < Cache
end

class InternationalArrivals < Cache
end

class InternationalDepartures < Cache
end
