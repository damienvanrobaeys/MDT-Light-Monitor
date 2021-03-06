#================================================================================================================
#
# Script Part    : MDT Monitoring series
# Script purpose : MDT Light Monitor Tool
# Author 		 : Damien VAN ROBAEYS
# Twitter 		 : https://twitter.com/syst_and_deploy
# Blog 		     : http://www.systanddeploy.com/
#
#================================================================================================================

param(
	[String]$Date,
	# [String]$Host,
	[String]$DeployShare,
	[String]$ModulePath,	
	[String]$position,
	[String]$ID,	
	[String]$name,
	[String]$status,
	[String]$step,	
	[String]$Percentage,
	[String]$Start,	
	[String]$End,	
	[String]$LastTime,	
	[String]$TotalTime,
	[String]$CurrentStep,		
	[String]$TotalStep,	
	[String]$Status_Step,	
	[String]$ErrorNB,	
	[String]$WarningNB,		
	[String]$DART_IP,	
	[String]$Dart_Port,		
	[String]$Dart_Ticket,	
	[String]$VM_Host,
	[String]$hoste,		
	[String]$VM_Name	
	)

	
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') | out-null
[System.Reflection.Assembly]::LoadFrom('assembly\MahApps.Metro.dll')       | out-null

function LoadXml ($global:filename)
{
    $XamlLoader=(New-Object System.Xml.XmlDocument)
    $XamlLoader.Load($filename)
    return $XamlLoader
}

# Load MainWindow
$XamlMainWindow=LoadXml("Properties.xaml")
$Reader=(New-Object System.Xml.XmlNodeReader $XamlMainWindow)
$Form=[Windows.Markup.XamlReader]::Load($Reader)

########################################################################################################################################################################################################	
#*******************************************************************************************************************************************************************************************************
# 																		BUTTONS AND LABELS INITIALIZATION 
#*******************************************************************************************************************************************************************************************************
########################################################################################################################################################################################################

#************************************************************************** DEPLOYMENTSHARE DETAILS PART  ***********************************************************************************************
$Comp_ID = $Form.findname("Comp_ID") 
$Comp_Name = $Form.findname("Comp_Name") 
$Deployment_Status = $Form.findname("Deployment_Status") 
$NB_Error = $Form.findname("NB_Error") 
$NB_Warning = $Form.findname("NB_Warning") 

#************************************************************************** DEPLOYMENTSHARE PROGRESS PART  ***********************************************************************************************
$Step_Name = $Form.findname("Step_Name") 
$ProgressBar_Value = $Form.findname("ProgressBar_Value") 
$Step_Evolution = $Form.findname("Step_Evolution") 
$Start_Time = $Form.findname("Start_Time") 
$End_Time = $Form.findname("End_Time") 
$Elapsed_Time = $Form.findname("Elapsed_Time") 

#************************************************************************** MORE OPTIONS BUTTON  ***********************************************************************************************
$More_Options = $Form.findname("More_Options")

#************************************************************************** FLYOUT CONTENT CONTROLS PART  ***********************************************************************************************
$FlyOutContent = $Form.findname("FlyOutContent")
$View_logs = $Form.findname("View_logs") 
$Remote_connection = $Form.findname("Remote_connection") 
$UserName_txtbox_log = $Form.findname("UserName_txtbox_log")
$Password_Txtbox_log = $Form.findname("Password_Txtbox_log")
$Remote_Connect = $Form.findname("Remote_Connect")

$Notification_End = $Form.findname("Notification_End")
$Notification_End_Warning = $Form.findname("Notification_End_Warning")
$Notify_me = $Form.findname("Notify_me")
$Notification_Mail = $Form.findname("Notification_Mail")


########################################################################################################################################################################################################	
#*******************************************************************************************************************************************************************************************************
#																		 VARIABLES DEFINITION 
#*******************************************************************************************************************************************************************************************************
########################################################################################################################################################################################################		
		
$object = New-Object -comObject Shell.Application  

$Comp_ID.Content = $id
$Comp_Name.Content = $name
$Deployment_Status.Content = $status
$Start_Time.Content = $Start
$End_Time.Content = $End
$NB_Error.Content = $ErrorNB
$NB_Warning.Content = $WarningNB

$View_Percent = $Percentage.Replace("%","")
$Step_Name.Content = $step

If ($ErrorNB -ne "0")
	{
		$NB_Error.ForeGround = "Red"
		$NB_Error.FontWeight = "Bold"		
	}

If ($WarningNB -ne "0")
	{
		$NB_Warning.ForeGround = "Red"
		$NB_Warning.FontWeight = "Bold"		
	}


$Step_Evolution.Content = "Step $Status_Step"
$ProgressBar_Value.Value = $View_Percent
$Elapsed_Time.Content = $TotalTime

$More_Options.Add_Click({
    $FlyOutContent.IsOpen = $true   
})

$View_Logs.Add_Click({

	$Log_Path = "\\$name\c$\"
	$out = net use $Log_Path /user:$Remote_User $Remote_User_Password 2>$1
	If ($lastexitcode -ne 0) 
		{
			write-host "oops $out"
		}
	
	If (test-path $Log_Path)
		{
			explorer $Log_Path			
		}
	Else
		{
			$Test_Connection.Content = "Connection KO"
			$Test_Connection.Foreground = "Red"			
		}			
})


$Remote_Connect.Add_Click({
	$cmd = "mstsc.exe /v:$name"
	Invoke-Expression $cmd
})



				
$Notify_me.Add_Click({

	If (($Notification_End_Warning.IsChecked -eq $false) -and ($Notification_Mail.IsChecked -eq $false))
		{
			[MahApps.Metro.Controls.Dialogs.DialogManager]::ShowMessageAsync($Form, "Oops :-(", "Please select a notification mode")				

		}
	Else
		{
			If (($Notification_End_Warning.IsChecked -eq $true) -or ($Notification_Mail.IsChecked -eq $true))
				{					
					If ($Notification_End_Warning.IsChecked -eq $true)
						{
							$Global:DisplayGUI=$true
						}
					Else
						{
							$Global:DisplayGUI=$false
						}				
				
					If ($Notification_Mail.IsChecked -eq $true)
						{
							$Global:SendMail=$true
						}
					Else
						{
							$Global:SendMail=$false
						}		

					$okAndCancel = [MahApps.Metro.Controls.Dialogs.MessageDialogStyle]::AffirmativeAndNegative	
					$settings = [MahApps.Metro.Controls.Dialogs.MetroDialogSettings]::new()
					$result = [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Are you sure ?","Notification will be displayed in case of success or error.`n`nDon't close the script",$okAndCancel, $settings)			
					
					switch ($result)
					{
						"Affirmative" 
						{
							start-process powershell.exe ".\MonitoringData_Deploy_Analyze.ps1 '$MyComputer' '$Hoste' '$DeployShare' '$status' '$step' '$Percentage' '$Start' '$End' '$Elapsed' '$ErrorNB' '$WarningNB' '$LastTime' '$Mail' '$GUI' " 																
						}
					}
				}					
		}



})

$Form.ShowDialog() | Out-Null