#################################### Connection Section ###################################################
## log in with power bi admin account ##
$User = $username
$PWord = ConvertTo-SecureString -String $password -AsPlainText -Force
$UserCredential = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $User, $PWord
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
Import-PSSession $Session

#################################### EndConnection Section ###################################################

#################################### Configuration Section ###################################################
## Get the date of the last activity and log into SQL server, then get data between last activity and now ##

$GetLastActivity = "SELECT MAX(CreationTime) FROM [PowerBIAdminUsage]"
[DateTime]$start = Invoke-SQLcmd -ServerInstance $servername -query $GetLastActivity -U $SQLUsername -P $SQLPassword -Database $DBName 

##output data to csv to review the data in excel ##
$logFile = "\MyLog.txt"
$outputFile = "\AuditRecords.csv"

[DateTime]$start = $start
[DateTime]$end = Get-Date
$record = "PowerBI"
$resultSize = 1000
$intervalMinutes = 480
##  Interval minutes means the timespan the script is looking for activity  ##
$retryCount = 3
#################################### End Configuration Section ###################################################

#################################### Initializing Variables Section ###################################################
[DateTime]$currentStart = $start
[DateTime]$currentEnd = $start
$currentTries = 0
 
Function Write-LogFile ([String]$Message)
{
$final = [DateTime]::Now.ToString() + ":" + $Message
$final | Out-File $logFile -Append
}
 
while ($true)
{
$currentEnd = $currentStart.AddMinutes($intervalMinutes)
if ($currentEnd -gt $end)
{
break
}
$currentTries = 0
$sessionID = [DateTime]::Now.ToString().Replace('/', '_')
Write-LogFile "INFO: Retrieving audit logs between $($currentStart) and $($currentEnd)"
$currentCount = 0
while ($true)

#################################### End Initializing Variables Section ###################################################

#################################### Run Operation Section ###################################################
{
[Array]$results = Search-UnifiedAuditLog -StartDate $currentStart -EndDate $currentEnd -RecordType $record -SessionId $sessionID -SessionCommand ReturnLargeSet -ResultSize $resultSize
if ($results -eq $null -or $results.Count -eq 0)

{
#Retry if needed. This may be due to a temporary network glitch
if ($currentTries -lt $retryCount)
{
$currentTries = $currentTries + 1
continue
}
else
{
Write-LogFile "WARNING: Empty data set returned between $($currentStart) and $($currentEnd). Retry count reached. Moving forward!"
break
}
}
$currentTotal = $results[0].ResultCount
if ($currentTotal -gt 5000)
{
Write-LogFile "WARNING: $($currentTotal) total records match the search criteria. Some records may get missed. Consider reducing the time interval!"
}
$currentCount = $currentCount + $results.Count
Write-LogFile "INFO: Retrieved $($currentCount) records out of the total $($currentTotal)"

$data = @()

foreach ($auditlogitem in $results) {
    $datum = New-Object –TypeName PSObject
    $d=convertfrom-json $auditlogitem.AuditData
    $datum | Add-Member –MemberType NoteProperty –Name Id –Value $d.Id
    $datum | Add-Member –MemberType NoteProperty –Name CreationTime –Value $auditlogitem.CreationDate
    $datum | Add-Member –MemberType NoteProperty –Name Operation –Value $d.Operation
    $datum | Add-Member –MemberType NoteProperty –Name UserType –Value $d.UserType
    $datum | Add-Member –MemberType NoteProperty –Name UserKey –Value $d.UserKey
    $datum | Add-Member –MemberType NoteProperty –Name UserId –Value $d.UserId
    $datum | Add-Member –MemberType NoteProperty –Name ClientIP –Value $d.ClientIP
    $datum | Add-Member –MemberType NoteProperty –Name UserAgent –Value $d.UserAgent
    $datum | Add-Member –MemberType NoteProperty –Name WorkSpaceName –Value $d.WorkSpaceName
    $datum | Add-Member –MemberType NoteProperty –Name DashboardName –Value $d.DashboardName
    $datum | Add-Member –MemberType NoteProperty –Name DatasetName –Value $d.DatasetName
    $datum | Add-Member –MemberType NoteProperty –Name ReportName –Value $d.ReportName
    $datum | Add-Member –MemberType NoteProperty –Name WorkspaceId –Value $d.WorkspaceId
    $datum | Add-Member –MemberType NoteProperty –Name DatasetId –Value $d.DatasetId
    $datum | Add-Member –MemberType NoteProperty –Name ReportId –Value $d.ReportId
 
    ## follow the convention above to add columns or remove lines to omit columns from the auditlog ##
    
    #option to include the below JSON column however for large amounts of data it may be difficult for PBI to parse
    #$datum | Add-Member –MemberType NoteProperty –Name Datasets –Value (ConvertTo-Json $d.Datasets)
 
    foreach ($dataset in $d.datasets) {
        $datum.DatasetName = $dataset.DatasetName
        $datum.DatasetId = $dataset.DatasetId
    }
    $data+=$datum
}

## when the results are outputted ##

$data | epcsv $outputFile -NoTypeInformation -Append

if ($currentTotal -eq $results[$results.Count - 1].ResultIndex)
{
$message = "INFO: Successfully retrieved $($currentTotal) records for the current time range. Moving on!"
Write-LogFile $message
break
}
}
$currentStart = $currentEnd
}
Remove-PSSession $Session

#################################### End Run Operation Section ###################################################

foreach($row in $data) 
{ 
    $Id = $row.Id
    $CreationTime = $row.CreationTime
    $Operation = $row.Operation
    $UserType = $row.UserType
    $UserKey = $row.UserKey
    $UserId = $row.UserId
    $ClientIP = $row.ClientIP

## if there's single quotations anywhere they can't be inserted into the database, so they need to be replaced ###
    $UserAgent = if (-not ([string]::IsNullOrEmpty($row.UserAgent)))
    {
        $row.UserAgent.replace("'","''")
    }
    $WorkSpaceName = if (-not ([string]::IsNullOrEmpty($row.WorkSpaceName)))
    {
        $row.WorkSpaceName.replace("'","''")
    }
    $DashboardName = if (-not ([string]::IsNullOrEmpty($row.DashboardName)))
    {
        $row.DashboardName.replace("'","''")
    }
    $DatasetName = if (-not ([string]::IsNullOrEmpty($row.DatasetName)))
    {
        $row.DatasetName.replace("'","''")
    }
    $ReportName = if (-not ([string]::IsNullOrEmpty($row.ReportName)))
    {
        $row.ReportName.replace("'","''")
    }
    $WorkspaceId = $row.WorkspaceId
    $DatasetId = $row.DatasetId
    $ReportId = $row.ReportId


    
 
$insertquery=" 
INSERT INTO [dbo].[PowerBIAdminUsage] 
           (Id,
           CreationTime,
           Operation,
           UserType,
           UserKey,
           UserId,
           ClientIP,
           UserAgent,
           WorkSpaceName,
           DashboardName,
           DatasetName,
           ReportName,
           WorkspaceId,
           DatasetId,
           ReportId
           ) 
     VALUES 
           ('$Id',
           '$CreationTime',
           '$Operation',
           '$UserType',
           '$UserKey',
           '$UserId',
           '$ClientIP',
           '$UserAgent',
           '$WorkSpaceName',
           '$DashboardName',
           '$DatasetName',
           '$ReportName',
           '$WorkspaceId',
           '$DatasetId',
           '$ReportId'           
                   
           ) 
GO 
" 
 
Invoke-SQLcmd -ServerInstance $servername -query $insertquery -U $SQLUsername -P $SQLPassword -Database $DBName 
 
}
