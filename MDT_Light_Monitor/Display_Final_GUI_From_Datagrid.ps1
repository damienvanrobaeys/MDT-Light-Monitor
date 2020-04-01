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

#************************************************************************** IMPORT MDT MODULE ******************************************************************************************************

$Global:URL = "http://" + $Host_Monitor + ":9801/MDTMonitorData/Computers/"					

Write-Host "##############################################################################" -ForegroundColor Cyan 
Write-Host "Deployment statut analyzer" -ForegroundColor yellow 
Write-Host "The script is analyzing the deployment of the following computer: $MyComputer" -ForegroundColor yellow 
Write-Host "Do not close this script !!!" -ForegroundColor yellow 
Write-Host "Once deployment is finished a GUI will e displayed" -ForegroundColor yellow 
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

function rrrrrr
{
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
				$Global:Main_Text = "Deployment unresponsive"
				$Global:Low_Text = "$MyComputer is unresponsive - $(get-date)"		
				$Global:Percent_Status = $Get_Monitoring.percentcomplete 	
				cd $Current_Folder
				powershell -sta ".\Monitoring_End_Notification.ps1" -MainText "'$global:Main_Text'" -LowText "'$global:Low_Text'" -PercentStatus "'$global:Percent_Status'" 										
				break	
	
			}

		ElseIf ($Deployment_Status -eq 3)		
			{			

				$Global:Main_Text = "Deployment completed"
				$Global:Low_Text = "$MyComputer is now ready - $(get-date)"			
				$Global:Percent_Status = "100"		
				cd $Current_Folder
				powershell -sta ".\Monitoring_End_Notification.ps1" -MainText "'$global:Main_Text'" -LowText "'$global:Low_Text'" -PercentStatus "'$global:Percent_Status'" 										
				break	
			}	
			
		ElseIf ($Deployment_Status -eq 2)		
			{			
				$Global:Main_Text = "Deployment failed"
				$Global:Low_Text = "An error occured on $Computer_Name - $(get-date)"
				$Global:Percent_Status = $Get_Monitoring.percentcomplete		
				cd $Current_Folder
				powershell -sta ".\Monitoring_End_Notification.ps1" -MainText "'$global:Main_Text'" -LowText "'$global:Low_Text'" -PercentStatus "'$global:Percent_Status'" 										
				break	
			}				
	} 
While ($MyData.Percent_Complete	 -lt "100") 
write-host "Deployment finished"

}	
	
		
rrrrrr

