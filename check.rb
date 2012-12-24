# encoding: utf-8

require 'tiny_tds'
require 'time'
require 'tlsmail'

# Database Information
$dbHost = "192.168.100.248"
$dbUsername = "sa"
$dbPassword = "apputu.SQL"
$dbTableName = "WFTP"

# Mail Setting
$mailSender = "noreply@winspection.com"
$mailHost = "msa.hinet.net"
$mailPort = 25

# Miscellaneous Setting
$limitationDay = 30
$secondsInADay = 86400

# Send notification mail to user
def sendNotifyToUser(userData)
  if userData["LastLoginDate"].nil?
    message = "You have <span style='font-weight:bold; color:#FF0000;'>never</span> logged in to engineering system."
  else
    message = "You have been not logged in <span style='font-weight:bold; color:#FF0000;'>#{userData["UnLoginDays"]}</span> days."
  end

content = <<MESSAGE_END
From: WIS Engineering Database System <#{$mailSender}>
To: #{userData["Username"]} <#{userData["Email"]}>
Date: #{Time.now.rfc2822}
MIME-Version: 1.0
Content-type: text/html
Subject: WIS Engineering Database System Notification

Hello <span style='font-weight:bold;'>#{userData["Username"]}</span>,<br/>
<br/>
<br/>
#{message}<br/>
<br/>
Please login as soon as possible.<br/>
<br/>
<br/>
<br/>
<br/>
Yours sincerely,<br/>
Wintriss Engineering Database System<br/>
<br/>
<span style='font-weight:bold;'>[THIS IS AN AUTOMATED MESSAGE - PLEASE DO NOT REPLY DIRECTLY TO THIS EMAIL]</span>
MESSAGE_END

  Net::SMTP.start($mailHost, $mailPort) do |smtp|
    smtp.send_message(content, $mailSender, userData["Email"])
  end
end

# Send notification mail to administrator
def sendNotifyToAdmin(userData, adminMailList)
	userList = ""
	userData.each { | data|
		userList << "<tr>"
		userList << "<td>#{data["Username"]}</td>"
		userList << "<td>#{data["Email"]}</td>"
		userList << "<td>#{data["CreateDate"]}</td>"
                if data["LastLoginDate"].nil?
			userList << "<td>Never</td>"
		else
                        userList << "<td>#{data["LastLoginDate"]}"
		end
		userList << "<td>#{data["UnLoginDays"]} days</td>"
		userList << "</tr>"
	}

content = <<MESSAGE_END
From: WIS Engineering Database System <#{$mailSender}>
To: No-Reply <#{$mailSender}>
Date: #{Time.now.rfc2822}
MIME-Version: 1.0
Content-type: text/html
Subject: WIS Engineering Database System Notification

Hello <span style='font-weight:bold;'>Administrator</span>,<br/>
<br/>
<br/>
The following users are too long not logged in or have never logged into the system：<br/>
<br/>
<table border="1">
<tr>
<th>Name</th>
<th>Email</th>
<th>Account Create Date</th>
<th>Last Login Date</th>
<th>Days of no login</th>
</tr>
#{userList}
</table>
<br/>
Please remind user login as soon as possible.<br/>
<br/>
<br/>
<br/>
<br/>
Yours sincerely,<br/>
Wintriss Engineering Database System<br/>
<br/>
<span style='font-weight:bold;'>[THIS IS AN AUTOMATED MESSAGE - PLEASE DO NOT REPLY DIRECTLY TO THIS EMAIL]</span>
MESSAGE_END

  Net::SMTP.start($mailHost, $mailPort) do |smtp|
    smtp.send_message(content, $mailSender, adminMailList)
  end
end

# Query user information
userList = Array.new
adminMailList = Array.new
client = TinyTds::Client.new(:username => $dbUsername, :password => $dbPassword, :host => $dbHost, :database => $dbTableName)
# Get limitation day
result = client.execute("SELECT [LimitationDay] FROM [dbo].[SystemConfig]")
$limitationDay = result.first["LimitationDay"]
# Get userlist
result = client.execute("SELECT * FROM [dbo].[Employees] WHERE [Activity] = 1")
result.each { |row|
	userDate = row["LastLoginDate"].nil? ? userDate = row["CreateDate"] : row["LastLoginDate"]
	unLoginDays = ((Time.now - userDate) / $secondsInADay).to_i
	data = {
		"Username" => row["Name"],
		"UnLoginDays" => unLoginDays,
		"CreateDate" => row["CreateDate"],
		"LastLoginDate" => row["LastLoginDate"],
		"Email" => row["Email"],
		"RecvNotify" => row["RecvNotify"]
	}
	userList.push(data) if unLoginDays >= $limitationDay
	adminMailList.push(row["Email"]) if row["RecvNotify"]
	sendNotifyToUser data if unLoginDays >= $limitationDay
}
sendNotifyToAdmin(userList, adminMailList) if userList.count > 0 && adminMailList.count > 0
# Close database connection
client.close
