$clientId = "{clientIdHere}"
$tenantId = "{tenantIdHere}"
$certificate = "{CertSubjectHere}"

Connect-MgGraph -ClientId $clientId -TenantId $tenantId -CertificateName $certificate

$thresholdDays = 60

#select what user parameters you need
$users = Get-MgUser -all -Select "displayName,signInActivity,userPrincipalName,givenName,surname"
$currentDate = Get-Date

#create the cutoff date (no need to re-format currently)
$currentDate = $currentDate.AddDays(-$thresholdDays)#.ToString("MM/dd/yyyy hh:ss:mm")

#array of objects used to create Excel doc
$exportData = foreach($user in $users) {
    
    #check against their last sign-in date and if they have an active license. if not, skip one loop
    if(($user.SignInActivity.LastSignInDateTime -le $currentDate) -and ($user.SignInActivity.LastSignInDateTime -ne $null)) {
        $userLicense = Get-MgUserLicenseDetail -UserId $user.id
        if($userLicense -eq $null) { continue }

        #Skip certain users by displayName
        if(($user.displayName -eq 'exampleUser1') -or ($user.displayName -eq 'exampleUser2')) { continue }

        #array to convert license names as they appear in Entra ID
        $readableLicenseName = @()
        foreach($license in $userLicense.SkuPartNumber) {
            if($license -eq 'O365_BUSINESS_PREMIUM') {
                $readableLicenseName += 'Microsoft 365 Business Standard'
              }
            elseif($license -eq 'EXCHANGESTANDARD') {
                $readableLicenseName += 'Exchange Online (Plan 1)'
            }
            elseif($license -eq 'FLOW_FREE') {
                $readableLicenseName += 'Microsoft Power Automate Free'
            }
        }

        #store all necessary data into the object
        [PSCustomObject]@{
            'Display Name' =  $user.displayName
            'First Name' = $user.givenName
            'Last Name' = $user.surname
            Licenses = $readableLicenseName -join '+'
            'User principal name' = $user.UserPrincipalName
            'Last Sign In' = $user.SignInActivity.LastSignInDateTime
        }
    }

}

#create the Excel document with autosize
$exportData
$exportData | Export-Excel -Path "C:\path\to\Filename.xlsx" -FreezeTopRow -AutoSize

#email information
$sender = "{sender here}"
$recipient = "{recipient here}"
#$ccrecipient = ""
#$bccrecipient = ""
$subject = "Inactive User Report"
$body = "{Message Body Here}"
$attachmentpath = "C:\path\to\Filename.xlsx"
$attachmentBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($AttachmentPath))
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
                ContentBytes  = $attachmentBytes
            }
        )
    }
    SaveToSentItems = $save
}

#send the email
Send-MgUserMail -UserId $sender -BodyParameter $params

Disconnect-MgGraph