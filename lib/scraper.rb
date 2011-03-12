require "open-uri"
require "date"
require "net/http"
require "cgi"

class Scraper
  def initialize(url = "http://www.christchurchairport.co.nz")
    @url = url
    @flights = false
    Time.zone = "Auckland"
  end
  
  def flights
    scrape!
    @flights
  end
  
  def self.flights
    new.flights
  end
  
  def form_data
    scrape!
    @form_data
  end
  
  def scrape!
    hp = Hpricot(open(@url))
    @flights = {}
    @flights["domestic_arrivals"] = parse_flights(hp) 
    
    @form_data, buttons = {}, {}
    (hp/"input").each do |input|
      if input.attributes["type"].downcase == "submit"
        buttons[input.attributes["name"]] = input.attributes["value"]
      else
        @form_data[input.attributes["name"]] = input.attributes["value"]
      end
    end
    
    buttons.each do |k, v|
      v = v.downcase.gsub(/\s+/, "_")
      next if @flights.key?(v) || v == "search"
      @flights[v] = parse_flights(more_flights(@form_data, k, v))
    end
    
    @flights
  end
  
  def parse_flights(hp)
    begin
      tbody = hp.at ".results table tbody"
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
    rescue
      hp.to_html
    end
  end
  
  def more_flights(form_data, button_name, button_value)
    http = Net::HTTP.new("www.christchurchairport.co.nz", 80)
    headers = {
      "Content-Type"=>"application/x-www-form-urlencoded; charset=UTF-8",
      "Referer"=>"http://www.christchurchairport.co.nz/",
      "User-Agent"=>"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_6; en-US) AppleWebKit/534.16 (KHTML, like Gecko) Chrome/10.0.648.127 Safari/534.16",
      "X-MicrosoftAjax" => "Delta=true"
    }
    encoded_data = form_data.merge({button_name => button_value}).to_a.map { |k, v|
      "#{k}=#{CGI::escape(v)}"
    }.join("&")
    response, data = http.post("/Default.aspx", encoded_data, headers)
    Hpricot.parse data
  end
end