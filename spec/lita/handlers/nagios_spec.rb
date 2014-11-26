require "spec_helper"

describe Lita::Handlers::Nagios, lita_handler: true do
  it { is_expected.to route_http(:post, "/nagios/notifications").to(:receive) }
  it { is_expected.to route_command("nagios enable notif -h par-db4").with_authorization_for(:admins).to(:toggle_notifications) }
  it { is_expected.to route_command("nagios enable notif -h par-db4 -s Load").with_authorization_for(:admins).to(:toggle_notifications) }
  it { is_expected.to route_command("nagios disable notification -h par-db4 -s Load").with_authorization_for(:admins).to(:toggle_notifications) }
  it { is_expected.to route_command("nagios disable notifications -h par-db4 -s Load").with_authorization_for(:admins).to(:toggle_notifications) }

  it { is_expected.to route_command("nagios recheck -h par-db4").with_authorization_for(:admins).to(:recheck) }
  it { is_expected.to route_command("nagios recheck -h par-db4 -s Load").with_authorization_for(:admins).to(:recheck) }

  it { is_expected.to route_command("nagios ack -h par-db4").with_authorization_for(:admins).to(:acknowledge) }
  it { is_expected.to route_command("nagios ack -h par-db4 -s Load").with_authorization_for(:admins).to(:acknowledge) }

  it { is_expected.to route_command("nagios fixed downtime -d 2h -h par-db4 -s Load").with_authorization_for(:admins).to(:schedule_downtime) }
  it { is_expected.to route_command("nagios flexible downtime -d 2h -h par-db4 -s Load").with_authorization_for(:admins).to(:schedule_downtime) }
end
