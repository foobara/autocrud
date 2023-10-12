require "foobara/all"

module Foobara
  Util.require_directory(__dir__)

  module Autocrud
    foobara_domain!
  end
end
