<#
Written by: Tyler Applebaum
$Rev =  "v1.1 25 Aug 2014"
Usage: Remove-KasperskyDump.ps1 -l <Path_to_computer_list.txt> -f <Get-ADComputer filter (Can use single name too)>
#>
[CmdletBinding(DefaultParameterSetName = "Set1")]
    param(
        [Parameter(mandatory=$true, parametersetname="Set1", HelpMessage="Specify the path to the list of computer names (C:\Scripts\list.txt)")]
		[Alias("l")]
        [string]$Complist,

        [Parameter(mandatory=$true, parametersetname="Set2", HelpMessage="Specify the Get-ADComputer name filter to apply (Use * for wildcard")]
		[Alias("f")]
        [string]$Filter
    )

function script:Input {
	If ($Complist){
	#Get content of file specified, trim any trailing spaces and blank lines
	$script:Computers = gc ($Complist) | where {$_ -notlike $null } | foreach { $_.trim() }
	}
	Elseif ($Filter) {
	#Filter out AD computer objects with ESX in the name
	$script:Computers = Get-ADComputer -Filter {SamAccountName -notlike "*esx*" -AND Name -Like $Filter} | select -ExpandProperty Name | sort
	}
}#end Input

function script:PingTest {
$script:TestedComps = @()
	foreach ($WS in $Computers){
	$i++
		If (Test-Connection -count 1 -computername $WS -quiet){
		$script:TestedComps += $WS
		}
		Else {
		Write-Host "Cannot connect to $WS" -ba black -fo yellow
		}
	Write-Progress -Activity "Testing connectivity" -status "Tested connection to computer $i of $($computers.count)" -percentComplete ($i / $computers.length*100)
	}#end foreach
}#end PingTest

function script:Duration {
$Time = $((Get-Date)-$date)
	If ($Time.totalseconds -lt 60) {
	$dur = "{0:N3}" -f $Time.totalseconds
	Write-Host "Script completed in $dur seconds" -fo DarkGray
	}
	Elseif ($Time.totalminutes -gt 1) {
	$dur = "{0:N3}" -f $Time.totalminutes
	Write-Host "Script completed in $dur minutes" -fo DarkGray
	}
}#end Duration

$Scriptblock = {
	function script:RemoveDMP {
	$KasPath = "C:\Program Files (x86)\Kaspersky Lab\NetworkAgent\~dumps"
		If (Test-Path $KasPath){
		$FolderExistPre = $True
		$GetSize = $((gci $KasPath | Measure-Object -property length -sum))
		$DumpSize = "{0:N2}" -f ($GetSize.sum / 1MB) + " MB"
		Remove-Item $KasPath -recurse -force
			If(!(Test-Path $KasPath)){
			$IsDeleted = $True
			}
			Else {
			$IsDeleted = $False
			}
		$properties = @{
			FolderExists = $FolderExistPre
			DumpSize = $DumpSize
			Computer = $env:computername
			IsDeleted = $IsDeleted
		}
		$Obj = New-Object -TypeName PSObject -Property $properties
		$Results+= $Obj
		Write-Output $Results 
		}
	}#end RemoveDMP
. RemoveDMP
}#end Scriptblock

$AllResults = @()
$i = 0
$date = get-date
. Input #Call input function
. Pingtest #Call PingTest function
$Results = Invoke-Command -ComputerName $TestedComps -Scriptblock ${Scriptblock}
$AllResults += $Results #Add result to array
Write-Output $AllResults | fl
. Duration #Call duration function
$AllResults | Select Computer,FolderExists,DumpSize,IsDeleted | Export-CSV -Path "$Env:UserProfile\Desktop\Remove-KasperskyDumpResults.csv" -notypeinformation