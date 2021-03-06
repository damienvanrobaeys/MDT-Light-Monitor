#================================================================================================================
#
# Script Part    : MDT Monitoring series
# Script purpose : MDT Light Monitor Tool
# Author 		 : Damien VAN ROBAEYS
# Twitter 		 : https://twitter.com/syst_and_deploy
# Blog 		     : http://www.systanddeploy.com/
#
#================================================================================================================


[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')  				| out-null
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') 				| out-null
[System.Reflection.Assembly]::LoadFrom('assembly\MahApps.Metro.dll')       				| out-null

function LoadXml ($global:filename)
{
    $XamlLoader=(New-Object System.Xml.XmlDocument)
    $XamlLoader.Load($filename)
    return $XamlLoader
}

# Load MainWindow
$XamlMainWindow=LoadXml("MDT_Monitor_Main.xaml")
$Reader=(New-Object System.Xml.XmlNodeReader $XamlMainWindow)
$Form=[Windows.Markup.XamlReader]::Load($Reader)

########################################################################################################################################################################################################	
#*******************************************************************************************************************************************************************************************************
# 																		BUTTONS AND LABELS INITIALIZATION 
#*******************************************************************************************************************************************************************************************************
########################################################################################################################################################################################################

#************************************************************************** DATAGRID *******************************************************************************************************************
$DataGrid_Monitoring = $form.FindName("DataGrid_Monitoring")
#************************************************************************** TAB CONTROL ****************************************************************************************************************
$Tab_Control = $form.FindName("Tab_Control")
#************************************************************************** ACTIONS PART BUTTONS *******************************************************************************************************
$Refresh_Once = $Form.findname("Refresh_Once") 
$Remove_btn = $Form.findname("Remove_btn") 
$Properties_btn = $Form.findname("Properties_btn") 
$Start_Stop_Timer = $Form.findname("Start_Stop_Timer") 
$Toggle_Host_Remember = $Form.findname("Toggle_Host_Remember") 
$Search_Host = $Form.findname("Search_Host") 

$Monitoring_host_txtbox = $Form.findname("Monitoring_host_txtbox") 
$Export_To_Excel = $Form.findname("Export_To_Excel") 

########################################################################################################################################################################################################	
#*******************************************************************************************************************************************************************************************************
#																		 VARIABLES DEFINITION 
#*******************************************************************************************************************************************************************************************************
########################################################################################################################################################################################################

$User = $env:USERPROFILE
$ProgData = $env:PROGRAMDATA
$Date = get-date -format "dd-MM-yy_HHmm"
$Global:Current_Folder =(get-location).path 
$object = New-Object -comObject Shell.Application  

$Global:List_Monitoring_Host = "$ProgData\Monitoring_Host.txt"	
$Test_Monitoring_Host = test-path $List_Monitoring_Host


function GetMDTData { 
  $Data = Invoke-RestMethod $URL
  foreach($property in ($Data.content.properties)) 
  { 
		$Percent = $property.PercentComplete.'#text' 		
		$Current_Steps = $property.CurrentStep.'#text'			
		$Total_Steps = $property.TotalSteps.'#text'		
		
		If ($Current_Steps -eq $Total_Steps)
			{
				If ($Percent -eq $null)
					{			
						$Step_Status = "Not started"
					}
				Else
					{
						$Step_Status = "$Current_Steps / $Total_Steps"
					}					
			}
		Else
			{
				$Step_Status = "$Current_Steps / $Total_Steps"			
			}
	
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
      "Computer Name" = $($property.Name); 
      "Percent Complete" = $Percent_Value; 	  
      "Step Name" = $StepName;	  	  
      "Step status" = $Step_Status;	
      Actual_Step = $property.CurrentStep.'#text'	 	  
      All_my_Steps = $property.TotalSteps.'#text'		  
      Warnings = $($property.Warnings.'#text'); 	  
      Errors = $($property.Errors.'#text'); 	  
      ID = $($property.ID.'#text'); 
      LastTime = ([datetime]$($property.LastTime.'#text')).ToLocalTime().ToString('HH:mm:ss')  	
      DARTIP = $($property.DARTIP.'#text'); 	  
      DartPort = $($property.DartPort.'#text'); 
      DartTicket = $($property.DartTicket.'#text'); 
      VMHost = $($property.VMHost.'#text'); 
      VMName = $($property.VMName.'#text'); 
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
      "Start time" = ([datetime]$($property.StartTime.'#text')).ToLocalTime().ToString('HH:mm:ss')  
	  "End time" = $EndTime;
      "Ellapsed time" = $Ellapsed;	  	  
    } 
  } 
} 


