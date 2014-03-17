require "lita"

module Lita
  module Handlers
    class Nagios < Handler

      SERVICE_STATES = Hash.new(:clear).merge({
        "OK" => :light_green,
        "WARNING" => :yellow,
        "CRITICAL" => :light_red,
        "UNKNOWN" => :orange,
      })

      HOST_STATES = Hash.new(:clear).merge({
        "UP" => :light_green,
        "DOWN" => :light_red,
        "UNREACHABLE" => :orange,
      })

      NOTIF_TYPES = Hash.new(:clear).merge({
        "PROBLEM" => :light_red,
        "RECOVERY" => :light_green,
        "ACKNOWLEDGEMENT" => :yellow,
#        "FLAPPINGSTART",
#        "FLAPPINGSTOP",
#        "FLAPPINGDISABLED",
#        "DOWNTIMESTART",
#        "DOWNTIMESTOP",
#        "DOWNTIMECANCELLED",
      })

      def self.default_config(config)
        config.default_room = nil
      end

      http.post "/nagios/alerts", :alerts

      def alerts(request, response)
        params = request.params.dup

        if params.has_key?("type")
          notif_type = params["type"].to_sym
          raise "'#{notif_type}' is not supported by Nagios handler" unless respond_to?(notif_type, true)
        else
          raise "Notification type must be defined in Nagios command"
        end

        if params.has_key?("room")
          room = params["room"]
        elsif Lita.config.handlers.nagios.default_room
          room = Lita.config.handlers.nagios.default_room
        else
          raise "Room must be defined. Either fix your command or specify a default room ('config.handlers.nagios.default_room')"
        end

        message = notification_type(params)
        message += send(notif_type, params)

        target = Source.new(room: room)
        robot.send_message(target, "nagios: #{ack}#{message}")
      rescue Exception => e
        Lita.logger.error(e)
      end

      private

      def notification_type(params)
        color = NOTIF_TYPES[params["notificationtype"]]
        "[#{params["notificationtype"]}] ".irc_color(color)
      end

      def host(params)
        color = HOST_STATES[params["hoststate"]]
        status = params["state"].irc_color(color)
        "#{params["host"].irc_color(:orange)} is #{status}: #{params["output"].gsub(/\s*#{params["state"]}\s*:?\s*/, "")}"
      end

      def service(params)
        color = SERVICE_STATES[params["servicestate"]]
        status = params["state"].irc_color(color)
        "#{params["host"].irc_color(:orange)}:#{params["description"]} is #{status}: #{params["output"].gsub(/\s*#{params["state"]}\s*:?\s*/, "")}"
      end
    end

    Lita.register_handler(Nagios)
  end
end
