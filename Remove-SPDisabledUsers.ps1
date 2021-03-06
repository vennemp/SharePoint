<#
This scripts builds a hash table of every active user and every object in your AD.
This script loops thru every site, list/library, and Group in a site collection and checks to see if the user is is in the active user hash
If it isn't it checks it against AD to see if it a user object in AD and removes it from the permissions list is not an active user object.  It will ignore 
AD groups, mailboxes etc.  Make sure you understand your domain before implementing this. It builds a record of who is removed and emails it to an admin

Highly recommend you comment out each remove user command and run first just to see who would be removed.  


#>

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
$allwebs = (get-spsite https://sharepoint.domain.local).allwebs | where {$_.hasuniqueroleassignments -eq $true}
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
        foreach ($webroleassignment in $webroleassignments)
        {
            Write-Host "Checking $($webroleassignment.member) in web: $($web.title)" -ForegroundColor DarkCyan
            $webusersam = $webroleassignment.Member.LoginName.Substring(12)            
            $webobjectDN = $ADhash[$webusersam]
                if ($activeusershash.values.samaccountname -notcontains $webusersam)
                {
                    if($webobjectDN.objectclass -eq "user")
                    {
                    $webspuser = get-spuser $webroleassignment.Member.userlogin -web https://sharepoint.domain.local
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
                    if($listobjectDN.objectclass -eq "user")
                    {
                    $listspuser = get-spuser $listroleassignment.member.userlogin -Web https://sharepoint.domain.local
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
$site = get-spsite https://sharepoint.domain.local
$groups = $site.RootWeb.SiteGroups
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
                if($memberobjectDN.objectclass -eq "user")
                {
                $groupspuser = get-spuser $member.userlogin -web https://sharepoint.domain.local
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