Function Populate_Datagrid_Monitoring
	{
		$Global:MyData = GetMDTData | Select Date, "Computer Name", Actual_Step, All_my_Steps, ID, LastTime, DARTIP, DartPort, DartTicket, VMHost, VMName, "Percent Complete", "Step Name", Warnings, Errors, "Start time", "End Time", "Ellapsed time", "Step status", "Deployment Status" 
		
		If ($MyData -eq $null)
			{
				[MahApps.Metro.Controls.Dialogs.DialogManager]::ShowMessageAsync($Form, "Oops :-(", "No monitoring values have been found")																																				
			}
		Else
			{
				ForEach ($data in $MyData)
					{
						$Monitor_values = New-Object PSObject
						$Monitor_values = $Monitor_values | Add-Member NoteProperty ID $MyData.ID –passthru	
						$Monitor_values = $Monitor_values | Add-Member NoteProperty Date $data.Date –passthru									
						$Monitor_values = $Monitor_values | Add-Member NoteProperty Name $data."Computer Name" –passthru	
						$Monitor_values = $Monitor_values | Add-Member NoteProperty PercentComplete $data."Percent Complete" –passthru				
						$Monitor_values = $Monitor_values | Add-Member NoteProperty StepName $data."Step Name" –passthru
						$Monitor_values = $Monitor_values | Add-Member NoteProperty Step_status $data."Step status" –passthru						
						$Monitor_values = $Monitor_values | Add-Member NoteProperty Warnings $data.warnings –passthru	
						$Monitor_values = $Monitor_values | Add-Member NoteProperty Errors $data.Errors –passthru	
						$Monitor_values = $Monitor_values | Add-Member NoteProperty Start_time $data."Start time" –passthru	
						$Monitor_values = $Monitor_values | Add-Member NoteProperty End_Time $data."End Time" –passthru	
						$Monitor_values = $Monitor_values | Add-Member NoteProperty Ellapsed_time $data."Ellapsed Time" –passthru				
						$Monitor_values = $Monitor_values | Add-Member NoteProperty LastTime $data.LastTime –passthru					
						$Monitor_values = $Monitor_values | Add-Member NoteProperty DARTIP $data.DARTIP –passthru	
						$Monitor_values = $Monitor_values | Add-Member NoteProperty DartPort $data.DartPort –passthru	
						$Monitor_values = $Monitor_values | Add-Member NoteProperty DartTicket $data.DartTicket –passthru	
						$Monitor_values = $Monitor_values | Add-Member NoteProperty VMHost $data.VMHost –passthru	
						$Monitor_values = $Monitor_values | Add-Member NoteProperty VMName $data.VMName –passthru		
						$Monitor_values = $Monitor_values | Add-Member NoteProperty This_Step $MyData.Actual_Step –passthru			
						$Monitor_values = $Monitor_values | Add-Member NoteProperty All_Steps $MyData.All_my_Steps –passthru					
						$Monitor_values = $Monitor_values | Add-Member NoteProperty DeploymentStatus $data."Deployment Status" –passthru
						
						$DataGrid_Monitoring.Items.Add($Monitor_values) > $null						
					}			
			}
	}





# Check presence of the monitoring_host txt file
If ($Test_Monitoring_Host -ne $true)
	{
		new-item $List_Monitoring_Host -force -type file
	}

		
# Check if an host already exists in the txt file
# If yes, it'll will automatically loaded 	
$My_Host = (Get-Content $List_Monitoring_Host) 
If ($My_Host -ne $null)
	{	
		# Fill the textbox with the existing host located in the txt file
		$Monitoring_host_txtbox.Text = $My_Host	
		# Check the toogleswicth remember host
		$Toggle_Host_Remember.IsChecked = $true	
		# Disabled the search host button
		$Search_Host.IsEnabled = $false
		# Disabled the monitoring host textbox		
		$Monitoring_host_txtbox.IsEnabled = $false
		# check deployment status on this host
		$Global:URL = "http://" + $My_Host + ":9801/MDTMonitorData/Computers/"							
		GetMDTData	
		Populate_Datagrid_Monitoring			
	}	
Else
	{
		$Toggle_Host_Remember.IsChecked = $False				
	}

	
	
#########################################################################################################################################################################################################	
#*******************************************************************************************************************************************************************************************************
#																			BUTTONS AND LABELS DEFAULT STATUS 
#*******************************************************************************************************************************************************************************************************
#########################################################################################################################################################################################################	



