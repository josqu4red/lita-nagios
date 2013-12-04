require "lita"

module Lita
  module Handlers
    class Nagios < Handler
    end

    Lita.register_handler(Nagios)
  end
end
