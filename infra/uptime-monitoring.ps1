# reset the lists of hosts prior to looping
$OutageHosts = $Null
# specify the time you want email notifications resent for hosts that are down
$EmailTimeOut = 720
# specify the time you want to cycle through your host lists.
$SleepTimeOut = 30
# specify the maximum hosts that can be down before the script is aborted
$MaxOutageCount = 15
# specify who gets notified
$notificationto = "to@domain.com"
# specify where the notifications come from
$notificationfrom = "from@domain.com"
# specify the SMTP server
$smtpserver = "smtp.domain.com"
 
Do{
$available = $Null
$notavailable = $Null
 
# Read the File with the Hosts every cycle, this way to can add/remove hosts
# from the list without touching the script/scheduled task, 
# also hash/comment (#) out any hosts that are going for maintenance or are down.
get-content servers.txt | Where-Object {!($_ -match "#")} | 
ForEach-Object {
if(Test-Connection -ComputerName $_ -Count 1 -ea silentlycontinue)
    {
    }
else
    {
     if(!(Test-Connection -ComputerName $_ -Count 4 -ea silentlycontinue))
       {
        # If the host is still unavailable for 4 full pings, write error and send email
        [Array]$notavailable += $_
 
        if ($OutageHosts -ne $Null)
            {
                if (!$OutageHosts.ContainsKey($_))
                {
                 # First time down add to the list and send email
                 $OutageHosts.Add($_,(get-date))
                 $Now = Get-date
                 $Body = "$_ has not responded for 5 pings at $Now"
                 Send-MailMessage -Body "$body" -to $notificationto -from $notificationfrom `
                  -Subject "Host $_ is down" -SmtpServer $smtpserver
                }
                else
                {
                    # If the host is in the list do nothing for 1 hour and then remove from the list.
                    if (((Get-Date) - $OutageHosts.Item($_)).TotalMinutes -gt $EmailTimeOut)
                    {$OutageHosts.Remove($_)}
                }
            }
        else
            {
                # First time down create the list and send email
                $OutageHosts = @{$_=(get-date)}
                $Body = "$_ has not responded for 5 pings at $Now" 
                Send-MailMessage -Body "$body" -to $notificationto -from $notificationfrom `
                 -Subject "Host $_ is down" -SmtpServer $smtpserver
            } 
       }
    }
}
sleep $SleepTimeOut
if ($OutageHosts.Count -gt $MaxOutageCount)
{
    # If there are more than a certain number of host down in an hour abort the script.
    $Exit = $True
    $body = $OutageHosts | Out-String
    Send-MailMessage -Body "$body" -to $notificationto -from $notificationfrom `
     -Subject "More than $MaxOutageCount Hosts down, monitoring aborted" -SmtpServer $smtpServer
}
}
while ($Exit -ne $True)
