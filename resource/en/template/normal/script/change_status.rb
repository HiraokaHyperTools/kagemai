## An example for setting the values of certain fields arbitrarily.

## Set status fields semi-automatically.

=begin

@project.add_add_message_hook {|report, message|
  if message['assigned'] != 'None' && message['status'] == 'New' then
    message['status'] = 'Assigned'
  end

  if message['resolution'] != 'Unresolved' && message['status'] != 'Fixed' then
    message['status'] = 'Awaiting verification'
  end
}

=end
