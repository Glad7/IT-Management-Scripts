#Cert will expire 12/04/2024
$certCred = Get-StoredCredential -Target MailboxUsageCert
$appCred = Get-StoredCredential -Target MailboxUsageMonitor

#$secureThumb = ConvertFrom-SecureString $cred.Password
$thumb = (New-Object PSCredential 0, $certCred.Password).GetNetworkCredential().Password
$tenant = (New-Object PSCredential 0, $appCred.Password).GetNetworkCredential().Password

Connect-ExchangeOnline -CertificateThumbprint $thumb -AppID $appCred.UserName -Organization "companyname.onmicrosoft.com"

#Get list of all user mailboxes
$users = Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox -Properties ProhibitSendReceiveQuota

#$FullInboxMailingList = @()

$exportData = foreach($user in $users) {
    $prohibitSendReceiveQuota = [math]::Round(($user.ProhibitSendReceiveQuota.ToString().Split('(')[1].Split(' ')[0].Replace(',','')/1MB),2)

    $userStats = Get-EXOMailboxStatistics -Identity $user.UserPrincipalName -Properties TotalItemSize
    $totalItemSize = [math]::Round(($userStats.TotalItemSize.ToString().Split('(')[1].Split(' ')[0].Replace(',','')/1MB),2)

    $percentFull = [math]::Round((($totalItemSize / $prohibitSendReceiveQuota) * 100), 2)

    if($percentFull -lt 80) { continue }

    #FullInboxMailingList += $user.UserPrincipalName

    [PSCustomObject]@{
        'Display Name' = $user.DisplayName
        'User Principal Name' = $user.UserPrincipalName
        'Mailbox Usage' = $percentFull
    }
}

Disconnect-ExchangeOnline -Confirm:$false

#If emailing users with alerts in future, use foreach loop with FullInboxMailingList


$exportData
$exportData | Export-Excel -Path "C:\Scripts\Reports\MailboxUsage.xlsx" -FreezeTopRow -AutoSize

#email information
$sender = "sender email here"
$recipient = "recipient email here"
#$ccrecipient = ""
#$bccrecipient = ""
$subject = "Monthly Mailbox Usage Report"
$body = "Attached is the mailbox usage information."
$attachmentpath = "C:\Scripts\Reports\MailboxUsage.xlsx"
$attachmentmessage = [Convert]::ToBase64String([IO.File]::ReadAllBytes($AttachmentPath))
$attachmentname = (Get-Item -Path $attachmentpath).Name
$type = "HTML" #Or you can choose "Text"
$save = "false" #Or you can choose "true"

$params = @{
    Message         = @{
        Subject       = $subject
        Body          = @{
            ContentType = $type
            Content     = $body
        }
        ToRecipients  = @(
            @{
                EmailAddress = @{
                    Address = $recipient
                }
            }
        )
        <#CcRecipients  = @(
            @{
                EmailAddress = @{
                    Address = $ccrecipient
                }
            }
        )#>
        <#BccRecipients = @(
            @{
                EmailAddress = @{
                    Address = $bccrecipient
                }
            }
        )#>
        Attachments   = @(
            @{
                "@odata.type" = "#microsoft.graph.fileAttachment"
                Name          = $attachmentname
                ContentType   = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                ContentBytes  = $attachmentmessage
            }
        )
    }
    SaveToSentItems = $save
}



#send the email
Connect-MgGraph -ClientId $appCred.UserName -TenantId $tenant -CertificateName $certCred.UserName

Send-MgUserMail -UserId $sender -BodyParameter $params

#Disconnect-MgGraph
Disconnect-MgGraph