## When a new report is created, send replies to its owner

class MessageSender
  include FormHandler
    
  def sendmail(project, report, message)
    eid = 'assigned' # setup
    return unless message.has_element?(eid)
    
    to = message[eid].split(/[,\s]+/).find_all{|addr| valid_email_address?(addr)}
    to = to.uniq - project.notify_addresses - report.email_addresses
    if !to.empty? then
      project.sendmail_to(report, message, to, [], [])
    end
  end
end

@project.add_new_report_hook {|report, message|
  MessageSender.new.sendmail(@project, report, message)
}

@project.add_add_message_hook {|report, message|
  MessageSender.new.sendmail(@project, report, message)
}
