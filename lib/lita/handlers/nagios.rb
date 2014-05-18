module Lita
  module Handlers
    class Nagios < Handler

      def self.default_config(config)
        config.default_room = nil
        config.cgi = nil
        config.user = nil
        config.pass = nil
        config.version = 3
        config.time_format = "iso8601"
        config.verify_ssl = true
      end

      def initialize(robot)
        @site = NagiosHarder::Site.new(
          config.cgi,
          config.user,
          config.pass,
          config.version,
          config.time_format,
          config.verify_ssl
        )
        super(robot)
      end

      ##
      # Chat routes
      ##

      route /^nagios\s+(?<action>enable|disable)\s+notif(ication(s)?)?/, :toggle_notifications,
        command: true,
        restrict_to: ["admins"],
        kwargs: {
          host: { short: "h" },
          service: { short: "s" }
        },
        help: {
          "nagios enable notif(ication(s)) <-h | --host HOST> [-s | --service SERVICE]" => "Enable notifications for given host/service",
          "nagios disable notif(ication(s)) <-h | --host HOST> [-s | --service SERVICE]" => "Disable notifications for given host/service",
        }

      def toggle_notifications(response)
        args = response.extensions[:kwargs]
        return response.reply("Missing 'host' argument") unless args[:host]

        action = response.match_data[:action]

        reply = @site.send("#{action}_service_notifications", args[:host], args[:service])
        response.reply(reply)
      end

      route /^nagios\s+recheck/, :recheck,
        command: true,
        restrict_to: ["admins"],
        kwargs: {
          host: { short: "h" },
          service: { short: "s" }
        },
        help: {
          "nagios recheck <-h | --host HOST> [-s | --service SERVICE]" => "Reschedule check for given host/service"
        }

      def recheck(response)
        args = response.extensions[:kwargs]
        return response.reply("Missing 'host' argument") unless args[:host]

        if args[:service]
          method_w_params = [ :schedule_service_check, args[:host], args[:service] ]
          reply = "#{args[:service]} on #{args[:host]}"
        else
          method_w_params = [ :schedule_host_check, args[:host] ]
          reply = args[:host]
        end

        reply = @site.send(*method_w_params) ? "Check scheduled for #{reply}" : "Failed to schedule check for #{reply}"
        response.reply(reply)
      end

      route /^nagios\s+ack(nowledge)?/, :acknowledge,
        command: true,
        restrict_to: ["admins"],
        kwargs: {
          host: { short: "h" },
          service: { short: "s" },
          message: { short: "m" }
        },
        help: {
          "nagios ack(nowledge) <-h | --host HOST> [-s | --service SERVICE] [-m | --message MESSAGE]" => "Acknowledge host/service problem with optional message",
        }

      def acknowledge(response)
        args = response.extensions[:kwargs]
        return response.reply("Missing 'host' argument") unless args[:host]

        user = response.message.source.user.name
        message =  args[:message] ? "#{args[:message]} (#{user})" : "acked by #{user}"

        if args[:service]
          method_w_params = [ :acknowledge_service, args[:host], args[:service], message ]
          reply = "#{args[:service]} on #{args[:host]}"
        else
          method_w_params = [ :acknowledge_host, args[:host], message ]
          reply = args[:host]
        end

        reply = @site.send(*method_w_params) ? "Acknowledgment set for #{reply}" : "Failed to acknowledge #{reply}"
        response.reply(reply)
      end

      route /^nagios(\s+(?<type>fixed|flexible))?\s+downtime/, :schedule_downtime,
        command: true,
        restrict_to: ["admins"],
        kwargs: {
          host: { short: "h" },
          service: { short: "s" },
          duration: { short: "d" }
        },
        help: {
          "nagios (fixed|flexible) downtime <-d | --duration DURATION > <-h | --host HOST> [-s | --service SERVICE]" => "Schedule downtime for a host/service with duration units in (m, h, d, default to seconds)"
        }

      def schedule_downtime(response)
        args = response.extensions[:kwargs]
        return response.reply("Missing 'host' argument") unless args[:host]

        units = { "m" => :minutes, "h" => :hours, "d" => :days }
        match = /^(?<value>\d+)(?<unit>[#{units.keys.join}])?$/.match(args[:duration])
        return response.reply("Invalid downtime duration") unless (match and match[:value])

        duration = match[:unit] ? match[:value].to_i.send(units[match[:unit]]) : match[:value].to_i

        options = case response.match_data[:type]
        when "fixed"
          { type: :fixed, start_time: Time.now, end_time: Time.now + duration }
        when "flexible"
          { type: :flexible, hours: (duration / 3600), minutes: (duration % 3600 / 60) }
        end.merge({ author: "#{response.message.source.user.name} via Lita" })

        if args[:service]
          method_w_params = [ :schedule_service_downtime, args[:host], args[:service], options ]
          reply = "#{args[:service]} on #{args[:host]}"
        else
          method_w_params = [ :schedule_host_downtime, args[:host], options ]
          reply = args[:host]
        end

        reply = @site.send(*method_w_params) ? "#{options[:type].capitalize} downtime set for #{reply}" : "Failed to schedule downtime for #{reply}"
        response.reply(reply)
      end


      ##
      # HTTP endpoints
      ##

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
        elsif config.default_room
          room = config.default_room
        else
          raise "Room must be defined. Either fix your command or specify a default room ('config.handlers.nagios.default_room')"
        end

        message = send(notif_type, request.params)

        ack = request.params["notificationtype"] == "ACKNOWLEDGEMENT" ? "[ACK] " : ""

        target = Source.new(room: room)
        robot.send_message(target, "nagios: #{ack}#{message}")
      rescue Exception => e
        Lita.logger.error(e)
      end

      private

      def host(params)
        case params["state"]
        when "UP"
          color = :light_green
        when "DOWN"
          color = :light_red
        when "UNREACHABLE"
          color = :orange
        end
        status = params["state"]

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
        status = params["state"]

        message = "#{params["host"]}:#{params["description"]} is #{status}: #{params["output"]}"
      end
    end

    Lita.register_handler(Nagios)
  end
end
