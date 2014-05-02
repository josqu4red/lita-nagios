require "lita"

module Lita
  module Handlers
    class Nagios < Handler

      def self.default_config(config)
        config.default_room = nil
      end

      http.post "/nagios", :receive

      def receive(request, response)
        if request.params.has_key?("type")
          notif_type = request.params["type"].to_sym
          unless respond_to?(notif_type, true)
            raise "'#{notif_type}' is not supported by Nagios handler"
          end
        else
          raise "Notification type must be defined in Nagios command"
        end

        if request.params.has_key?("room")
          room = request.params["room"]
        elsif Lita.config.handlers.nagios.default_room
          room = Lita.config.handlers.nagios.default_room
        else
          raise "Room must be defined. Either fix your command or specify a default room ('config.handlers.nagios.default_room')"
        end

        message = send(notif_type, request.params)

        ack = request.params["notificationtype"] == "ACKNOWLEDGEMENT" ? irc_color("[ACK] ", :light_green) : ""

        target = Source.new(room: room)
        robot.send_message(target, "nagios: #{ack}#{message}")
      rescue Exception => e
        Lita.logger.error(e)
      end

      private

      def irc_color(str, fg, bg=nil)
        str
      end

      def host(params)
        case params["state"]
        when "UP"
          color = :light_green
        when "DOWN"
          color = :light_red
        when "UNREACHABLE"
          color = :orange
        end
        status = irc_color(params["state"], color)

        message = "#{params["host"]} is #{status}: #{params["output"]}"
      end

      def service(params)
        case params["state"]
        when "OK"
          color = :light_green
        when "WARNING"
          color = :yellow
        when "CRITICAL"
          color = :light_red
        when "UNKNOWN"
          color = :orange
        end
        status = irc_color(params["state"], color)

        message = "#{params["host"]}:#{params["description"]} is #{status}: #{params["output"]}"
      end
    end

    Lita.register_handler(Nagios)
  end
end