[System.Windows.RoutedEventHandler]$EventonDataGrid = {
    $button =  $_.OriginalSource.Name
    $Script:resultObj = $DataGrid_Monitoring.CurrentItem
    If ( $button -match "Properties" ){
        viewProperties -rowObj $resultObj
    }
    ElseIf ($button -match "Remote" ){   
        RemoteConnect -rowObj $resultObj

    }
    ElseIf ($button -match "DisplayGUI" ){
        DisplayGUI -rowObj $resultObj
    }
    ElseIf ($button -match "Mail" ){
        SendMail -rowObj $resultObj
    }	
}
$DataGrid_Monitoring.AddHandler([System.Windows.Controls.Button]::ClickEvent, $EventonDataGrid)	
	


	
Function DisplayGUI($rowObj)
	{     
	
		$Host_Monitor = $Monitoring_host_txtbox.Text.ToString()		
		$Global:Comp_Name = $rowObj.Name		
		$okAndCancel = [MahApps.Metro.Controls.Dialogs.MessageDialogStyle]::AffirmativeAndNegative	
		$settings = [MahApps.Metro.Controls.Dialogs.MetroDialogSettings]::new()
		$result = [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Are you sure ?","Display a GUI about $Comp_Name deployment status ?",$okAndCancel, $settings)			

		switch ($result)
		{
			"Affirmative" 
			{
				start-process powershell.exe ".\Display_Final_GUI_From_Datagrid.ps1 '$Host_Monitor' '$Comp_Name'" 
			}
		}		
	}	

	
	
	
Function SendMail($rowObj)
	{     
	
		$Host_Monitor = $Monitoring_host_txtbox.Text.ToString()		
		$Global:Comp_Name = $rowObj.Name		
		$okAndCancel = [MahApps.Metro.Controls.Dialogs.MessageDialogStyle]::AffirmativeAndNegative	
		$settings = [MahApps.Metro.Controls.Dialogs.MetroDialogSettings]::new()
		$result = [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Are you sure ?","Receive mail notification for $Comp_Name deployment status ?",$okAndCancel, $settings)			

		$Global:List_XML_Content = "$Progdata\Monitoring_Infos.xml"						
		$Input_XML = [xml] (Get-Content $List_XML_Content)	 
		foreach ($infos in $Input_XML.selectNodes("Mail_Infos"))		
			{
				$Global:Mail_SMTP = $infos.SMTP			
				$Global:Mail_From = $infos.MailFrom			
				$Global:Mail_To = $infos.MailTo			
			}	
		
		switch ($result)
		{
			"Affirmative" 
			{
				If (!(test-path $List_XML_Content))
					{
						[MahApps.Metro.Controls.Dialogs.DialogManager]::ShowMessageAsync($Form, "Oops :-(", "The Monitoring_infos.xml does not exist")																																	
					}
				Else
					{
						If (($Mail_SMTP -ne "") -and ($Mail_From -ne "") -and ($Mail_To -ne ""))
							{
								start-process powershell.exe ".\Mail_From_dataGrid.ps1 '$Host_Monitor' '$Comp_Name'" 							
							}
						Else
							{
								[MahApps.Metro.Controls.Dialogs.DialogManager]::ShowMessageAsync($Form, "Oops :-(", "An information is missing in the Monitoring_infos.xml file")																																								
							}
					}
			}
		}		
	}
	
Function RemoteConnect($rowObj)
	{     
		$Global:Comp_Name = $rowObj.Name
		$cmd = "mstsc.exe /v:$Comp_Name"
		Invoke-Expression $cmd		
	}	

	
Function viewProperties($rowObj)
	{     
		$Global:Comp_ID = $rowObj.id	
		$Global:Deploy_date = $rowObj.Date		
		$Global:Comp_Name = $rowObj.Name
		$Global:Percent = $rowObj.PercentComplete			
		$Global:Deploy_Status = $rowObj.DeploymentStatus								
		$Global:Step_Name = $rowObj.StepName					
		$Global:Start_Time = $rowObj.Start_time
		$Global:End_Time = $rowObj.End_Time
		$Global:Last_Time = $rowObj.LastTime				
		$Global:Elapsed_Time = $rowObj.Ellapsed_time				
		$Global:My_Step = $rowObj.Actual_Step
		$Global:Total_Steps = $rowObj.All_my_Steps				
		$Global:Error_Number = $rowObj.Errors
		$Global:Warning_Number = $rowObj.warnings			
		$Global:DARTIP = $rowObj.DARTIP	
		$Global:DartPort = $rowObj.DartPort	
		$Global:DartTicket = $rowObj.DartTicket	
		$Global:VMHost = $rowObj.VMHost	
		$Global:VMName = $rowObj.VMName			
		$Global:Step_status = $rowObj.Step_status	
		$Host_Monitor = $Monitoring_host_txtbox.Text.ToString()					

		powershell -sta ".\Properties.ps1" -Date "'$Deploy_date'"  -ID "'$Comp_ID'" -Host "'$Host_Monitor'" -name "'$Comp_Name'" -DeployShare "'$DeploymentSharePath'" -ModulePath "'$MDT_module_Path'" -status "'$Deploy_Status'" -step "'$Step_Name'" -Percentage "'$Percent'" -Start "'$Start_Time'" -End "'$End_Time'" -LastTime "'$Last_Time'" -TotalTime "'$Elapsed_Time'" -CurrentStep "'$Cur_Step'"  -Status_Step "'$Step_status'"  -TotalStep "'$Total_Steps'" -ErrorNB "'$Error_Number'" -WarningNB "'$Warning_Number'" -DART_IP "'$DARTIP'" -Dart_Port "'$DartPort'" -Dart_Ticket "'$DartTicket'" -VM_Host "'$VMHost'" -VM_Name "'$VMName'"   
	}	
	
	
########################################################################################################################################################################################################	
#*******************************************************************************************************************************************************************************************************
#																						 BUTTONS ACTIONS 
#*******************************************************************************************************************************************************************************************************
########################################################################################################################################################################################################

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 10000 
$timer.add_tick({UpdateUi})
 
Function UpdateUi()
{
	($DataGrid_Monitoring.items).Clear()	
	GetMDTData		
	Populate_DataGrid_Monitoring
}
		
$Start_Stop_Timer.Add_Click({	
	$Timer_Status = $timer.Enabled
	If ($Timer_Status -eq $true)
		{
			# We'will stop the timer
			$Start_Stop_Timer.ToolTip = "Refresh your deployment status each 10 seconds"									
			$timer.Stop()			
		}
	Else
		{
			# We'will stop the timer
			$Start_Stop_Timer.ToolTip = "Stop the refresh"			
			$timer.start()			
		}
})		
	
	
$Toggle_Host_Remember.Add_Click({	
	# If the remember host toggle switch is checked
	If ($Toggle_Host_Remember.IsChecked -eq $True)
		{	
			# Add the monitoring host located in the textbox, in the txtfile
			$Typed_Host = $Monitoring_host_txtbox.Text.ToString()	
			# If there is no text in the textbox we will display the below message
			If ($Typed_Host -eq "")
				{
					[MahApps.Metro.Controls.Dialogs.DialogManager]::ShowMessageAsync($Form, "Oops :-(", "Please type a monitoring host to watch")																												
				}
			Else
				{									
					$My_Host = (Get-Content $List_Monitoring_Host)	
					# if the txt file contains something we'll clear the content
					If ($My_Host -ne $null)
						{		
							clear-content $List_Monitoring_Host
							# Then we will add the host typed in the textbox							
							add-content $List_Monitoring_Host $Typed_Host
						}
					Else
						{
							add-content $List_Monitoring_Host $Typed_Host				
						}				
				}
		}
	Else
		{	
			# If the remember host isn't checked and if there is something in the txt file, we'll clear it
			$My_Host = (Get-Content $List_Monitoring_Host)			
			If ($My_Host -ne $null)
				{		
					clear-content $List_Monitoring_Host
					# Enable the search host button
					$Search_Host.IsEnabled = $true
					# Enable the monitoring host textbox		
					$Monitoring_host_txtbox.IsEnabled = $true						
				}				
		}	
})	
		

$Search_Host.Add_Click({	
	$Typed_Host = $Monitoring_host_txtbox.Text.ToString()
	If ($Typed_Host -eq "")
		{
			[MahApps.Metro.Controls.Dialogs.DialogManager]::ShowMessageAsync($Form, "Oops :-(", "Please type a monitoring host to watch")																												
		}
	Else
		{			
			$Global:URL = "http://" + $Typed_Host + ":9801/MDTMonitorData/Computers/"					
			GetMDTData	
			Populate_Datagrid_Monitoring			
		}	
})		
		
	
# refresh the Deployment status just once
$Refresh_Once.Add_Click({	
	($DataGrid_Monitoring.items).Clear()			
	GetMDTData	
	Populate_Datagrid_Monitoring		
})		


$Export_To_Excel.Add_Click({	
	$tmp_folder = $env:TEMP
	$Deployment_List = "$tmp_folder\Deployment_List.csv"
	If (test-path $Deployment_List)
		{
			remove-item $Deployment_List -force
		}
	$DataGrid_Monitoring.items | select DeploymentStatus, Date, Name, PercentComplete, Step_status, StepName, Warnings, Errors, Start_time, End_Time, Ellapsed_time, LastTime, DARTIP, DartPort, DartTicket, VMHost, VMName | export-csv $Deployment_List -NoTypeInformation	-UseCulture		
	invoke-item $Deployment_List
})		



$Form.ShowDialog() | Out-Null

