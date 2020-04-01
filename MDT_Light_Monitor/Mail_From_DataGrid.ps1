#================================================================================================================
#
# Script Part    : MDT Monitoring series
# Script purpose : MDT Loght Monitor Tool
# Author 		 : Damien VAN ROBAEYS
# Twitter 		 : https://twitter.com/syst_and_deploy
# Blog 		     : http://www.systanddeploy.com/
#
#================================================================================================================


#******************************************************************** LOAD PARAMETERS FROM Notifications_AreaResume_GUI.PS1 ***************************************************************************
Param
 (
	[String]$Host_Monitor,	
	[String]$MyComputer
 )

$Global:Current_Folder =(get-location).path 
									
#************************************************************************** GET MONITORING INFOS FROM XML ******************************************************************************************************		
$Progdata = $env:PROGRAMDATA
$Global:List_XML_Content = "$Progdata\Monitoring_Infos.xml"						
$Input_XML = [xml] (Get-Content $List_XML_Content)	 
foreach ($infos in $Input_XML.selectNodes("Mail_Infos"))		
	{
		$Global:Mail_SMTP = $infos.SMTP			
		$Global:Mail_From = $infos.MailFrom			
		$Global:Mail_To = $infos.MailTo			
	}		

#************************************************************************** IMPORT MDT MODULE ******************************************************************************************************

$Global:URL = "http://" + $Host_Monitor + ":9801/MDTMonitorData/Computers/"					


$host.ui.RawUI.WindowTitle = "Deployment statut analyzer"

Write-Host "##############################################################################" -ForegroundColor Cyan 
Write-Host "Deployment statut analyzer" -ForegroundColor yellow 
Write-Host "The script is analyzing the deployment of the following computer: $MyComputer" -ForegroundColor yellow 
Write-Host "Do not close this script !!!" -ForegroundColor yellow 
Write-Host "Once deployment is finished you'll receive a mail" -ForegroundColor yellow 
Write-Host "$Mail_SMTP" -ForegroundColor yellow 
Write-Host "$Mail_From" -ForegroundColor yellow 
Write-Host "$Mail_To" -ForegroundColor yellow 
Write-Host "$URL" -ForegroundColor yellow 
Write-Host "##############################################################################" -ForegroundColor Cyan 


function GetMDTData { 
  $Data = Invoke-RestMethod $URL
  foreach($property in ($Data.content.properties)) 
  { 
		$Percent = $property.PercentComplete.'#text' 		
		$Current_Steps = $property.CurrentStep.'#text'			
		$Total_Steps = $property.TotalSteps.'#text'		
		
		$Step_Name = $property.StepName		
		If ($Percent -eq 100)
			{
				$Global:StepName = "Deployment finished"
				$Percent_Value = $Percent + "%"				
			}
		Else
			{
				If ($Step_Name -eq "")
					{					
						If ($Percent -gt 0) 					
							{
								$Global:StepName = "Computer restarted"
								$Percent_Value = $Percent + "%"
							}	
						Else							
							{
								$Global:StepName = "Deployment not started"	
								$Percent_Value = "Not started"	
							}

					}
				Else
					{
						$Global:StepName = $property.StepName		
						$Percent_Value = $Percent + "%"					
					}					
			}

		$Deploy_Status = $property.DeploymentStatus.'#text'					
		If (($Percent -eq 100) -and ($Step_Name -eq "") -and ($Deploy_Status -eq 1))
			{
				$Global:StepName = "Running in PE"						
			}			
			
			
		$End_Time = $property.EndTime.'#text' 	
		If ($End_Time -eq $null)
			{
				If ($Percent -eq $null)
					{									
						$EndTime = "Not started"
						$Ellapsed = "Not started"												
					}
				Else
					{
						$EndTime = "Not finished"
						$Ellapsed = "Not finished"					
					}
			}
		Else
			{
				$EndTime = ([datetime]$($property.EndTime.'#text')).ToLocalTime().ToString('HH:mm:ss')  	 
				$Ellapsed = new-timespan -start ([datetime]$($property.starttime.'#text')).ToString('HH:mm:ss') -end ([datetime]$($property.endTime.'#text')).ToString('HH:mm:ss'); 				
			}
	
    New-Object PSObject -Property @{ 
      ComputerName = $($property.Name); 
      Percent_Complete = $Percent_Value; 	  
      Step_Name = $StepName;	  	  
      Actual_Step = $property.CurrentStep.'#text'	 	  
      All_my_Steps = $property.TotalSteps.'#text'		  
      Warnings = $($property.Warnings.'#text'); 	  
      Errors = $($property.Errors.'#text'); 	  
      ID = $($property.ID.'#text'); 
      LastTime = $($property.LastTime.'#text'); 
      DeploymentStatus = $($property.DeploymentStatus.'#text'); 	  
      "Deployment Status" = $( 
        Switch ($property.DeploymentStatus.'#text') { 
        1 { "Running" } 
        2 { "Failed" } 
        3 { "Success" } 
        4 { "Unresponsive" } 		
        Default { "Unknown" } 
        } 
      ); 	  
      "Date" = $($property.StartTime.'#text').split("T")[0]; 
      Start_time = ([datetime]$($property.StartTime.'#text')).ToLocalTime().ToString('HH:mm:ss')  
	  End_time = $EndTime;
      Ellapsed_time = $Ellapsed;	  	  
    } 
  } 
}


