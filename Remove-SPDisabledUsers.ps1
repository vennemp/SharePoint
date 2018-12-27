asnp *sharepoint*
ipmo *active*
$activeusers = Get-ADUser -Filter {Enabled -eq $true} -SearchBase "OU=Domain Users,DC=domain,DC=local"
$activeusershash = @{}
foreach ($activeuser in $activeusers)
    {
    $aduser = @{
        DistinguishedName = $activeuser.distinguishedname;
        Enabled = $activeuser.enabled;
        Name = $activeuser.Name;
        ObjectClass = $activeuser.objectclass;
        SamAccountname = $activeuser.SamAccountName;
               }
    $activeusershash.Add($activeuser.SamAccountName,$aduser)
    }
$allwebs = (get-spsite https://sharepoint.cfpb.local).allwebs | where {$_.hasuniqueroleassignments -eq $true}
$AD = Get-ADObject -filter * -properties distinguishedname,samaccountname | where {$_.samaccountname -ne $null}
$ADHash = @{}
foreach ($ADObject in $AD)
{
    $ADHashObject = @{
        DistinguishedName = $ADObject.DistinguishedName;
        Name = $ADObject.Name;
        ObjectClass = $ADObject.objectclass;
        SamAccountname = $ADObject.samaccountname
                     }
    $ADHash.Add($ADObject.samaccountname, $ADHashObject)
}
$removedusers = @()
function Remove-DisabledUsersFromWebs
    {
    foreach ($web in $allwebs)
    {
    Write-Host "In web: $($web.title)" -ForegroundColor DarkYellow
    $webroleassignments = $web.RoleAssignments | where {$_.roledefinitionbindings.name -ne "Limited Access" -and $_.member.loginname -like "i:0#.w|*"}
    #$webroleassignments.gettype()
        foreach ($webroleassignment in $webroleassignments)
        {
            Write-Host "Checking $($webroleassignment.member) in web: $($web.title)" -ForegroundColor DarkCyan
            $webusersam = $webroleassignment.Member.LoginName.Substring(12)            
            $webobjectDN = $ADhash[$webusersam]
                if ($activeusershash.values.samaccountname -notcontains $webusersam)
                {
                    if($webobjectDN.objectclass -eq "user" -and $webobjectDN.distinguishedname -notlike "*Mailbox*")
                    {
                    $webspuser = get-spuser $webroleassignment.Member.userlogin -web https://sharepoint.cfpb.local
                    $web.roleassignments.remove($webspuser)
                    $removeduser = [ordered]@{
                    UserName = $webspuser.displayname;
                    UserLogin = $webspuser.UserLogin;
                    URL = $web.url;
                    ObjectClass = $webobjectDN.objectclass;
                    DistinguishedName = $webobjectDN.distinguishedname;
                    ResourceType = "web";
                    ResourceName = $web.title
                                             }
                    $global:removedusers += New-Object -TypeName psobject -Property $removeduser
                    #Write-Output "Removed $($spuser.displayname) from web: $web" | Out-File $logfile -Append
                    Write-Host "Removed $($webspuser.displayname) from web: $web" -ForegroundColor DarkGreen
                                        }
                }
    
        }
    $web.update()
    $lists = $web.lists | where {$_.hasuniqueroleassignments -eq $true}
    "Starting lists for $($web.title)"
        foreach ($list in $lists)
        {
        Write-Host "In List: $($list.title)" -ForegroundColor Magenta
        $listroleassignments = $list.roleassignments | where {$_.roledefinitionbindings.name -ne "Limited Access" -and $_.member.loginname -like "i:0#.w|*"}
            foreach ($listroleassignment in $listroleassignments)
            {            
            Write-Host "Checking $($listroleassignment.member.loginname) in $($list.title)" -foregroundcolor darkcyan
            $listusersam = $listroleassignment.member.loginname.substring(12)
            $listobjectDN = $ADHash[$listusersam]
                if ($activeusershash.values.samaccountname -notcontains $listusersam)
                {
                    if($listobjectDN.objectclass -eq "user" -and $listobjectDN.distinguishedname -notlike "*Mailbox*")
                    {
                    $listspuser = get-spuser $listroleassignment.member.userlogin -Web https://sharepoint.cfpb.local
                    $list.roleassignments.remove($listspuser)
                    $removeduser = [ordered]@{
                    UserName = $listspuser.displayname;
                    UserLogin = $listspuser.UserLogin;
                    URL = "$($web.url)$($list.defaultviewurl)";
                    ObjectClass = $listobjectDN.objectclass;
                    DistinguishedName = $listobjectDN.distinguishedname;
                    ResourceType = "list";
                    ResourceName = $list.title
                                            }

                    $global:removedusers += New-object -typename psobject -property $removeduser
                    Write-Host "Removed $($listspuser.displayname) from List: $($list.title) in web: $($web.title)" -ForegroundColor DarkGreen                      
                    }
                }
                                       
            }
        $list.update()
        }
    $web.update()
    $web.dispose()
    }

}


function Remove-DisabledUsersfromGroups
{
$site = get-spsite https://sharepoint.cfpb.local
$groups = $site.RootWeb.SiteGroups | where {$_.name -notlike "CFPB Auto Group*"}
$groupcount = 1
    foreach ($group in $groups)
    {
    "Checking $($group.name). Group $groupcount of $($groups.count)"
    $groupcount++
    $groupusers = $group.users | ? {$_.userlogin -like "i:0#.w|*"}
        foreach ($member in $groupusers)
        {
        Write-Host "Checking $($member.displayname) in $($group.name)" -foregroundcolor darkcyan
        $membersamname = $member.userlogin.Substring(12)
        $memberobjectDN = $ADHash[$membersamname]
            if ($activeusershash.values.samaccountname -notcontains $membersamname)
            {
                if($memberobjectDN.objectclass -eq "user" -and $memberobjectDN.distinguishedname -notlike "*Mailbox*")
                {
                $groupspuser = get-spuser $member.userlogin -web https://sharepoint.cfpb.local
                $group.RemoveUser($groupspuser)
                $removeduser = [ordered]@{
                UserName = $member.displayname;
                UserLogin = $member.UserLogin;
                URL = "N/A";
                ObjectClass = $memberobjectDN.objectclass;
                DistinguishedName = $memberobjectDN.distinguishedname;
                ResourceType = "group";
                ResourceName = $group.name
                                         }
            $global:removedusers += New-object -typename psobject -property $removeduser
            Write-Host "$($member.displayname) removed from Group: $($group.Name)" -ForegroundColor DarkGreen
            
                }
            }
        }
    $group.update()
    }

}
Remove-DisabledUsersFromWebs
Remove-DisabledUsersfromGroups
$removedusers | Export-Csv -Path e:\temp\removedusers.csv -NoTypeInformation

Send-MailMessage -Body "Removed Users CSV Attached" -Attachments "e:\temp\removedusers.csv" -From SharePoint@domain.com v  -Priority High -To admin@do.com SmtpServer mailrelay.domain.local -Subject "Disabled Users Removal Report"
