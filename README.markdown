CHC
===

A tiny application that scrapes flight information from the
[Christchurch International Airport](http://christchurchairport.co.nz)
homepage, and presents it in a format suitable for iPhone.

This is **not** an official application, and may change
or disappear at any time. It was mostly for something to
do while my work servers were down following a major
earthquake.

How it works
------------
The airport's flight information is served using a ghastly
ASPX site. The domestic arrivals information is available
from the homepage, but everything else has to be fetched
with a `POST` request, which seems to need a bunch of
form variables from the homepage, so I make heavy use
of a tiny Redis cache with about five keys.

Each time a request is made for the Domestic Arrivals
information, we hit the homepage, grab the flight information,
and cache the ASPX view state data at the same time.
For the other three flight types, we check if we have any
relatively fresh view state data in the cache (the expiry
is set at a relatively conservative two minutes), and use
that to form the `POST` request to the flights page; if
there isn't any, we first perform a quick hit on the homepage
to get some new view state parameters.

Redis's automatic key expiry comes in really handy here:
we can just set keys with an expiry time of thirty seconds
or so and never have to worry about manually expiring stuff.
Eventually, we'll get a request for data that has expired
from the cache, and it'll be time to scrape it again. Simple!

The scraping of the flight information is relatively simple
after that: just find the table and rip the rows out one by one.
For now, the JSONified version of the flight information is stored
wholesale in Redis as a single string, since we never
do anything else with it.

Technologies
------------
I used a bunch of stuff on this project I hadn't really played with before:

* [Sinatra](http://www.sinatrarb.com/) as super-lightweight middleware
* [Hpricot](https://github.com/hpricot/hpricot/wiki) for scraping the HTML data
* [HAML](http://haml-lang.com/) for markup (I don't really get HAML: tell the truth, it kind of annoyed me)
* [Redis](http://redis.io/) for caching
* [iScroll](http://cubiq.org/iscroll-4) for the fixed-pane scrolling and "pull to refresh"

The whole thing runs on [Heroku](http://heroku.com/).

Caveats
-------
In theory, the airport could tell me to take all this down.
I'd hope that they'd at least see that if someone could put
the guts of this together in an afternoon without access to
any kind of API, it would be relatively cost-effective to
provide an official mobile site. Hell, I'd give them this one.

For now, this is only an iPhone app. I've downloaded the
Android SDK, but haven't dipped my toes in those murky
waters just yet. We'll see.

Matt Powell ([@fauxparse](http://twitter.com/fauxparse))
March 2011
