VersionNumber = 2.6

SetTitleMatchMode, 2
Process, Priority,, High
SetBatchLines, -1
#SingleInstance force
SetKeyDelay, 0
#NoEnv
SendMode Input
CoordMode, Pixel, Screen
CoordMode, Mouse, Screen
SetWorkingDir %A_ScriptDir%

/*
____________              __     ________                 __    __________             __
\___    ___/___   ____   |  |__  \______ \   ____   _____|  | __\__    __/____   ____ |  |   ______
   |    | / __ \ / ___\  |  |  \  |  | |  \_/ __ \ /  ___/  |/ /  |    | /  _ \ /  _ \|  |  /  ___/
   |    | \  __/_\  \___ |   Y  \ |  |_|   \  ___/ \___ \|    <   |    |(  <_> |  <_> )  |__\___ \
   |____|  \_____\\_____\|___|__/ /________/\_____>______>__|__\  |____| \____/ \____/|____/______>
*/

; Pull contents from Clipboard, there are a lot of things that modify this upon startup, so we want to preserve original content
If(Clipboard)
{
	UserHadClipboardContent = 1
	StartClip = %Clipboard%
}

; Create variables for permission checking. These strings are the names of the security groups as they appear in CMD when the user is searched. 
; Due to difficulties and revamps in permissions, Laps is used to determine if MFA and adac are granted - Jonathan
LAPS_String = LAPS-ReadWrite
DeviceAdmin_String = ITS (Tech Desk Stud
ADAC_String = ITS Tech Desk - Reset
MFA_String = ITS Tech Desk - Reset



;========================================================================================================================================================
; - Username Extraction and Permissions - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;========================================================================================================================================================
UsernameExtractionAndPermissions:
{
	Username = %A_Username%
	If(InStr(Username, "-"))
	{
		StringTrimLeft, CutUsername, Username, 4 ; 4 for XST, 5 for XTRA
		HadHypen = 1
	}
	If( (InStr(CutUsername, "-")) && HadHypen ) ; Determine if removing 4 characters did not remove the hyphen (indicating they had an xtra account when they launched the application)
	{
		StringTrimLeft, Username, CutUsername, 1
		XTRAUsername = xtra-%Username%
		UserRanAsAdmin = XTRA
		UserHasAdminType = XTRA
		LoggedInAdmin = 1 ;Used to determine if MiM runs in incog
	}
	Else If( !(InStr(CutUsername, "-")) && HadHypen ) ; Determine if removing 4 characters removed the hyphen (indicating they had an xst account when they launched the application)
	{
		Username = %CutUsername%
		XSTUsername = xst-%Username%
		UserRanAsAdmin = XST
		UserHasAdminType = XST
		LoggedInAdmin = 1 ;Used to determine if MiM runs in incog
	}
	else
	{
		UserRanAsAdmin = NoneFound
		LoggedInAdmin = 0
		XTRAUsername = xtra-%Username%
		XSTUsername = xst-%Username%
	}

	If (UserRanAsAdmin = "NoneFound")
	{
		clipboard =
		run, %comspec% /c net user %XSTUsername% /domain | find "User name" | Clip && exit, , hide
		ClipWait, 3
		XSTCMD = %Clipboard%

		If(Clipboard)
		{
			UserHasAdminType = XST
		}

		clipboard =
		run, %comspec% /c net user %XTRAUsername% /domain | find "User name" | Clip && exit, , hide
		ClipWait, 3
		XTRACMD = %Clipboard%
		If(Clipboard)
		{
			UserHasAdminType = XTRA
		}
	}

	If (UserHasAdminType = "XTRA")
	{
		clipboard = ; clear clipboard
		run, %comspec% /c net user %XTRAUsername% /domain | Clip && exit, , hide ; Gets permissions from CMD on XTRA account
		ClipWait, 3
		XTRACMD = %Clipboard%
		AdminEmail = %XTRAUsername%@stthomas.edu
		XSTUsername =
	}

	If (UserHasAdminType = "XST")
	{
		clipboard = ; clear clipboard
		run, %comspec% /c net user %XSTUsername% /domain | Clip && exit, , hide ; Gets permissions from CMD on XST account
		ClipWait, 3
		XSTCMD = %Clipboard%
		AdminEmail = %XSTUsername%@stthomas.edu
		XSTUsername =
	}

	clipboard = ; clear clipboard
	run, %comspec% /c net user %Username% /domain | Clip && exit, , hide ; Gets permissions from CMD on normal user account
	ClipWait, 3
	USERCMD = %Clipboard%

	; Generates first name based on username
	clipboard = ; clear clipboard
	run, %comspec% /c net user %Username% /domain | Find "Full Name" | Clip && exit, , hide ; Gets permissions from CMD on normal user account
	ClipWait, 3
	NameCMD = %Clipboard%

	StringTrimLeft, Name, NameCMD, 29 ; Remove whitespace -> just whitespace
	Name := SubStr(Name, InStr(Name, ",") + 1)
	Name = %Name%
	Name := SubStr(Name, 1, InStr(Name, " ") - 1)

	if(InStr(Name, "Comment"))
	{
		Name :=  StrReplace(Name, "Comment")
	}

	If InStr(XSTCMD, LAPS_String) or InStr(XTRACMD, LAPS_String)
	{
		UserCanLAPS = 1
	}

	if ( InStr(XSTCMD, ADAC_String) or (InStr(XTRACMD, ADAC_String)) or (InStr(UserCMD, ADAC_String)) )
	{
		UserCanADAC = 1
	}

	If InStr(XSTCMD, MFA_String) or InStr(XTRACMD, MFA _String)
	{
		UserCanMFA = 1
	}

	; Check if ADAC is installed (using default install location)
	ifExist, C:\Windows\System32\dsac.exe
	{
		ADACInstalled = 1
	}

	; Check if ReferenceFiles is installed (using C:\ location)
	ifExist, C:\ReferenceFiles
	{
		ReferenceFilesInstalled = 1
	}
}

;========================================================================================================================================================
; - Gui Creation - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;========================================================================================================================================================
GuiCreation:
	TitleFont = Arial Bold
	ButtonFont = Century Gothic
	TitleColor = Purple
	TotalWidth = 358
	TotalHeight = 370
{
	ButtonHeight = 30
	ButtonWidth = 112
	ColumnWidth = 116
	Gui, Margin , 5, 5
	
	
	; Left column
	Gui, 1:Font, s13 underline, %TitleFont%
	Gui, 1:Add, Text, x5 y6 w%ButtonWidth% h%ButtonHeight% +Center c%TitleColor%, Links
	Gui, 1:Font ;resets font
	Gui, 1:Font,s9,%ButtonFont%
	Gui, 1:Add, Button,   xp     y+1 w%ButtonWidth% h%ButtonHeight% gButtonOneStThomas, OneStThomas
	Gui, 1:Add, Button,   xp y+6 w%ButtonWidth% h%ButtonHeight% gButtonWebCheckout , Web Checkout
	Gui, 1:Add, Button,   xp y+6 w%ButtonWidth% h%ButtonHeight% gButtonFileMaker , FileMaker	
	Gui, 1:Add, Button,   xp y+6 w%ButtonWidth% h%ButtonHeight% gButtonLive , 25 Live
	Gui, 1:Add, Button,   xp y+6 w%ButtonWidth% h%ButtonHeight% gButtonCanvas , Canvas
	Gui, 1:Add, Button,   xp y+6 w%ButtonWidth% h%ButtonHeight% gButtonMurphy , Murphy
	Gui, 1:Add, Button,   xp y+6 w%ButtonWidth% h%ButtonHeight% gButtonWhenToWork , When To Work
	Gui, 1:Add, Button,   xp y+6 w%ButtonWidth% h%ButtonHeight% gButtonHelp , Help
	Gui, 1:Add, Button,   xp y+6 w%ButtonWidth% h%ButtonHeight% gButtonAllLinks , Other Links

	; Open needed Apps
	Gui, 1:Font, s13 underline, %TitleFont%
	Gui, 1:Add, Text,     xp+%ColumnWidth%   y6  w%ButtonWidth% h%ButtonHeight% +Center c%TitleColor%, Main Apps
	Gui, 1:Font
	Gui, 1:Font, s11, bold, %ButtonFont%
	Gui, 1:Add, Button,   xp y+2  w%ButtonWidth% h%ButtonHeight% gButtonOpenMain, Launch
		
	;Middle Column
	Gui, 1:Font, s9, %ButtonFont%
	Gui, 1:Add, Button,   xp y+6 w%ButtonWidth% h%ButtonHeight% gButtonMIM , MIM
	Gui, 1:Add, Button,   xp y+6  w%ButtonWidth% h%ButtonHeight% gButtonTickets, Tickets
	Gui, 1:Add, Button,   xp y+6  w%ButtonWidth% h%ButtonHeight% gButtonKB, Reference Menu
	Gui, 1:Add, Button,   xp y+6  w%ButtonWidth% h%ButtonHeight% gButtonOnlineXstOutlook, TD Inbox
	Gui, 1:Add, Button,   xp y+6  w%ButtonWidth% h%ButtonHeight% gButtonBomgar, Bomgar

	if(UserCanLAPS){ ;If given laps perms these will show in main window
	Gui, 1:Add, Button,   xp y+6  w%ButtonWidth% h%ButtonHeight% gButtonADAC, ADAC
	Gui, 1:Add, Button,   xp y+6  w%ButtonWidth% h%ButtonHeight% gButtonAAD, Azure MFA
	Gui, 1:Add, Button,   xp y+6  w%ButtonWidth% h%ButtonHeight% gButtonLAPS, LAPS
		}


	; Right column upper
	Gui, 1:Font, s12 underline, %TitleFont%
	Gui, 1:Add, Text,  xp+%ColumnWidth% y6 w%ButtonWidth% h%ButtonHeight% +Center c%TitleColor%, Tools
	Gui, 1:Font
	Gui, 1:Font, s9, %ButtonFont%
	Gui, 1:Add, Button,   xp   y+2  w%ButtonWidth% h%ButtonHeight% gButtonPasswordReset, Password Reset
	Gui, 1:Add, Button,   xp   y+6  w%ButtonWidth% h%ButtonHeight% gButtonGeneratePassword, Create Password
	Gui, 1:Add, Button,   xp   y+6  w%ButtonWidth% h%ButtonHeight% gButtonPassLink, Password Article

	; Right column lower
	;Gui, 1:Font, s12 underline, %TitleFont%
	;Gui, 1:Add, Text,     xp   y+11  w%ButtonWidth% h%ButtonHeight% +Center c%TitleColor%, Tools
	;Gui, 1:Font
	Gui, 1:Font, s9, %ButtonFont%
	Gui, 1:Add, Button,   xp y+6  w%ButtonWidth% h%ButtonHeight% gButtonCMD, CMD
	Gui, 1:Add, Button,   xp   y+6  w%ButtonWidth% h%ButtonHeight% gButtonSnippingTool, Screenshot
	Gui, 1:Add, Button,   xp   y+6  w%ButtonWidth% h%ButtonHeight% gButtonCopyEmailOnline, Copy Email Online
	Gui, 1:Add, Button,   xp   y+6  w%ButtonWidth% h%ButtonHeight% gButtonCampMap, Campus Map
	Gui, 1:Add, Button,   xp   y+6  w%ButtonWidth% h%ButtonHeight% gButtonFindPrinters, Find Printers
	Gui, 1:Add, Button,   xp   y+6  w%ButtonWidth% h%ButtonHeight% gButtonMiniMenu, Minimize


	Gui, 1:Show, Autosize Center, Tech Desk Tools - V%VersionNumber%
	; Restore original contents of clipboard
	if(UserHadClipboardContent)
	{
		Clipboard := StartClip
		ClipWait, 3
	}
	return
}

;Descriptions not in the knowledgebase
LinkADAC:
{
	MsgBox, Launches Active Directory Administrative Center. This application can be used to manually reset passwords with your XST account as well as view users' security groups, however, it shouldn't need to be used as long as the password reset button is working properly.
	return
}
LinkAAD:
{
	MsgBox, Links to Azure Active Directory. This application is used by student tech leads and full-time technicians to reset MFA. Eventually, it's likely that password resets will be done in this application as well.
	return
}
LinkScreenshot:
{
	MsgBox, Launches the Windows Snipping Tool. `nShortcut: [Windows Key] + SHIFT + S
	return
}
LinkLAPS:
{
	MsgBox, Launches LAPS client. This application can be used to manually grab an admin password for a specific network asset. Need permitted access
	return
}

LinkOpenMain:
{
	MsgBox, Launches main applications needed for Tech Desk. Log in Once and then refresh other tabs
	return
}

LinkLive:
{
	MsgBox, Launches 25 live into browser. Must have personal account.
	return
}

LinkFileMaker:
{
	MsgBox, Opens FileMaker online with guest login. This is the asset and software database for ITS
	return
}

;========================================================================================================================================================
; - Left Row Buttons - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;========================================================================================================================================================
ButtonOneStThomas:
{
	Run, msedge.exe https://one.stthomas.edu
	return
}
ButtonMurphy:
{
	Run, msedge.exe https://banner.stthomas.edu
	return
}
ButtonCanvas:
{
	Run, msedge.exe https://stthomas.instructure.com/
	return
}
ButtonTeams:
{
	Run, C:\Users\%A_Username%\AppData\Local\Microsoft\Teams\Update.exe --processStart "Teams.exe"
	return
}
ButtonZoom:
{
	Run, C:\Program Files\Zoom\bin\Zoom.exe
	return
}
ButtonMIM:
{
	if(LoggedInAdmin = 1){
	Run msedge.exe -inprivate https://mimportal.stthomas.edu/IdentityManagement/
		}
	else{
	Run msedge.exe https://mimportal.stthomas.edu/IdentityManagement/
	Return
		}
}

ButtonWebCheckout:
{
	Run, msedge.exe https://stthomas.webcheckout.net/wco
	sleep 2000
	SendInput, %AdminEmail%
	return
}
ButtonWhenToWork:
{
	Run, msedge.exe https://whentowork.com/logins.htm
	return
}

ButtonFileMaker:
{
	 Run, msedge.exe -inprivate https://filem.stthomas.edu/fmi/webd/#UST_INVT
			sleep 8000
			SendInput,{tab}{tab}guest{tab}lemon{return}
		return
}

ButtonLive:
{
	Run, msedge.exe https://25live.collegenet.com/pro/stthomas#!/home/availability
	return
}

ButtonHelp: 
{

	Run, msedge.exe -inprivate https://services.stthomas.edu/TDClient/1898/ClientPortal/KB/ArticleDet?ID=141578
	return
}


ButtonAllLinks:
{
	NumOfCheckboxes := 10

	Gui, 1:Submit, Hide
	Gui, +AlwaysOnTop
	Gui, AllLiks:Font, s10 underline, %TitleFont%
	Gui, AllLinks:Add, Button,   0   y5   w%ButtonWidth% h%ButtonHeight% gButtonLaunchBrowser, Open
	Gui, AllLiks:Font, s8 , %ButtonFont%
	;Gui, AllLinks:Add, Checkbox, xp  y+10  vL_OneStThomas, OneStThomas
	Gui, AllLinks:Add, Checkbox, xp  y+10  vL_Murphy, Murphy
	Gui, AllLinks:Add, Checkbox, xp  y+10  vL_Canvas, Canvas
	Gui, AllLinks:Add, Checkbox, xp  y+10  vL_Teams, Teams Online
	Gui, AllLinks:Add, Checkbox, xp  y+10  vL_AccountClaim, Account Claim
	Gui, AllLinks:Add, Checkbox, xp  y+10  vL_MFASetup, MFA Setup
	Gui, AllLinks:Add, Checkbox, xp  y+10  vL_MyDevices, My Devices
	Gui, AllLinks:Add, Checkbox, xp  y+10  vL_PaperCut, PaperCut
	Gui, AllLinks:Add, Checkbox, xp  y+10  vL_Panopto, Panopto
	Gui, AllLinks:Add, Checkbox, xp  y+10  vL_Voicethread, Voicethread
	Gui, AllLinks:Add, Checkbox, xp  y+10  vL_GPDownload, Global Protect Download

	Gui, AllLinks:Font, s10, %TitleFont%
	Gui, AllLinks:Add, Checkbox, xp  y+15  gL_SelectAll, Select All
	Gui, AllLinks:Font

	Gui, AllLiks:Font, s10, %ButtonFont%
	Gui, AllLinks:Add, Button,   xp+120 y5 w%ButtonWidth% h%ButtonHeight% gButtonBookmark, Export As Bookmarks
	Gui, AllLinks:Add, Button,   xp   y+10  w%ButtonWidth% h%ButtonHeight% gButtonStPPrinters, StP Printers
	Gui, AllLinks:Add, Button,   xp   y+10  w%ButtonWidth% h%ButtonHeight% gButtonMPLSPrinters, MPLS Printers
	Gui, AllLinks:Add, Button,   xp   y+10  w%ButtonWidth% h%ButtonHeight% gButtonZoom, Zoom
	Gui, AllLinks:Add, Button,   xp   y+10  w%ButtonWidth% h%ButtonHeight% gButtonADAC, ADAC
	Gui, AllLinks:Font, s10, %TitleFont%
	Gui, AllLinks:Add, Checkbox, xp+15   y+80  vL_InIncog, Incognito

	Gui, AllLinks:Show, Center, Links
	return

	; If select all is checked, choose all the options for chrome. NumOfCheckboxes must be changed if the number of checkboxes changes. NumOfCheckboxes does NOT include SelectAll.
	L_SelectAll:
	{
		OnOff := !OnOff
		Loop %NumOfCheckboxes% {
			LoopNum := A_Index+1 ;Skip first Gui element because that is the "Launch Browser" button.
			GuiControl,, Button%LoopNum%, %OnOff%
		}
		return
	}

	; If Launch Browser button is pressed, then it checks the status of the checkboxes. If it is checked, the page will open.
	ButtonLaunchBrowser:
	{
		Gui, AllLinks:Submit, NoHide
		if(L_InIncog == 1){
		
		if(L_OneStThomas == 1)
			Run, msedge.exe -inprivate  https://one.stthomas.edu/
		if(L_Murphy == 1)
			Run, msedge.exe -inprivate https://banner.stthomas.edu/
		if(L_Canvas == 1)
			Run, msedge.exe -inprivate https://stthomas.instructure.com/
		if(L_Teams == 1)
			Run, msedge.exe -inprivate https://teams.microsoft.com/
		if(L_Zoom == 1)
			Run, msedge.exe -inprivate https://stthomas.zoom.us/
		if(L_WebCheckout == 1)
			Run, msedge.exe -inprivate https://stthomas.webcheckout.net/wco/
		if(L_WhenToWork == 1)
			Run, msedge.exe -inprivate https://whentowork.com/logins.htm/
		if(L_AccountClaim == 1)
			Run, msedge.exe -inprivate https://accountclaim.stthomas.edu/
		if(L_FileMaker == 1)
			Run, msedge.exe -inprivate https://filem.stthomas.edu/fmi/webd/
		if(L_25Live == 1)
			Run, msedge.exe -inprivate https://25live.collegenet.com/stthomas/
		if(L_MFASetup == 1)
			Run, msedge.exe -inprivate https://link.stthomas.edu/MFASetup/
		if(L_MyDevices == 1)
			Run, msedge.exe -inprivate https://mydevices.stthomas.edu/
		if(L_PaperCut == 1)
			Run, msedge.exe -inprivate https://print.stthomas.edu/
		if(L_Panopto == 1)
			Run, msedge.exe -inprivate https://stthomas.hosted.panopto.com/
		if(L_Voicethread == 1)
			Run, msedge.exe -inprivate https://stthomas.voicethread.com/
		if(L_Passwords == 1)
			Run, msedge.exe -inprivate https://www.stthomas.edu/its/password/
		if(L_GPDownload == 1)
			Run, msedge.exe -inprivate https://www.stthomas.edu/its/facultystaff/workingremotelyvpn/
		if(L_CampusMap == 1)
			Run, msedge.exe -inprivate https://campusmap.stthomas.edu/}
		if(L_InIncog == 0){ 
		
		if(L_OneStThomas == 1)
			Run, msedge.exe  https://one.stthomas.edu/
		if(L_Murphy == 1)
			Run, msedge.exe https://banner.stthomas.edu/
		if(L_Canvas == 1)
			Run, msedge.exe https://stthomas.instructure.com/
		if(L_Teams == 1)
			Run, msedge.exe https://teams.microsoft.com/
		if(L_Zoom == 1)
			Run, msedge.exe https://stthomas.zoom.us/
		if(L_WebCheckout == 1)
			Run, msedge.exe https://stthomas.webcheckout.net/wco/
		if(L_WhenToWork == 1)
			Run, msedge.exe https://whentowork.com/logins.htm/
		if(L_AccountClaim == 1)
			Run, msedge.exe https://accountclaim.stthomas.edu/
		if(L_FileMaker == 1)
			Run, msedge.exe https://filem.stthomas.edu/fmi/webd/
		if(L_25Live == 1)
			Run, msedge.exe https://25live.collegenet.com/stthomas/
		if(L_MFASetup == 1)
			Run, msedge.exe https://link.stthomas.edu/MFASetup/
		if(L_MyDevices == 1)
			Run, msedge.exe https://mydevices.stthomas.edu/
		if(L_PaperCut == 1)
			Run, msedge.exe https://print.stthomas.edu/
		if(L_Panopto == 1)
			Run, msedge.exe https://stthomas.hosted.panopto.com/
		if(L_Voicethread == 1)
			Run, msedge.exe https://stthomas.voicethread.com/
		if(L_Passwords == 1)
			Run, msedge.exe https://www.stthomas.edu/its/password/
		if(L_GPDownload == 1)
			Run, msedge.exe https://www.stthomas.edu/its/facultystaff/workingremotelyvpn/
		if(L_CampusMap == 1)
			Run, msedge.exe https://campusmap.stthomas.edu/
			}}
		return
		}

	ButtonBookmark:
	{
		AddBookmark(Link, Name, Icon)
		{
			FileAppend, % "            <DT><A HREF=""" . Link . """ ADD_DATE=""1640995200"" ICON=""" . Icon . """>" . Name . "</A>`n", C:\Users\%A_Username%\Downloads\TDT_Bookmarks.html
			return
		}

		Gui, AllLinks:Submit, NoHide
		FileDelete, C:\Users\%A_Username%\Downloads\TDT_Bookmarks.html
		BookmarkFile := "C:\Users\" . %A_Username% . "\Downloads\TDT_Bookmarks.html"
;This header has to break indentation because it copies over text EXACTLY as it appears between the parentheses.
Header =
(
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks</H1>
<DL><p>
    <DT><H3 ADD_DATE="1640995200" LAST_MODIFIED="1640995200" PERSONAL_TOOLBAR_FOLDER="true">Bookmarks bar</H3>
    <DL><p>
        <DT><H3 ADD_DATE="1640995200" LAST_MODIFIED="1640995200">Tech Desk</H3>
        <DL><p>

)
		FileAppend, %Header%, C:\Users\%A_Username%\Downloads\TDT_Bookmarks.html
		if(L_OneStThomas == 1)
			AddBookmark("https://one.stthomas.edu", "OneStThomas", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAABvklEQVQ4jZWSQU8TURDHZ97bXbtb2t2WGtyUNkCB1SaKMSYmcjIoXr34Hf0CfAGPRBMOBNFGQwVqbbvrtt1d2L63bzyQVGiaJs5pJvn/MjP/GSQi+J/QbhekCADkRDLOiIAUaQYHAGQ4H2h9/DH8NQYiQAACQASgcr3U2F2bA4x7kUhlc3/byBthZ4iItltIo8nZ4XkcJPmydSPD6Q7HB1/EtTTyRr81EKkkBYalr3iV2E+sktl8693pQETc4HFwlUapbulG3kAEldGoOyYCbvDZkTKhgnbYPend7Le8XlKZCi9HSioApIwyqbjG/gGI0Ps2aB9eaDnt/vZyJlUmsutx2m/54krqpoZ4twPXuVMtMo05Nbv65MHv0z4iru64IhHBWehUbcbZrEsP97eQM2QY+8nlURcACitLay9q9eer3l5jjq22Wxx89yeJqD51nZoNAFbJPP/cMZ2c7RanMjbNLMf09jajfhxeDDd26+sv68HPMPZj7/VmrnBv/qUfvdkK2n+OD74qqZRQ3dP+zrum96pxW4MzzzdJxKcPR2FnRBlVNsrP3j/Wc/oiAACUVNEgBoSlSn5qziJgcfwFQOXNbAi89xEAAAAASUVORK5CYII=")
		if(L_Murphy == 1)
			AddBookmark("https://banner.stthomas.edu", "Murphy", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADRklEQVQ4jX2TfUicdQDHP7/nee7NU8+dd76c3tJTc0w9ne9dKTPdWmBUFkHMBkEEcxQURBBcUGIRK1DWKIoFEUSBNVaNAmNHb7pkbruKytS5qZ2p4zxfzzvveX79k0EWff/8vvz3/cAudXd3V/vKK17BljMG5lXQVrG4L+/z157s7Oys3d3/hxoDd7wGSECW7lHlvRWZ8r4qhyxzqnLH37e/cuA/x05X7meA7Ciyyu96vFK+VCZlX56UfflSvlwmR0545d0lNgnI2vqGoZ2dCnD/Aw/3Xxm7+MiJBgcfHPfgzdYwFhZJ5dYPGVr2DbE4WewtdnA04GAtavDx6JSv5WBH3sz1a+dFb29veTAY/LXlFhtfP+OFlRRr6zpibZ70h055tuNRz9a54CUchWTYFdij0f7107Bem4wSDQb96c23rhcXIXOOnR/PJdaqsLeuIeAzV1xiSmilibKz7hNTLWF90J3QTFqug2WXl9dEVIrENs/JjeOKuokwVf6EJI6qjKAL0JGpB/VupyZEXiU62q17/OyTWUYRBanqG8rQIpWkwOTHforG97AmUWyAeIbFsYMSTqMU1Pylm26z845dKI+HNVj1V72HLhNQ2MvDYAIWeeNP37z84+dV4iQZ6mnD7Zug81m9a2lSVVAKR6zufuvTRczKVRC5N5Wt6KkN1l44o1ow54a37EP1Gh6ppOkhFw+KMjI4v2JmfrtI2txRDWKQR/rxdn71yRGS4kfEV9GvDz9paHz+kL0zcJgefHEbZIDwGCOeEVlNXfe7qcOj49U/OPFq018rWzSSKqiHs2aCoCFsW+lz4QHI1mrO9ONVmTzf4fbOYcGwaf3PlsNJ1pO00wBPfqJCXR7o7H9JcIARIAxQFYXOQDPX/YJsdfpqCvTz1xRIAgZqyATUUCi21th3OHxobrzdvQmtTOmYNSEgkIACTZsJmTynCZebk2RgDF2PcfvDQu2cHB98UO5e8tXz/hd/Gf247Vm3n+cMuSnI0MP0Vb0uml1L0fbnMmcurpGc6v11fjbb8iwd/dd0bO9A0FaiypzlL9jRnyYDX9DdMlQca3v5fIu/p6mrOLiw+hSX3KlhjkLaC5goXlFacbm29M7C7/yejSU5Rl1xQzAAAAABJRU5ErkJggg==")
		if(L_Canvas == 1)
			AddBookmark("https://stthomas.instructure.com", "Canvas", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACPElEQVQ4jaWTwUtUYRTFz73vezNvdBQVDTIr03FKQmwRIYFgJmLQIohoEbRvE20Ei4IngUgLt9F/EBOCmyhhxJFS2hZEaJGkKGWjkc57M2/evO+20JFnlgSd9f2dj3vu+YB9stnusZWIcCqVMlKplCEibPfYCgDtn/9PhRyFAJLeEw/7j7Q0dB1P1B/LrjnfTZPMqppYfGk+u7K4+HV6dmn4dXl2j5MICIAau/fivZRknwJPZPj2xAwA2GJzmVPlvYls3Vk3eLXzXOLk4kLWnZv6KA2Hq6JBSeTHulPsHkjymbOtXa3WnV4b9jRgM2DrPaFcTD66XlNd2bG+vlVYW/lpgijLAGuRusajtX51bTy2ubE5l/489HxnfVFhg6gyB/KOf9mKcaGtvbE6QDDO4DiB+z3P3fJyvmVEDAvArgGXVwCAkvb8iLLqCaop77mf8vncTMF10vlibpVZNZlmtD4Q391mrlE4AwEA0TzhB8Va0RqBLo1PLdx/CgB9yVHRrPt9FAXCk9vMMw0A5TQFAJY2sq+CoFBgjigSYzdpIjJMj107AexvphZdvwkw4A5rPVjgtDRxXrK6UGE19bSNRFrZAcotZdWiNJ0AmKF8AAIy9pcpIc2X3OzGCm4ZhNROhBOYOxdZ5P8h9cxz3xvJmZgvI7EIcMhAAlP7y4IMAwxEjRgDliAzXNCJEoLuzy/bqDiOhV3/Xdk0vtY89FsEhsFRIoN9Ozg8O/bHCB+lCYvR0T3Lk1D8DB+iv3/gXruMDHSEjv7wAAAAASUVORK5CYII=")
		if(L_Teams == 1)
			AddBookmark("https://teams.microsoft.com", "Online Teams", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAABqElEQVQ4ja2SP0hbYRTFf/d7nybQgFQEsdKUdtTBoagpdAwdNItVHLKGduiQuRBBHCqdMzeT+IaAKEU3Ax0cUlxErIX+MWBooX/pUGujee86xDyNfUGE3u2ec+75zr18QkjNPv8Z9+p+AdUEImXHmszc0+79MK0JA726X1DVpEJMVZNe3S+E6QBsKKqaCOsn0q+foWQR8svuaK5tgjfby+82yy94u/OyAYiUG0ZkFWIo2SBBanJ9X+HmeYMjHzqj8aOD31u+iGw41mQaRuTlNEFTK+OT69puv7Wl5DXgTzseTm+Qnr5NevpOALrFPdxihQdj8wfD9x4BUKsdex8+Vp1AJOyuuKODpjFQITVVAiA1VcItVv55KRLpcFoAZQDaHPEq9X8N3OLeFUalBmAEqmcGZ7v73uEl87wCsKtLyXgTG5/I//rx7X0XKMZYuq4HFIp8RmRXlGEVyh22MwMXvnJ//1Cpt3fgYbO3NhJwRnRtxR15fDFIi8GtvrtPDv2/CUVvtKQVqUZhLmyTliPmcrEvUWFERBYFvgt8FZEFx5r7MzM9n8IMTgCAM4qHUIjetAAAAABJRU5ErkJggg==")
		if(L_Zoom == 1)
			AddBookmark("https://stthomas.zoom.us", "Zoom", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACX0lEQVQ4jVWSvYteZRTEf/M89767mxgkYEKKNGqjYhNQItqtpLASraxFsRCRFIJohBR2W2llmvwDsVl7EdQECQ107LUVE8QMLI8K6e/feM2Pxvio5zZxqZs7MEYmQ8sL17I7bvMnMBcSZJNuRAiAi0CHhrhq3p5m9/Zd1i6tpAnjxel7rW3zYxKpmiMP/E0AAtCb6CDaHPuLyx6/omp6/lot9zJfqGlLMJAMCgiIiRBIJEoHC0rrGQM0Tl4bWeUddwzJlaS1jaCGBbNwTJDBiTeZxPmYZtjW0zluDnSc8Kzb9uJQui6yNI7BhMZxcRVOFuZQTI205JikeH1w5nYok8upTjQcfgPL6bhGmgq++F/vfmEfPiacfEje+jjJbgrODzY4TVl165mFz9lTbhKf/8MJ589tf4vKu2BqtG3dCGZraVnNILBxyMIEdlgp2qArlcDCJS4+Ic/fDHwcCWmJwkhaDK8TQ2+b2TXn/7k5YvPkI1uQuSEFzRSQcTdGff4vexNDvxTOnxK3vzM93w5n7hJfIDnY0xExIW3MpH3waXnoyOr0D2ei3BgdTuPNDePv3YvexHkckkp1DPbtXP9J0Xk6miqqi1XDvE5Zh6OtKp1JOrILaAOVfW1W+laSqeFS0PSpCUdY9CDE0AKU35eQYpVQIlX2nzTXvLbOL1oay5nUDazVHsYlrHXRVWEpz1IZl8lLL8H67+e7OZz7mdSeH9D6SLhvZkLJc1oZQSZN6HxOOl6o3vrii242raZ+/169Nky95zn6Vf4lzmI2DRIkB68iVn1x8Mh/VczevrD4i0T+uuK6HjS6bUwAAAABJRU5ErkJggg==")
		if(L_WebCheckout == 1)
			AddBookmark("https://stthomas.webcheckout.net/wco", "Web Checkout", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADW0lEQVQ4jWWTXWyTdRTGn///fd9+064bMvsxgVJWFpjMul1At8VB/GDEiBeTSPQGr0y4NvGuGJErYuIVmhBBMzGobEbWuWkMHxeIsi2jhZHUVSDd3jas6xdd+34eL9xMg8/NuTjnPDkneX7Av2LrFc/t7A5Furo/6O8/7EWTRkYuCc1zeHpxa7grahGkd7kotGmK+lelVHb6gv7bfl97YGryp4sA8gAQj8d5PB4nAPSfQTiy533O+auqapx9sHj3t4Ghl/tC27d/29sbDXq9XmQyGTmVSp2/dHH0HIDF/13Quav7dLlYGn2h78XNA/2xUz7fs/s3uTcBZOq6bpAoSZKh65CX5dLs7PwPY1cmzjwpyPcBgK/bZCW7I5h9mL0gy7n9jEHhnBmGYXLTNEXOmCFwrppEjlK5/F6b231i/QUmAECLp7XHKQi7Fc5235lPemZn5qhaqVLb5lY4HA4kkynj8uUfkZiYotxKAU6bbXVrozYlq2qNAUAwuOO1jp7eRG1xoV5vNGxks7P62prp9bgNt9tN2aVlAZwLdosFqFU0V0fI0hCtN+5eS7wkAgAVllMrbx5bZfWGB999qQqZtOiySIKi6qacy5PdahW5UjcNgxvV52PG34NHyHLn5hIhQSKIWPbkyeVwbumBOnI8auvpI+PWdZP9PGay9D2yCpxMEvXi3phZjB7gSjAscjKxRyuBAcS8Xq/HHwh99vobw0cXegYw0x4WbS4nI0Uj8cakXp+aYLmDbwlq+zYGXQXIMHlxBacsMtO107XcEyeY+dOzto6clQUBnSaaMZwuv250CETFtRxc1KjWzEohIUNcMACI8rZzdvqp1Fh5KLf4AcUNVHkUiO7VDh4dZbmXVGpy/WWyUq6q7mEd3eob0wmMOzgkOlyTWqsW2q+O/dlwft+bL1brTZvte0DRF5swiJZOpfTVN+92/MHdkYXpS35tb3DeoFsnV4uWpBpme9NxYa+Lr47krX505+8yWe/lC5dPRC1/80pzKXQBsAPDK0MEP/7j1J31+7vyTjz7+hKKxAydog5s48eYkcwAgIgbgPhEpRMQePS5cS2cySkfA5ywWy3J0W2icxYkBEBBnJgBhPcXUjCfbIAwAYoNDw5yJ/Xar5Zvp6YnU0/0N/QMCO5EkQRbfggAAAABJRU5ErkJggg==")
		if(L_WhenToWork == 1)
			AddBookmark("https://whentowork.com/logins.htm", "When to Work", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAACsklEQVQ4jXWSTWicVRSGn/feyddkmkxi2kBFGJt2GsKXKrVNwBEs/kYtCF3oplAQF1JbcC+4mJ0LEVe1ILrSiKAVESxSVEIWFauhVJqJaUozUy1pMY79yd98k+8eFzHTsdKzOu853Of8XXGXTcVxtLwcHkPhWdDuOxn9Djbe49PTuy5dutWMbjhxXIreXfmyv4/V1wwVkI0T3DlvtjN13PSB7tRRBFhg0zsvzP06A+A2AG3Za3s+6B46OR3dl/b49PDI5YvvjVR+G08dN12qub3VmY+yHf4opk9aO84AzBYKubHly299vHlg6Hzblutdqm+D9TZ7fHo66YhWAYbK5SSOS2dWsn+9vWPr470BezMDcLvhX25EesigIZFvrdA6L0A9WxvwslfMNJFd7qu52UIhlzqKO9YWD4ONyegl+J6NBzuH39i9feTotibBhScNenH2VblcStytJLML4NHM32dNOhWga0n+6Ts1wzEvPbexaAJPAVc6SX5c53nrB7seJUl7jvp5iWpAz8RxKep/5NiDiAMEHYzjUtTWeXU7Yi9wprH4QOU/V7iR+tEP/5x4mMB3DvbUs7UB18YTQF5ifz1bG1gkKhrcj+zbcrmUrANMC4L2bIf/emRu5gtz9k2ALil9kaCDBo2mNj0vmA8NxpsrkWnGUPfKkm0BCGa/CC6Y9KrEfsFJwQVDRwSjhv0wd+54tQkYrk7PI5tyhAMAlZ/fv4bxE0YhQJfJxoR9DuTXtU61ntUBKPWfpY7iZH5wH4BkV/5N3lbwlc2Wfi+oSVRp2Nn//cTh6vT8ZH7wRPD2+mR+8MRLa3yK11bnrLJpqfdiA0g7F44IW+mo9823AtQqJvOD+8yHQyb+cGtuIhetzSZRtDpULifcw3R3YLZQyN1I/aiwoqFuZFPZ9szxe0H+AfzWICmf21/CAAAAAElFTkSuQmCC")

		if(L_AccountClaim == 1)
			AddBookmark("https://accountclaim.stthomas.edu", "Account Claim", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAKYSURBVDhPXVJLTxNRGJ1770w7HWhpAWlBENGAUFAQoyIhQIIbCZqoxEhc487Ejcp/cOUPcOHCxAQXhriSqAlRQcMrgjwKtNCHpZRiS0vbmc7DM5aVN5nFfPc75zv3nI8Mu8Z0TSeEcIQo+YKqaIZuUEo4jtN1g1DCC8wqCSiigkPuOJ5qqk4pVRW1tsXtqrI73fajZBZXJU5bMpZOxtOhlRgTGAcI4Si4cTRVk5y2wYfdzV31Sq5Q1+I51epRckrztdM3RruBNFX8G8u8Yg+gcla5OtS6ORt6/+prKpJRC9p+OLn6LTD9YUmXjfrz1f7FsGDl0cljDrRabELvvYsH0cNbj3prGit1HVym6F1/Ih78U1nrnHm3hGeYYu6WjRUUVZSEjuvnyqsd0IO+1076FXJOScBZRSO2lFyZ92YzMGOEJMaBPsou3H/fVNbtzGdkqWeYn13ietfWeLciqWGqNbSc258PpZJbxAjU4QhkB2uVx4HH2cml1OhBe39uPpJan/FKZWOq0lcO3VJ4yyhkGNfBRms/IO7+i2cP8xnzY9yPYP3LpypA38DOy/n2nWEwfZBkAHDl2CXml4kcQ8Hsj3nChxtvdYHdJiqxuzYXC6/FPr+eim/tI0GTHFDM/QnYDif6RzsuDXt9sCNMiG3HY2j7Q1P+gc2/7AD0wAABzgqbpgoVPRFOwpe9+Z/5IWfzoi24l6lrcHQNNb59/nhpfsJVYi7aaAN0wsEmMZytf/J4zFT3D7bl0v107G0XWzbWp88eWTCYjBrhWFmADDjImDV1A3M7F8otYpiALl6drMzovRN4gVXLhCNyQhuGdYvuMfc6kwTz/ZWMV4GlyNgRhrVxRTbIBTx6dYYqAWeOSwvRyFkv+6OY77C3AgW2ixgFHHAAAAAElFTkSuQmCC")
		if(L_FileMaker == 1)
			AddBookmark("https://filem.stthomas.edu/fmi/webd", "FileMaker", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAADYElEQVQ4jV2TSUxcdQCHv/+bGWZ7DOsUxAbBwRQMjQZMqsYYa0mM1d6qJu6eOaiJt16M8aaHRk1rmkajIaTixSUa41ZsLBpAtlLKADPDNgU6GzNvmf883uKpF77kd/ouv8snOMTnA+uXLKuQq488MPXWZOy7w/4w4urV8cnV1ZU7xWLxnJTyxv5FdSbaGnyolrdzbY2Dt+uCTQsN4fvmC5XFYUX4svXR+z2/L/TZm//WjwGIcrlSWl9fb8xmt9E0LW/uOs01X0Wp6BVqex7mrB93NYTigUBQtgv296Uvte2D9AlgVRhG9TfXdYbC4TC6rqNpGu3t7WxubjA1Nc12JsvCp3mCXoiY0oSC4Pf9b+gNDq73t52dF6Yp3zZN43woFEIIAYDrugghCAQCzM7Nsra8xsTlNGbKIyyi1IkA0tH5pfB1WXFd+0q1WqVWq2HbNge2je04WJaFruv09vbx6BOP0XO6ASOgo2EghcvN6jR5Z/dHRVXVvWrVLJmmycHBAfbdOQ6O4yClJBwKockSSjPUhIsULmm5iOFUFv0AyVR27te/F0/+M7VEei1Doqebk08+wgunT3BPWzN+vx8XD1SbWt7Fw2Svls4mmo5t+Hqfeqfr2sTMywupnXvrOzvpHhzEUnxMTt4gubJNf18naiTIwvwcxbyOfqeO29Vl8jI1H492jPjCzYlhS/G99szZZ/no3Rdx1DCuqqI2NbM4exPPdhg83k0ymaSslSlsBkmVr1FztJEdPTOqSEN/ri3RjatGWdjX6Ok7ysevD/HeK0O0Jbr56/ocjuPQGm/FFiaWcCjIjKf66/4AUCxpDsTicfyhAFuei9vRyMjGDmMzq8TicSJ1CgAtLS1IqVNy1vBg8kh91z6AUheKzFRyOS68eopSrsLGyg6lXAVTl1RyOXRp4zgO8fgRdEOnZC3j90XSS7npWQAlFFV/2ktleP7cF2wsbbHyX4ouT/DSQIK9VIaH+3scy7KIxWJIKanoW0grf/luTL6OY6e2KoXdo/t7+QelUcPQakxcn2Xsys/IUvHbvOE/09kYTfr8vqdjDdHA+Pif9DQc/yRv7uwACICex99IGOXisKxWz7g2XT6/yIQi4R8isaaLaxNfpQA8z1M+/OD8hVvJW7ujo5fev/vgf/GPzFhRGqXhAAAAAElFTkSuQmCC")
		if(L_25Live == 1)
			AddBookmark("https://25live.collegenet.com/stthomas", "25Live", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAC4ElEQVQ4jQXBy29UVRwA4N/vnHvuPXPmzp1XgTvtOAVrp7adxjJt0XQKYUMaLWgQrcEYSdDozh3/ARt3rggxxo1GV7oyLlnUSAKS+GhBoUJxhpRpmaHTefQ+zrn3+H14/sr3dmz6IZ8c9z9cff3q598psAMSLUwUlq107a9+ux0QvVPNzpcKXP64HJCJMKhmbwmjVH+nfbm29d+GNiANX4q97T0enR4TgzFBb28+PFDKSKRYDubBYJqx3QHio4p/XHhSG2anRYpRgkZ396cadc8uvhAmzewBZl1PTsrhBhkfdzy7WUPtRmnra++rrtZV3po4Ni1CwX/9ozx0vSE5iwXf2g0IhG1BCZfrVQ3n84M3527cfA+OSkfvN4OPzlZv3tuNU+ojDC7nUv773Ys5lLNraU7S8ePFhoxMeqMvvnmg15RMPeypwstb81Mzj7n4/7F5+bfrGTqeY4nmL32336MziW1Tyzb1+szm4tDr7rDvw4kTD3z85ezQTY1d7Y44VUJNF4fSw+3vrOV1ZudSOQouIjhrcevDfp+/XqNWpByOy+/fq1EQPRRs7VTff2JbVMbH2ZEC/uf7F5OTRemtnEPHAEOuNZ/NTE8slQ/ZDj0CllLX63pAtDomIieQYl3TbOq0G7Y/OnajNljpKtUP0en7JyY2/5EaBZ2iZzzjCYo6T5AyHsin68qkzzb53c+Oh3/fPLlVOVlwd7u0d9POmOpxLG3GYthMUY4qAOqZIaG3pE42WJPaux+7Ud/dlWC2PLIykfC+kqNO2TVADAIBGJHGksFnvCCf5T2Pnz0bnkU96RJfdVCVnzhWzzCCcGaA1AoLWQFAD0F0688MvGwOwxt3M8vTQ28dfKJrajqxQ9TIZBwC0RiSgAQEBAAwJCtHYuP/0br2vk1bysFkeTc0Uc7WMI6XizAACOgZCQEWaEMStzVZkGDFBokNqaDAJRVNAgidDkRA6BgAgBLTWAICI/wOhx0gK8FhoHwAAAABJRU5ErkJggg==")
		if(L_MFASetup == 1)
			AddBookmark("https://aka.ms/mfasetup", "MFA Setup", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAKYSURBVDhPXVJLTxNRGJ1770w7HWhpAWlBENGAUFAQoyIhQIIbCZqoxEhc487Ejcp/cOUPcOHCxAQXhriSqAlRQcMrgjwKtNCHpZRiS0vbmc7DM5aVN5nFfPc75zv3nI8Mu8Z0TSeEcIQo+YKqaIZuUEo4jtN1g1DCC8wqCSiigkPuOJ5qqk4pVRW1tsXtqrI73fajZBZXJU5bMpZOxtOhlRgTGAcI4Si4cTRVk5y2wYfdzV31Sq5Q1+I51epRckrztdM3RruBNFX8G8u8Yg+gcla5OtS6ORt6/+prKpJRC9p+OLn6LTD9YUmXjfrz1f7FsGDl0cljDrRabELvvYsH0cNbj3prGit1HVym6F1/Ih78U1nrnHm3hGeYYu6WjRUUVZSEjuvnyqsd0IO+1076FXJOScBZRSO2lFyZ92YzMGOEJMaBPsou3H/fVNbtzGdkqWeYn13ietfWeLciqWGqNbSc258PpZJbxAjU4QhkB2uVx4HH2cml1OhBe39uPpJan/FKZWOq0lcO3VJ4yyhkGNfBRms/IO7+i2cP8xnzY9yPYP3LpypA38DOy/n2nWEwfZBkAHDl2CXml4kcQ8Hsj3nChxtvdYHdJiqxuzYXC6/FPr+eim/tI0GTHFDM/QnYDif6RzsuDXt9sCNMiG3HY2j7Q1P+gc2/7AD0wAABzgqbpgoVPRFOwpe9+Z/5IWfzoi24l6lrcHQNNb59/nhpfsJVYi7aaAN0wsEmMZytf/J4zFT3D7bl0v107G0XWzbWp88eWTCYjBrhWFmADDjImDV1A3M7F8otYpiALl6drMzovRN4gVXLhCNyQhuGdYvuMfc6kwTz/ZWMV4GlyNgRhrVxRTbIBTx6dYYqAWeOSwvRyFkv+6OY77C3AgW2ixgFHHAAAAAElFTkSuQmCC")
		if(L_MyDevices == 1)
			AddBookmark("https://mydevices.stthomas.edu", "MyDevices (Add MAC address)", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAKYSURBVDhPXVJLTxNRGJ1770w7HWhpAWlBENGAUFAQoyIhQIIbCZqoxEhc487Ejcp/cOUPcOHCxAQXhriSqAlRQcMrgjwKtNCHpZRiS0vbmc7DM5aVN5nFfPc75zv3nI8Mu8Z0TSeEcIQo+YKqaIZuUEo4jtN1g1DCC8wqCSiigkPuOJ5qqk4pVRW1tsXtqrI73fajZBZXJU5bMpZOxtOhlRgTGAcI4Si4cTRVk5y2wYfdzV31Sq5Q1+I51epRckrztdM3RruBNFX8G8u8Yg+gcla5OtS6ORt6/+prKpJRC9p+OLn6LTD9YUmXjfrz1f7FsGDl0cljDrRabELvvYsH0cNbj3prGit1HVym6F1/Ih78U1nrnHm3hGeYYu6WjRUUVZSEjuvnyqsd0IO+1076FXJOScBZRSO2lFyZ92YzMGOEJMaBPsou3H/fVNbtzGdkqWeYn13ietfWeLciqWGqNbSc258PpZJbxAjU4QhkB2uVx4HH2cml1OhBe39uPpJan/FKZWOq0lcO3VJ4yyhkGNfBRms/IO7+i2cP8xnzY9yPYP3LpypA38DOy/n2nWEwfZBkAHDl2CXml4kcQ8Hsj3nChxtvdYHdJiqxuzYXC6/FPr+eim/tI0GTHFDM/QnYDif6RzsuDXt9sCNMiG3HY2j7Q1P+gc2/7AD0wAABzgqbpgoVPRFOwpe9+Z/5IWfzoi24l6lrcHQNNb59/nhpfsJVYi7aaAN0wsEmMZytf/J4zFT3D7bl0v107G0XWzbWp88eWTCYjBrhWFmADDjImDV1A3M7F8otYpiALl6drMzovRN4gVXLhCNyQhuGdYvuMfc6kwTz/ZWMV4GlyNgRhrVxRTbIBTx6dYYqAWeOSwvRyFkv+6OY77C3AgW2ixgFHHAAAAAElFTkSuQmCC")
		if(L_PaperCut == 1)
			AddBookmark("https://print.stthomas.edu", "PaperCut", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAA2UlEQVQ4jaWQMQrCQBBF/4yRRRAsrZRAwIBXsBM8gIU5i2CrhScRAuIZbO1TLFikt9BUQUwyFhIwJoqbvGp3Zv9jZglvODtn0Ob2WkimALr4TqQ9bQOAlVfG/niYIDkJpP8jWILzQ0rphkBG4YJARGamYeBtBQKpgrnFdsxxBACdrNPL0iz8Kfgk5jgK5+ENAOyDDZWqyndcWTWgseDrCuqhrq7vvi6PYk8g90YTENGxieBiibWqI4gA7Jl5EnjBOS9W/wFhqxd6+Y+1PIFBuCwwDBcY+aNawSf44zwySmLFdQAAAABJRU5ErkJggg==")
		if(L_Panopto == 1)
			AddBookmark("https://stthomas.hosted.panopto.com", "Panopto", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAC6klEQVQ4jXVTTYiVZRR+znnf97vfvdc71/mpO2aQxLRwkxJYhLXQqKHFEAwZhCnl4E5aGKi4qOvKjS3DTU0waosICiPpB7RoMQxGuckSJ+xCOVydn/vjne+733fe97SoGxHjA2dxOM95eBbPA2wIpbnaV+XBNlebKwNKGzHpn9EzlY/GttTGTwbNEiUaBlAN0CUCiEDjANoIaEUcRcvNtdNHutMrAIgHSg/WRg97yE95nl7IW+nxg4uT+1X0hyB69eDi5P6lVnpcJDkvyK9VauXD/3WA2W1fvGSM2ZOqeacstBURnrBwmmn6FABEFC8IckKGH3tW/4zJn9Kgl1+/9eJFCwDG8HNEtDeG71DB7mHwNgv7dQZ6hgA4dqWgYVIjaRRUrhDR80pkAVyk9x/+eKRQeOBJp7C5ke3i5TcC2o7t4/08LDhYcKS7xMvPIK0w2wnn7S9CwfeS5lWbahirGD6bh3zckomNYYhKs2pHavf03rvEcFU3/GZTl247cg8RMYR96sjdQRRNctblZVHpBPh43a/3M81uRxwtrcndE0noNUTFt7LVtyyZO17lj8T30gAfi0o7X+G7fLTzyqpXuVHicl6gglZMta2KC1C709noRIC86iE7NOiso2g55iIVuZR7zW4e6U6vWADwgre9yRdE83UPX8yQDoFoHykZABDIARBuOHVzEnwCknJf/CUAMAAQtfprE6M7j5VM6VA/ZKOq+I5Am8CoMVgU+DZG9GsADli2L4vm5tKt2feu47qSQolAem7rlztcOb6sqj1VLAYvn7LBo3kITVLNjTVTBH6MyRSTLNv7xu8vXAOUCAAGIh888vnTQ9Hmz3rarRRNOYXXs6rBsTGvJSEZK3FppdNvT880puYHP/x3HEnrqPNMY2q+nazuduSuVHnzsEBir37TkB3ZYsl80007u2caU/N11JlA+m+UB6ijznXUAwB8MvH9oQQJA+piKqX7bj774f85Gxf5PrW93+0v1096+12CNesAAAAASUVORK5CYII=")
		if(L_Voicethread == 1)
			AddBookmark("https://auth-stthomas.voicethread.com/myvoice", "Voicethread", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAB20lEQVQ4jYWSPaiSYRTHf773GhroKy6R4OAgFOSQEgWXKEERnVwVxWhoFBScnGts8IWWQFTSxbEGl0DoRnOLi4sI5ReioOBH2Wm4viLv/Tpwhuc553fO+Z/nMXHZHgJp4CVwHzABQ+Ab8An4eQUD+8S3wBqQa/wP8B44NcIK0LwBNPpn4M5xgXe3QdlsVjwez/FdSYcfAH9vgq1Wq/T7fXG5XMbY41Pgtd/vP4lEIiwWC7bbLfV6HVVVicfj2O12wuEwbrebfD5Pp9OhXC7rzd8owIt+v4/X60XTNGw2G5vNhul0SjQaJRAI0O12ARiNRkwmk2PpzwF+62Mul0up1WoCiNlsllarJRaLRZLJpIiIOBwOo4SxopdarVZomkY6nUZVVWKxGMPhkPV6jdPpBEBVVeProQC/9EOpdLHYQqFAPB6nUqkAYDKZLoF7myrAuX4aDAZUq1WKxSJOp5N2u33RRVEOUxrsHOAR8E/X5fP5REQklUodtAaDQRERyeVykslkJJFI6LGnJ8AYcADPAMbjMbvdjkajcejY6/WYz+eEQiFmsxnNZpPValUGPuijmIEv3PIbj/wrcNeoxwxox3Ku8Y+ARYeuWu8T4BVwBtzb54yBH0AN+H6c/B/0D+l6d+jeDwAAAABJRU5ErkJggg==")
		if(L_Passwords == 1)
			AddBookmark("https://www.stthomas.edu/its/password", "UST Password Info Page", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAKYSURBVDhPXVJLTxNRGJ1770w7HWhpAWlBENGAUFAQoyIhQIIbCZqoxEhc487Ejcp/cOUPcOHCxAQXhriSqAlRQcMrgjwKtNCHpZRiS0vbmc7DM5aVN5nFfPc75zv3nI8Mu8Z0TSeEcIQo+YKqaIZuUEo4jtN1g1DCC8wqCSiigkPuOJ5qqk4pVRW1tsXtqrI73fajZBZXJU5bMpZOxtOhlRgTGAcI4Si4cTRVk5y2wYfdzV31Sq5Q1+I51epRckrztdM3RruBNFX8G8u8Yg+gcla5OtS6ORt6/+prKpJRC9p+OLn6LTD9YUmXjfrz1f7FsGDl0cljDrRabELvvYsH0cNbj3prGit1HVym6F1/Ih78U1nrnHm3hGeYYu6WjRUUVZSEjuvnyqsd0IO+1076FXJOScBZRSO2lFyZ92YzMGOEJMaBPsou3H/fVNbtzGdkqWeYn13ietfWeLciqWGqNbSc258PpZJbxAjU4QhkB2uVx4HH2cml1OhBe39uPpJan/FKZWOq0lcO3VJ4yyhkGNfBRms/IO7+i2cP8xnzY9yPYP3LpypA38DOy/n2nWEwfZBkAHDl2CXml4kcQ8Hsj3nChxtvdYHdJiqxuzYXC6/FPr+eim/tI0GTHFDM/QnYDif6RzsuDXt9sCNMiG3HY2j7Q1P+gc2/7AD0wAABzgqbpgoVPRFOwpe9+Z/5IWfzoi24l6lrcHQNNb59/nhpfsJVYi7aaAN0wsEmMZytf/J4zFT3D7bl0v107G0XWzbWp88eWTCYjBrhWFmADDjImDV1A3M7F8otYpiALl6drMzovRN4gVXLhCNyQhuGdYvuMfc6kwTz/ZWMV4GlyNgRhrVxRTbIBTx6dYYqAWeOSwvRyFkv+6OY77C3AgW2ixgFHHAAAAAElFTkSuQmCC")
		if(L_GPDownload == 1)
			AddBookmark("https://www.stthomas.edu/its/facultystaff/workingremotelyvpn", "Global Protect Download", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAKYSURBVDhPXVJLTxNRGJ1770w7HWhpAWlBENGAUFAQoyIhQIIbCZqoxEhc487Ejcp/cOUPcOHCxAQXhriSqAlRQcMrgjwKtNCHpZRiS0vbmc7DM5aVN5nFfPc75zv3nI8Mu8Z0TSeEcIQo+YKqaIZuUEo4jtN1g1DCC8wqCSiigkPuOJ5qqk4pVRW1tsXtqrI73fajZBZXJU5bMpZOxtOhlRgTGAcI4Si4cTRVk5y2wYfdzV31Sq5Q1+I51epRckrztdM3RruBNFX8G8u8Yg+gcla5OtS6ORt6/+prKpJRC9p+OLn6LTD9YUmXjfrz1f7FsGDl0cljDrRabELvvYsH0cNbj3prGit1HVym6F1/Ih78U1nrnHm3hGeYYu6WjRUUVZSEjuvnyqsd0IO+1076FXJOScBZRSO2lFyZ92YzMGOEJMaBPsou3H/fVNbtzGdkqWeYn13ietfWeLciqWGqNbSc258PpZJbxAjU4QhkB2uVx4HH2cml1OhBe39uPpJan/FKZWOq0lcO3VJ4yyhkGNfBRms/IO7+i2cP8xnzY9yPYP3LpypA38DOy/n2nWEwfZBkAHDl2CXml4kcQ8Hsj3nChxtvdYHdJiqxuzYXC6/FPr+eim/tI0GTHFDM/QnYDif6RzsuDXt9sCNMiG3HY2j7Q1P+gc2/7AD0wAABzgqbpgoVPRFOwpe9+Z/5IWfzoi24l6lrcHQNNb59/nhpfsJVYi7aaAN0wsEmMZytf/J4zFT3D7bl0v107G0XWzbWp88eWTCYjBrhWFmADDjImDV1A3M7F8otYpiALl6drMzovRN4gVXLhCNyQhuGdYvuMfc6kwTz/ZWMV4GlyNgRhrVxRTbIBTx6dYYqAWeOSwvRyFkv+6OY77C3AgW2ixgFHHAAAAAElFTkSuQmCC")
		if(L_CampusMap == 1)
			AddBookmark("https://campusmap.stthomas.edu", "Campus Map", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAKYSURBVDhPXVJLTxNRGJ1770w7HWhpAWlBENGAUFAQoyIhQIIbCZqoxEhc487Ejcp/cOUPcOHCxAQXhriSqAlRQcMrgjwKtNCHpZRiS0vbmc7DM5aVN5nFfPc75zv3nI8Mu8Z0TSeEcIQo+YKqaIZuUEo4jtN1g1DCC8wqCSiigkPuOJ5qqk4pVRW1tsXtqrI73fajZBZXJU5bMpZOxtOhlRgTGAcI4Si4cTRVk5y2wYfdzV31Sq5Q1+I51epRckrztdM3RruBNFX8G8u8Yg+gcla5OtS6ORt6/+prKpJRC9p+OLn6LTD9YUmXjfrz1f7FsGDl0cljDrRabELvvYsH0cNbj3prGit1HVym6F1/Ih78U1nrnHm3hGeYYu6WjRUUVZSEjuvnyqsd0IO+1076FXJOScBZRSO2lFyZ92YzMGOEJMaBPsou3H/fVNbtzGdkqWeYn13ietfWeLciqWGqNbSc258PpZJbxAjU4QhkB2uVx4HH2cml1OhBe39uPpJan/FKZWOq0lcO3VJ4yyhkGNfBRms/IO7+i2cP8xnzY9yPYP3LpypA38DOy/n2nWEwfZBkAHDl2CXml4kcQ8Hsj3nChxtvdYHdJiqxuzYXC6/FPr+eim/tI0GTHFDM/QnYDif6RzsuDXt9sCNMiG3HY2j7Q1P+gc2/7AD0wAABzgqbpgoVPRFOwpe9+Z/5IWfzoi24l6lrcHQNNb59/nhpfsJVYi7aaAN0wsEmMZytf/J4zFT3D7bl0v107G0XWzbWp88eWTCYjBrhWFmADDjImDV1A3M7F8otYpiALl6drMzovRN4gVXLhCNyQhuGdYvuMfc6kwTz/ZWMV4GlyNgRhrVxRTbIBTx6dYYqAWeOSwvRyFkv+6OY77C3AgW2ixgFHHAAAAAElFTkSuQmCC")


		Footer := "`n        </DL><p>`n    </DL><p>`n</DL><p>"
		FileAppend, %Footer%, C:\Users\%A_Username%\Downloads\TDT_Bookmarks.html
		MsgBox, Successfully exported TDT_Bookmarks.html to the Downloads folder.`n`nTo add these bookmarks to a browser, go to your browser's Boomark Manager (CTRL+SHIFT+O) and select "import bookmarks".
		return
	}
}




;========================================================================================================================================================
; - Middle Row Buttons - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;========================================================================================================================================================

ButtonTickets:
{
	Run, msedge.exe -inprivate "https://services.stthomas.edu/TDNext"
	;sleep 2000
	;SendInput, %AdminEmail% {tab}{tab}{enter}
	;WinWait, Sign In
	return
}
ButtonKB:
{
	Run, msedge.exe -inprivate "https://services.stthomas.edu/TDClient/1898/ClientPortal/KB/ArticleDet?ID=128248"
	;sleep 2000
	;SendInput, %AdminEmail% {tab}{tab}{enter}
	;WinWait, Sign In
	return
}
ButtonOnlineXstOutlook:
{
	Run, msedge.exe -inprivate "https://outlook.office.com/mail/techdesk@stthomas.edu/inbox"
	;sleep 2000
	;SendInput, %AdminEmail% {tab}{tab}{tab}{enter}
	;WinWait, Sign In
	return
}
ButtonBomgar:
{
	Run, msedge.exe -inprivate "https://remotesupport.stthomas.edu/saml"
	sleep 2000
	SendInput, %AdminEmail% {tab}
	return
}
ButtonADAC:  ;Launch ADAC and prompt for XST with the application launcher script using level 0 (non-administrator) permissions
{
	Run, powershell.exe "Unblock-File C:\ReferenceFiles\PowerShell\ApplicationLauncher.ps1",, Hide
	Run, powershell.exe "C:\ReferenceFiles\PowerShell\ApplicationLauncher.ps1" C:\Windows\System32\dsac.exe 0,, Hide
	WinWaitActive, powershell.exe
	return
}
ButtonAAD:
{
	Run, msedge.exe -inprivate "https://portal.azure.com/#view/Microsoft_AAD_IAM/UsersManagementMenuBlade/~/MsGraphUsers"
	;sleep 2000
	;SendInput, %AdminEmail% {tab}{tab}{tab}{enter}
	;WinWait, Sign In
	return
}

ButtonLAPS:  ;Launch LAPS and prompt for XST with the application launcher script using level 0 (non-administrator) permissions
{

	Run, powershell.exe "C:\ReferenceFiles\PowerShell\ApplicationLauncher.ps1" C:\ReferenceFiles\Shortcuts\AdmPwd.UI.exe,,  hide     ;-noexit before file path to hold it
	return
}

ButtonOpenMain:   ;Launch main windows needed for TD work, if they also have LAPS/MFA permissions azure will open
{
	;Run, C:\Users\%A_Username%\AppData\Local\Microsoft\Teams\Update.exe --processStart "Teams.exe"
	if(LoggedInAdmin = 1){
	Run msedge.exe -inprivate https://mimportal.stthomas.edu/IdentityManagement/
		}
	else{
	Run msedge.exe https://mimportal.stthomas.edu/IdentityManagement/
		}
	sleep 200
	Run, msedge.exe -inprivate "https://remotesupport.stthomas.edu/saml"
	sleep 200
	Run, msedge.exe -inprivate "https://services.stthomas.edu/TDClient/1898/ClientPortal/KB/ArticleDet?ID=128248"
	sleep 200
	Run, msedge.exe -inprivate "https://outlook.office.com/mail/techdesk@stthomas.edu/inbox"
	sleep 200
	if(UserCanLAPS){
		Run, msedge.exe -inprivate "https://portal.azure.com/#view/Microsoft_AAD_IAM/UsersManagementMenuBlade/~/MsGraphUsers"
		sleep 200
		Run, msedge.exe -inprivate "https://services.stthomas.edu/TDNext"
		sleep 1000
		Run, msedge.exe -inprivate https://services.stthomas.edu/TDClient/1898/ClientPortal/KB/ArticleDet?ID=140931
		sleep 3500
		SendInput, %AdminEmail% {tab}{tab}{enter}
		WinWait, Sign In
		return
		}
		else
		{
		Run, msedge.exe -inprivate "https://services.stthomas.edu/TDNext"
		sleep 1000
		Run, msedge.exe -inprivate https://services.stthomas.edu/TDClient/1898/ClientPortal/KB/ArticleDet?ID=140931
	sleep 3500
		SendInput, %AdminEmail% {tab}{tab}{enter}
	WinWait, Sign In
	return
		}
}

;========================================================================================================================================================
; - Right Row Buttons - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;========================================================================================================================================================

; If Password is pressed, a randomly generated password (from C:\ReferenceFiles\List.txt) is generated that is 15 characters long, capital, lowercase, and numbers, consisting of random foods, colors, and animals.
ButtonPasswordReset:
{
	Gui, 1:Submit, Hide
	RandomTotal :=
	RandomPass :=

	Gui, 6:Add, Text, x10 y+10 h20 +0x201 +center, Enter username to reset:
	Gui, 6:Add, Edit, vUserToReset x+5 yp w100 h20
	Gui, 6:Add, Checkbox, vUserMustChange x10 y+10 w150 h20 -wrap, User must change password?
	Gui, 6:Add, Button, x+10 yp w55 h20 +0x201 +Center Default gPasswordGenerator, Submit
	Gui, 6:Show, Center, Password Reset
	return

	; Begin random password genration
	PasswordGenerator:
	{
		Gui, 6:Submit, Hide
		{
			If UserToReset is not alnum
			{
				msgbox, 48, Error, Invalid username.
				Gui, 1:Show
				return
			}
		}
		Random1 := NewRandom()
		Random2 := NewRandom()
		; See if passwords match. If so, keep getting new ones until they don't match.
		CheckPasswords:
		{
			If(Random1 == Random2)
			{
				Random2 := NewRandom()
				GoTo, CheckPasswords
			}
		}
		NewRandom()
		{
			Random, RandomColor, 1, 73
			FileReadLine, RandomOutput, C:\ReferenceFiles\List.txt, %RandomColor%
			Return RandomOutput
		}
		RandomPass := Random1 . Random2
		Length := StrLen(RandomPass)
		NumberGenerator:
		If Length <15
		{
			Random, TempRandom, 1,9
			RandomTotal := RandomTotal . TempRandom
			Length++
			GoTo, NumberGenerator
		}
		RandomPass := Random1 . RandomTotal . Random2
		clipboard = %RandomPass%
		Gui, 6:Destroy

		; If user selected to use the password Generator function (and not automatic reset)
		if(OldPasswordGenerator)
		{
			Gui, 4:Font, s18
			Gui, 4:Add, Text, w250 h30 +0x201 +Center , %RandomPass%
			Gui, 4:Font, s10
			Gui, 4:Add, Button, w250 h25 +0x201 +Center Default gCopyClip, Copy to Clipboard
			Gui, 4:Show, Center, PasswordGenie
			OldPasswordGenerator = 0
			return
		}
		; Otherwise do the automatic reset process
		else
		{
			RunPowerShell:
			if WinExist("Windows PowerShell credential request")
				WinClose
			if FileExist ("C:\ReferenceFiles\PowerShell\TDTools_Reset.ps1")
			{
				Run, powershell.exe "Unblock-File C:\ReferenceFiles\PowerShell\TDTools_Reset.ps1",, Hide
				Run, powershell.exe "C:\ReferenceFiles\PowerShell\TDTools_Reset.ps1" %UserToReset% %RandomPass% %UserMustChange%
				Gui, 1:Show
			}
			else
			{
				msgbox, 48, Error, Could not find password reset utility at C:\ReferenceFiles\PowerShell\TDTools_Reset.ps1 on computer.
			}
			return
		}
		return
	}

	ButtonGeneratePassword:
	{
		Gui, 1:Submit, Hide
		RandomPass :=
		RandomTotal :=
		OldPasswordGenerator = 1
		GoTo, PasswordGenerator
		return
	}
}

ButtonPassLink:
{
	Run, msedge.exe -inprivate "https://services.stthomas.edu/TDClient/1898/ClientPortal/KB/ArticleDet?ID=96839"
	Run, msedge.exe -inprivate "https://services.stthomas.edu/TDClient/1898/ClientPortal/KB/ArticleDet?ID=141571"
	return
}


; If CMD is pressed, it will prompt the use for an asset, username, printer, or IP to enter. Depending on the input, it will either ping (asset, printer, IP), or net user (username) the input.
ButtonCMD:
{
	Gui, 1:Submit, Hide
	IfWinNotExist, CMDBot
	{
		;[Building Code][Room #]-[4-digit Printer #]-[C if color printer] for example: OEC008-6041-C
		Gui, 3:Add, Text, , Enter a username or email to look up a user.`nEnter a printer name, asset number, or IP address to ping a device.
		Gui, 3:Add, Edit, w210 h20 +Center vUserInput
		Gui, 3:Add, Button, xp+220 yp w100 h20 +Center Default gButtonCmdOk, Submit
		Gui, 3:Add, Button, xp-220 yp+30 w100 h30 gButtonMassPing, Mass Ping

		Gui, 3:Show, Center, CMDBot
		return
	}

	ButtonMassPing:
	{
		Gui, 3:Submit
		Gui, 3:Destroy

		Gui, MassPing:Add, Text, , Enter all asset numbers`r(each entry on its own line)
		Gui, MassPing:Add, Edit, xp yp+35 w130 R15 vAssetUserInput
		Gui, MassPing:Add, Button, w130 h20 +Center Default gButtonPingAll, Ping All

		Gui, MassPing:Show, Center, Mass Ping
		return
	}

	ButtonPingAll:
	{
		Gui, MassPing:Submit

		if AssetUserInput is space ;If user input is only a space, then it's invalid.
			GoTo InvalidInput
		StartPos := InStr(AssetUserInput, "A00", CaseSensitive := false)
		if(StartPos == 0) ;If no "A00" in input, then input is invalid.
			GoTo InvalidInput
		StringTrimLeft, AssetUserInput, AssetUserInput, StartPos-1 ;Trim off everything before the first "A00".
		EndPos := InStr(AssetUserInput, "A00", CaseSensitive := false, StartingPos := 0)
		AssetUserInput := SubStr(AssetUserInput, 1, EndPos-1+9) ;Trim off everything after the last "A00" +6 characters to include the whole asset number.
		AssetUserInput := StrReplace(AssetUserInput, "`n", ",")
		AssetList := StrSplit(AssetUserInput, ",")	;Tolkenize string by newline into AssetList.

		for Index, Asset in AssetList ;Test each asset input to make sure its a proper asset number.
		{
			if(StrLen(Asset) != 9) ;If the asset number is not 9 characters long, then it's invalid.
				GoTo InvalidInput
			if(SubStr(Asset, 1 , 1) != "A" && SubStr(Asset, 1 , 1) != "a")	;If the first chatacter is not a "A" or "a" then the input is invalid
				GoTo InvalidInput
			CharIndex := 2
			Loop 8 {
				if(Asc(SubStr(Asset, CharIndex, CharIndex)) < 48 || Asc(SubStr(Asset, CharIndex, CharIndex)) > 57) ;If any character after the first character "A" is not a number, then the input is invalid.
					GoTo InvalidInput
				CharIndex := CharIndex + 1
			}
		}

		if(FileExist("C:\ReferenceFiles\PowerShell\PingTest.ps1")) ;If the Mass Ping PowerShell script is there, then unblock it and run it.
		{
			Run, powershell.exe "Unblock-File C:\ReferenceFiles\PowerShell\PingTest.ps1",, Hide
			Run, powershell.exe "C:\ReferenceFiles\PowerShell\PingTest.ps1" %AssetUserInput%
			Gui, 1:Show
		}
		else
		{
			MsgBox, Error: Could not find password Mass Ping utility at C:\ReferenceFiles\PowerShell\PingTest.ps1 on computer.
			Gui, MassPing:Show, Center, Mass Ping
			return
		}

		Gui, MassPing:Show, Center, Mass Ping
		return

		InvalidInput:
		{
			MsgBox, Error: Input invalid. Please make sure the field only contains asset numbers formatted as A000##### with each entry on its own line.
			Gui, MassPing:Show, Center, Mass Ping
			return
		}
	}

	ButtonCmdOk:
	{
		Gui, 3:Submit
		Gui, 3:Destroy
		Gui, 1:Show
		if(UserInput == Space) ;If the user input is a space then it is invalid.
		{
			MsgBox, Error: Input invalid. Please try again.
			Gui, 1:Show
			return
		}
		StringReplace, UserInput, UserInput, `r`n, , All
		StringReplace, UserInput, UserInput, %A_Space%, , All

		;Figure out what the input likely is
		ShouldPing := False
		ShouldUser := False
		IsPrinterInput := False
		if(InStr(UserInput,"@")) ;If string contains @ then remove @stthomas.edu (last 13 characters).
		{
			StringLen, length, UserInput
			StringTrimRight, UserInput, UserInput, 13
		}
		else if(InStr(UserInput, ".")) ;If there are periods in the string then it is an ip address.
		{
			ShouldPing := True
		}
		else if(InStr(UserInput, "-")) ;If there is a "-" then check if the string is a secondary account or a printer.
		{
			DashPrinterNum := SubStr(UserInput, InStr(UserInput, "-"))
			if(StrLen(DashPrinterNum) >= 5) ;If there are less than 4 characters after the "-" then it's not a printer.
			{
				IsPrinterInput := True
				CharIndex := 2
				Loop 4 { ;If the next 4 characters after the first "-" are not numbers, then the input is not a printer.
					if(Asc(SubStr(DashPrinterNum, CharIndex, CharIndex)) < 48 || Asc(SubStr(DashPrinterNum, CharIndex, CharIndex)) > 57)
						IsPrinterInput := False
					CharIndex := CharIndex + 1
				}
			}
			else if(InStr(UserInput,"xst-") OR InStr(UserInput,"xtra-") OR InStr(UserInput,"ipc-") OR InStr(UserInput,"xadm-") OR InStr(UserInput,"cwb-")) ;If the string contains any of the secondary account strings, then it's a username.
			{
				ShouldUser := True
			}
		}
		else if(InStr(UserInput, "a00", CaseSensitive := false) AND (StrLen(UserInput) == 9)) ;If string contains a00 and is 9 characters long then it should ping.
		{
			ShouldPing := True
		}

		;Run CMD with the proper command
		if(IsPrinterInput)
		{
			if(FileExist("C:\ReferenceFiles\Printer.dat"))
			{
				FileDelete, C:\ReferenceFiles\Printer.dat
			}
			Sleep, 100
			;This command "RUNDLL32.EXE" is the only way I could find to get a printer's IP address from the commandline instantly. It grabs a bunch of printer data and writes it to the Printer.dat file.
			StpString := "/c RUNDLL32.EXE PRINTUI.DLL,PrintUIEntry /Xg /n \\ust-pm2p\" . UserInput . " /f C:\ReferenceFiles\Printer.dat /q | exit"
			MplsString := "/c RUNDLL32.EXE PRINTUI.DLL,PrintUIEntry /Xg /n \\ust-pm3p\" . UserInput . " /f C:\ReferenceFiles\Printer.dat /q | exit"
			Run, %comspec% %StpString%,, hide
			Run, %comspec% %MplsString%,, hide
			Sleep, 500
			;If the data file exists then that means the printer was found so the file should be read and the IP address should be extracted.
			if(FileExist("C:\ReferenceFiles\Printer.dat"))
			{
				FileRead, PrinterData, C:\ReferenceFiles\Printer.dat
				PrinterDataCutToIP := SubStr(PrinterData, InStr(PrinterData, "PortName:")+10)
				PrinterIp := SubStr(PrinterDataCutToIP, 1, InStr(PrinterDataCutToIP, "DriverName:")-3)
				Run, cmd.exe
				WinWaitActive, cmd.exe
				SendInput ping %PrinterIp% {enter}
				FileDelete, C:\ReferenceFiles\Printer.dat
				Gui, 1:Show
				return
			}
			else ;If the file does not exist then it did not get written to the location meaning the printer could not be found.
			{
				ShouldPing := True
			}
		}
		if(ShouldPing)
		{
			Run, cmd.exe
			WinWaitActive, cmd.exe
			SendInput ping %UserInput% {enter}
		}
		else
		{
			Run, cmd.exe
			WinWaitActive, cmd.exe
			SendInput net user %UserInput% /domain {enter}
		}
	}


	return
}

; If SnippingTool is pressed, Snipping Tool will launch, and prepare to take a snip.
ButtonSnippingTool:
{
	Gui, 1:Submit, Hide
	SendInput, #+s ;[Windows key]+SHIFT+S
	Sleep, 1500
	Gui, 1:Show
	WinActivate, Tech Desk Tools - V%VersionNumber%
	return
}

; If Copy Email is pressed, it will flag, copy, and close the currently selected email in Outlook app.
ButtonCopyEmail:
{
	IfWinExist, Tech Desk - Inbox - Tech Desk - Outlook
	{
		WinActivate, Tech Desk - Inbox - Tech Desk - Outlook
		WinWaitActive, Tech Desk - Inbox - Tech Desk - Outlook
		SendInput, {Insert} ;Flag email
		Sleep, 5
		SendInput, ^r		;Open as reply
		Sleep, 5
		SendInput, ^a		;Select all text
		Sleep, 5
		SendInput, ^c		;Copy to clipboard
		ClipWait, 3
		If(%OutlookVersion% = ProPlus)
		{
			SendInput, {Escape}
		}
		else  If(%OutlookVersion% = Professional)
		{
			SendInput, !{f4} ; potentially destructive operation, but it is the most reliable way (to date)
		}
	}
	else
	{
		msgbox, 48, Error, Could not find Tech Desk mailbox. Please make sure the Outlook desktop application is open and you have selected the correct mailbox.
	}
	return
}

ButtonCopyEmailOnline:
{
	IfWinExist, Mail - Tech Desk - Outlook
	{

		WinActivate, Mail - Tech Desk - Outlook
		WinWaitActive, Mail - Tech Desk - Outlook
		SendInput, {Insert} 	;Flag email
		Sleep, 5
		SendInput, r			;Open as reply

		ClipCounter := 0
		Clipboard := "blah"
		while(Clipboard == "blah")	;While the clipboard still equals what I set it to, meaning the SHIFT+RightArrow has not successfully been registered yet, keep trying to enter it.
		{
			Sleep, 100
			SendInput, +{Right}	;Send a SHIFT+RightArrow to allow CTRL+A to work
			Sleep, 10
			SendInput, ^c		;Copy to clipboard
			ClipCounter := ClipCounter+1
			if(ClipCounter > 50)
			{
				MsgBox, "Error: Failed to copy text from reply. This may happen if your browser is especially laggy. Please try again."
				return
			}
		}
		ClipCounter := 0
		while(InStr(Clipboard, "From: ") == 0)	;While the clipboard does not contain "From: ", meaning the reply has not been successfully copied, keep trying to select all text and copy it.
		{
			Sleep, 100
			SendInput, ^a		;Select all text
			Sleep, 10
			SendInput, ^c		;Copy to clipboard
			ClipCounter := ClipCounter+1
			if(ClipCounter > 50)
			{
				MsgBox, "Error: Failed to copy text from reply. This may happen if your browser is especially laggy. Please try again."
				return
			}
		}

		Sleep, 10
		SendInput, {Escape}		;Discard draft
		Sleep, 600
		SendInput, {Enter}		;Enter to confirm draft discard
		Sleep, 150
		SendInput, {Enter}		;2nd Enter just to make sure
	}
	else
		MsgBox, "Error: Could not find Tech Desk mailbox. Please make sure the Tech Desk Inbox is open in Outlook Web and its browser tab is currently selected."
	return
}


ButtonStPPrinters:		;If StP Printers is presssed, it opens \\ust-pm2p in file explorer
{
	run, explorer.exe \\ust-pm2p
	return
}
ButtonMPLSPrinters:		;If MPLS Printers is presssed, it opens \\ust-pm3p in file explorer
{
	run, explorer.exe \\ust-pm3p
	return
}

ButtonFindPrinters:
{
	run, C:\Windows\Find Printers.qds
	return
}

ButtonCampMap:		;If MPLS Printers is presssed, it opens \\ust-pm3p in file explorer
{
	Run, msedge.exe -incognito "https://campusmap.stthomas.edu/"
	return
}

;========================================================================================================================================================
; - Minimized Tool Bar - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;========================================================================================================================================================

ButtonMiniMenu:
{
	Gui, 1:Submit, Hide
	Gui, Mini:+AlwaysOnTop
	Gui, Mini:-MinimizeBox
	Gui, Mini:Margin , 5, 5
	Gui, Mini:Font, s9, %ButtonFont%
	Gui, Mini:Add, Button,   xp   y+6  w%ButtonWidth% h%ButtonHeight% gButtonPasswordReset, Password Reset
	Gui, Mini:Add, Button,   xp   y+6  w%ButtonWidth% h%ButtonHeight% gButtonGeneratePassword, Create Password
	Gui, Mini:Add, Button,   xp   y+6  w%ButtonWidth% h%ButtonHeight% gButtonPassLink, Password Article
	Gui, 1:Add, Button,   xp y+6  w%ButtonWidth% h%ButtonHeight% gButtonKB, Reference Menu
	Gui, Mini:Add, Button,   xp y+6  w%ButtonWidth% h%ButtonHeight% gButtonCMD, CMD
	Gui, Mini:Add, Button,   xp   y+6  w%ButtonWidth% h%ButtonHeight% gButtonSnippingTool, Screenshot
	Gui, Mini:Add, Button,   xp   y+6  w%ButtonWidth% h%ButtonHeight% gButtonCopyEmailOnline, Copy Email Online
	Gui, Mini:Add, Button,   xp   y+6  w%ButtonWidth% h%ButtonHeight% gButtonCampMap, Campus Map
	Gui, Mini:Add, Button,   xp   y+6  w%ButtonWidth% h%ButtonHeight% gButtonFindPrinters, Find Printers
	Gui, Mini:Add, Button,   xp   y+6  w%ButtonWidth% h%ButtonHeight% gButtonNotes, Notepad
	Gui, Mini:Show, x15 y15
	return
	
	
	ButtonNotes:
{
	Gui, 1:Submit, NoHide

	IfWinNotExist, Notes
	{
		Gui, 7:Add, Edit, vNote w250 h250 ;-VScroll
		Gui, 7:Add, Button, xp yp+260  w%ButtonWidth% h%ButtonHeight% gSaveNote,  Save to Desktop
		Gui, 7:Show, Center, Notes
	}
	else
	{
		Gui, 7:Show
	}
	return
}

SaveNote:
{
	Gui, 7:Submit, NoHide
	Gui, 7:Destroy

	If(Note)
	{
		FormatTime, TimeString,, h-m-stt_MMMM-dd-yyyy
		logdir = C:\Users\%Username%\Desktop\SavedNotes
		FileCreateDir, %logdir%	
		FileAppend, %Note%, %logdir%\%TimeString%.txt
	}
	return
}

	return
	
}


;Copies the clipboard
CopyClip:
{
	Clipboard = %RandomPass%
	return
}

; If the user closes any of the mini GUIs (PasswordGenie, MFA, CMD) it will show the main GUI and close the other ones.
5GuiClose:
{
	Gui, 4:Show
	Gui, 5:Destroy
	return
}
; Check if user closed any other GUI's - if so, then show them the main GUI.
MassPingGuiClose:
{
	Gui, MassPing:Destroy
	GoTo, ButtonCMD
}
AllLinksGuiClose:
MiniGuiClose:
6GuiClose:
4GuiClose:
3GuiClose:
2GuiClose:
{
	Gui, Destroy
	WinClose, Message Preview
	Gui, 1:Show
	return
}

; If the user closes the main GUI it will exit the application.
GuiClose:
ExitApp
