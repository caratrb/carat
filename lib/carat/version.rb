module Carat
  # We're doing this because we might write tests that deal
  # with other versions of carat and we are unsure how to
  # handle this better.
  VERSION = "1.9.9.pre1" unless defined?(::Carat::VERSION)
end
