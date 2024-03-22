require "foobara/all"

module Foobara
  module Autocrud
    foobara_domain!
  end

  Util.require_directory("#{__dir__}/../../src")
end
