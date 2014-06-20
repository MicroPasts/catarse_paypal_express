# CatarsePaypalExpress [![Build Status](https://travis-ci.org/MicroPasts/catarse_paypal_express.svg?branch=master)](https://travis-ci.org/MicroPasts/catarse_paypal_express) 

Catarse paypal express integration with [Catarse](http://github.com/danielweinmann/catarse) crowdfunding platform.

## Installation

Add this line to your Catarse application's Gemfile and
run `bundle install` in your terminal:

    gem 'catarse_paypal_express'

Since this gem is a Rails Engine intented to work on Catarse's applications,
you need to mount it in a route and configure some keys.

    # config/routes.rb
    mount CatarsePaypalExpress::Engine => "/", :as => "catarse_paypal_express"

Inside your Rails console (accessible via `bundle exec rails console`),
create appropriate settings:

    Configuration.create!(name: "paypal_username", value: "USERNAME")
    Configuration.create!(name: "paypal_password", value: "PASSWORD")
    Configuration.create!(name: "paypal_signature", value: "SIGNATURE")

    # Any value is accepted as `true`
    Configuration.create!(name: "paypal_test", value: "1")
    
## To go out of the sandbox

Run `bundle exec rails console` and destroy the setting saying
you're in the sandbox.

    Configuration.find_by(name: "paypal_test").destroy
    Rails.cache.delete("/configurations/paypal_test")

## Rails 3.2.x and Rails 4 support

If you are using the Rails 3.2.x on Catarse's code, you can use the version `1.0.0`.

For Rails 4 support use the `2.0.0` version.

## Development environment setup

Clone the repository:

    $ git clone git://github.com/devton/catarse_paypal_express.git

Add the catarse code into test/dummy:

    $ git submodule init
    $ git submodule update

And then execute:

    $ bundle

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

This project rocks and uses MIT-LICENSE.
