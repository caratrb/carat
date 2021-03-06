require 'rubygems'

class Gem::Platform
  @local = new(ENV['CARAT_SPEC_PLATFORM']) if ENV['CARAT_SPEC_PLATFORM']
end

if ENV['CARAT_SPEC_VERSION']
  module Carat
    VERSION = ENV['CARAT_SPEC_VERSION'].dup
  end
end

class Object
  if ENV['CARAT_SPEC_RUBY_ENGINE']
    remove_const :RUBY_ENGINE if defined?(RUBY_ENGINE)
    RUBY_ENGINE = ENV['CARAT_SPEC_RUBY_ENGINE']

    if RUBY_ENGINE == "jruby"
      JRUBY_VERSION = ENV["CARAT_SPEC_RUBY_ENGINE_VERSION"]
    end
  end
end
