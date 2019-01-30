Add-PSSnapin "Microsoft.SharePoint.PowerShell"
$logfile = "e:\temp\workflowgroups.txt"
$csv = import-csv -Path "E:\GroupsforWorkflows.csv"
$groupsinworkflow = @()
$errors = @()
Function GetXOMLFromWorkflowInstance($wfa)
{
clv xmlstring
    [xml]$xmldocument =  $wfa.SoapXml
    $name = $wfa.Name
    $wfName = $name.Replace(" ", "%20")
    $webRelativeFolder = "Workflows1/" + $wfName
    $xomlFileName = $wfName + ".xoml"

    $wfFolder = $wfa.ParentWeb.GetFolder($webRelativeFolder)

    $xomlFile = $wfFolder.Files[$xomlFileName]
    if ($xomlFile.Exists)
    {
        try
        {$xomlbin = $xomlFile.OpenBinary()
        $encode = New-Object System.Text.ASCIIEncoding
        $xmlstring = $encode.GetString($xomlbin)
        
        return $xmlstring
        }
        catch
        {Write-Host "Error $($wfa.name) $($wfa.ParentList) $($wfa.ParentWeb)" -ForegroundColor Red
        $props = [ordered]@{
        Workflow = $wfa.name;
        Parentweb = $wfa.ParentWeb;
        Parentlist = $wfa.ParentList;
        Author = $wfa.author
         }     
        }
        $global:errors += New-object -TypeName psobject -Property $props
    }
    else {
    $webRelativeFolder = "Workflows1/" + $wfName
    $xomlFileName = $wfName + ".xoml"

    $wfFolder = $wfa.ParentWeb.GetFolder($webRelativeFolder)
    try {
    $xomlFile = $wfFolder.Files[$xomlFileName]
    $xomlbin = $xomlFile.OpenBinary()
    $encode = New-Object System.Text.ASCIIEncoding
    $xmlstring = $encode.GetString($xomlbin)
              }
        catch
        {Write-Host "Error $($wfa.name) $($wfa.ParentList) $($wfa.ParentWeb)" -ForegroundColor Red
        $props = [ordered]@{
        Workflow = $wfa.name;
        Parentweb = $wfa.ParentWeb;
        Parentlist = $wfa.ParentList;
        Author = $wfa.author
        }      
        }
        $global:errors += New-object -TypeName psobject -Property $props
        }  
        return $xmlstring
    }

    #return $xomlFileName


Function CheckAllWFXoml ($webUrl, $listName)
{
if ($xml){clv xml}
    #$site = Get-SPSite($webUrl)
    $web = get-spweb $weburl
    $wfaColl = $web.lists[$listname].WorkflowAssociations | ? {$_.name -notlike "*Previous*"}

    Foreach ($i in $wfaColl)
        {
        $xml = GetXOMLFromWorkflowInstance $i
        #$xml
            foreach ($group in $csv.groups) 
            {
            "Checking $($group) $($web.title) $($list.title) $($i.name)"
                if (Select-String -SimpleMatch "$($group)" -InputObject $xml -Quiet)
                {
                write-host "Found $($group) in $($i.name)" -ForegroundColor Green
                Write-Output "Found $($group) in $($i.name)" >> $logfile
                    $wfprops = [ordered]@{
                    Group = $group;
                    WFName = $i.name;
                    List = $i.parentlist;
                    Web = $i.parentweb
                }
                $global:groupsinworkflow +=New-Object -TypeName psobject -Property $wfprops
            }
            }
        }
}

$webs = (get-spsite https://sharepoint.domain.local).allwebs

foreach ($web in $webs)
{
"WEB: $($web.title)"
    $lists = $web.lists | ? {$_.workflowassociations}
    foreach ($list in $lists)
    {
    "LIST: $($list.title)"
    CheckAllWFXoml $web.url $list.title
    }
}