$Global:MyData = GetMDTData | Select Date, ComputerName, Actual_Step, All_my_Steps, LastTime, Percent_Complete, Step_Name, Warnings, Errors, Start_time, End_time, Ellapsed_time, DeploymentStatus, "Deployment Status" | where {$_.ComputerName -eq $MyComputer}	

Do
	{			
		$Deployment_Status = $MyData.DeploymentStatus		
		$Deployment_Date = $MyData.Date
		$Deployment_CompName = $MyData.ComputerName
		$Deployment_LastTime = $MyData.LastTime
		$Deployment_StepName = $MyData.Step_Name
		$Deployment_Warnings = $MyData.Warnings
		$Deployment_Errors = $MyData.Errors
		$Deployment_Percent_Complete = $MyData.Percent_Complete		
		$Deployment_Start_time = $MyData.Start_time		
		$Deployment_End_time = $MyData.End_time
		$Deployment_Ellapsedtime = $MyData.Ellapsed_time

		 If ($Deployment_Status -eq 4)
		 
		 # It means if deploymebntstatus equals unresponsive (not answzer for the past four hours)
			{
				$Body = "<p><span>Hello,<br><br>
				Operating System deployment <strong><span style=color:red>is unresponsive</span></strong> on the computer: <span style=color:blue><strong>$Deployment_CompName</strong></span> - $(get-date)
				<br><br>
				<span style=color:black>
				See below some informations about your deployment :
				<br><br>
				<strong>Computer name: </strong>$Deployment_CompName
				<br>
				<strong>Start time: </strong>$Deployment_Start_time
				<br>
				<strong>Last time: </strong>$Deployment_LastTime
				<br>
				<strong>Warning: </strong>$Deployment_Warnings
				<br>
				<strong>Error: </strong>$Deployment_Errors
				<br>
				<strong>Step name: </strong>$Deployment_StepName
				<br>	
				<strong>Percent: </strong>$Deployment_Percent_Complete
				<br>					
				<strong>Deployment Share: </strong>$DeploymentSharePath 
				<br><br>
				Best regards
				</span>
				</span></p>"											
				send-mailmessage -from "$Mail_From" -to "$Mail_To" -subject "MDT Monitoring status: Unresponsive - On $Deployment_CompName" -body $Body -BodyAsHtml  -priority Normal -smtpServer $Mail_SMTP									
			break		
			}

		ElseIf ($Deployment_Status -eq 3)		
			{			
				$Body = "<p><span>Hello,<br><br>
				Operating System deployment <strong><span style=color:green>completed successfully</span></strong> on the computer: <span style=color:blue><strong>$Deployment_CompName</strong></span> - $(get-date)
				<br><br>
				<span style=color:black>
				See below some informations about your deployment :
				<br><br>
				<strong>Computer name: </strong>$Deployment_CompName
				<br>
				<strong>Start time: </strong>$Deployment_Start_time
				<br>
				<strong>End time: </strong>$Deployment_End_time
				<br>
				<strong>Elapsed time: </strong>$Elapsed
				<br>						
				<strong>Warning: </strong>$Deployment_Warnings
				<br>
				<strong>Error: </strong>$Deployment_Errors					
				<br><br>
				Best regards
				</span>
				</span></p>"		
				send-mailmessage -from "$Mail_From" -to "$Mail_To" -subject "MDT Monitoring status: Success - On $Deployment_CompName" -body $Body -BodyAsHtml  -priority Normal -smtpServer $Mail_SMTP				
			break
			}	
			
		ElseIf ($Deployment_Status -eq 2)		
			{			
				$Body = "<p><span>Hello,<br><br>
				Operating System deployment <strong><span style=color:red>failed</span></strong> on the computer: <span style=color:blue><strong>$Deployment_CompName</strong></span> - $(get-date)
				<br><br>
				<span style=color:black>
				See below some informations about your deployment :
				<br><br>
				<strong>Computer name: </strong>$Deployment_CompName
				<br>
				<strong>Start time: </strong>$Deployment_Start_time
				<br>
				<strong>Last time: </strong>$Deployment_End_time
				<br>
				<strong>Warning: </strong>$Deployment_Warnings
				<br>
				<strong>Error: </strong>$Deployment_Errors
				<br>
				<strong>Step name: </strong>$Deployment_StepName
				<br>	
				<strong>Percent: </strong>$Deployment_Percent_Complete
				<br><br>
				Best regards
				</span>
				</span></p>"					
				send-mailmessage -from "$Mail_From" -to "$Mail_To" -Cc "$Mail_CC" -subject "MDT Monitoring status: Failed - On $Deployment_CompName" -body $Body -BodyAsHtml  -priority Normal -smtpServer $Mail_SMTP			
				break
			}				
	} 
	
While ($MyData.Percent_Complete	 -lt 100) 
write-host "Deployment finished"



	
	
	
	


