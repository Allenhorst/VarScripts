' VMware support script, VBscript version
' Copyright (C) 1998-2011 VMware, Inc.
'  Collects various configuration and log files, the information that this
'  collects is zipped and transferred to the VM's log file using xferlogs



Option Explicit
' On Error Resume Next

Const HKLM = &H80000002
Const COMMON_APPDATA = &H23&
Const USER_APPDATA = &H1A&
Const WINDOWS_DIR = &H24&

' The status constants are important and have to be kept
' in sync with VMware Workstation implementation

' vm-support script is not running
Const VMSUPPORT_NOT_RUNNING = 0
' vm-support script is beginning
Const VMSUPPORT_BEGINNING = 1
' vm-support script running in progress
Const VMSUPPORT_RUNNING = 2
' vm-support script is ending
Const VMSUPPORT_ENDING = 3
' vm-support script failed
Const VMSUPPORT_ERROR = 10
' vm-support collection not supported
Const VMSUPPORT_UNKNOWN = 100

Dim updateMode

Function ParseArgs
    Dim args, arg
    Set args = WScript.Arguments
    If args.Count = 1 Then
        arg = args(0)
        If arg = "-u" Then
            updateMode = True
        End If
    End If
End Function

' Convert and quote a string
Function Quote(strin)
    Dim siz, i, s
    siz = Len(strin)
    For i=1 to siz
        s = s & Chr(Asc(Mid(strin, i, 1)))
    Next
    Quote = Chr(34) & s & Chr(34)
End Function

Class VMsupport

    Private tmpdir, workdir, AppData, UserData, SysTemp, Username, VMTools
    Private WindowsDir
    Private Fso, Wsh, RegObj
    Private zipExe, xferlogs

    Private Sub Class_Initialize()
        Dim sh, desktop, objShell, wshNetwork

        Set RegObj=GetObject("winmgmts:{impersonationLevel=impersonate}!\\" _
                     & ".\root\default:StdRegProv")
        Set Fso = CreateObject("Scripting.FileSystemObject")

        set Wsh = WScript.CreateObject("WScript.Shell")
        set wshNetwork = CreateObject("WScript.Network")
        Username = wshNetwork.Username
        desktop = Wsh.SpecialFolders("Desktop")
        tmpdir = Wsh.Environment("Process").Item("Temp")
        SysTemp = Wsh.Environment("Process").Item("WINDIR") & "\Temp"
        workdir = tmpdir & "\vmsupport-" & Month(Date) _
                         & "-" & Day(Date) & "-" & Year(Date) & "-" _
                         & Hour(Now) & "-" & Minute(Now)
        If Fso.FolderExists(workdir) Then
            Fso.DeleteFolder(workdir)
        End If
        Fso.CreateFolder(workdir)
        Fso.CreateFolder(workdir & "\Misc")
        Fso.CreateFolder(workdir & "\TEMP")
        Fso.CreateFolder(workdir & "\SYSTEMP")
        Set objShell = CreateObject("Shell.Application")
        AppData = objShell.Namespace(COMMON_APPDATA).Self.Path
        UserData = objShell.Namespace(USER_APPDATA).Self.Path
        WindowsDir = objShell.Namespace(WINDOWS_DIR).Self.Path
        zipExe = """" & Left(WScript.ScriptFullName, Len(WScript.ScriptFullName) - _
        Len(WScript.ScriptName)) & "zip.exe"""
        xferlogs = """" & Left(WScript.ScriptFullName, Len(WScript.ScriptFullName) - _
        Len(WScript.ScriptName)) & "VMwareXferlogs.exe"""
        RegObj.GetStringValue HKLM, "Software\VMware, Inc.\VMware Tools",_
                              "InstallPath", VMTools
    End Sub

    'Updates the VM with the current state
    Sub Update(state)
        If updateMode = True Then
            Wsh.exec(xferlogs & " upd " & state)
        End If
    End Sub

    Sub DumpKey(DefKey, Path, filename)
        Dim f1
        Set f1 = fso.CreateTextFile(filename, True, True)
        EnumerateKey DefKey, Path, f1
        f1.Close
    End Sub

    ' Recursively enumerate registry and write it to a file.
    Sub EnumerateKey(DefKey, Path, OutFile)
        dim Keys, Names, types, i, j, value
        OutFile.WriteLine("[" & Path & "]")
        RegObj.EnumValues DefKey, Path, Names, Types
        if not IsNull(Names) and not IsNull(Types) Then
            for i = lbound(types) to ubound(types)
                select case types(i)
                    case 1
                        RegObj.GetStringValue defkey, path, names(i), value
                        If not isnull(names(i)) or not isnull(value) then
                            OutFile.WriteLine  names(i) & "=" & Quote(value)
                        end if
                    case 2
                        RegObj.GetExpandedStringValue defkey, path, names(i), value
                        if not isnull(names(i)) or not isnull(value) then
                            OutFile.WriteLine Quote(names(i)) & "=expand:" & Quote(value)
                        end if
                    case 3
                        RegObj.GetBinaryValue defkey, path, names(i), value
                        for j = lbound(value) to ubound(value)
                            value(j) = hex(cint(value(j)))
                        next
                        if not isnull(names(i)) or not isnull(value) then
                            OutFile.WriteLine Quote(names(i)) &"=hex:"& _
                                              join(value, ",")
                        end if
                    case 4
                        RegObj.GetDWordValue defkey, path, names(i), value
                        if not isnull(names(i)) or value then
                            OutFile.WriteLine Quote(names(i)) & "=dword:" & _
                                              hex(value)
                        end if
                end select
            next
        end if

        OutFile.WriteLine
        RegObj.EnumKey HKLM, Path, Keys
        Dim SubKey, NewPath
        If not IsNull(Keys) Then
            For Each SubKey In Keys
                NewPath = Path & "\" & SubKey
                EnumerateKey DefKey, NewPath,OutFile
            Next
        End if
    End Sub

    ' Run a command and save the output to a file
    Sub RunCmd(cmd, outfile)
        Dim f1, run, output
        Set f1 = fso.CreateTextFile(outfile, True, True)
        set run = Wsh.exec(cmd)
        output = run.stdout.readall
        f1.Write output
        f1.Close
    End Sub

    Sub CopyConfig()
        On Error Resume Next
        Fso.CopyFolder AppData & "\VMware", workdir & "\Global_Config"
        Fso.CopyFolder UserData & "\VMware", workdir & "\Current_User"
        Fso.CopyFile  SysTemp & "\vmware*.log", workdir & "\SYSTEMP\"
        Fso.CopyFile  SysTemp & "\vminst*.log", workdir & "\SYSTEMP\"
        Fso.CopyFile  tmpdir & "\vminst*.log", workdir & "\Temp\"
        Fso.CopyFile  SysTemp & "\vmmsi*.log", workdir & "\SYSTEMP\"
        Fso.CopyFile  tmpdir & "\vmmsi*.log", workdir & "\Temp\"
        If (Fso.FileExists(WindowsDir & "\setupapi.log")) Then
           Fso.CopyFile WindowsDir & "\setupapi.log" , workdir & "\SYSTEMP\"
        End If
        If (Fso.FileExists(WindowsDir & "\inf\setupapi.dev.log")) Then
           Fso.CopyFile WindowsDir & "\inf\setupapi.dev.log" , workdir & "\SYSTEMP\"
        End If
        If (Fso.FileExists(WindowsDir & "\inf\setupapi.offline.log")) Then
           Fso.CopyFile WindowsDir & "\inf\setupapi.offline.log" , workdir & "\SYSTEMP\"
        End If
        If (Fso.FileExists(WindowsDir & "\inf\setupapi.app.log")) Then
           Fso.CopyFile WindowsDir & "\inf\setupapi.app.log" , workdir & "\SYSTEMP\"
        End If
        On Error Goto 0
    End Sub

    Sub CopyEventLogs()
        CopyLog "Application", workdir & "\Misc\"
        CopyLog "System", workdir & "\Misc\"
        CopyLog "Security", workdir & "\Misc\"
    End Sub

    ' Copy the specified system event log to the specified directory
    Sub CopyLog(logname, directory)
        ' non-admin users would lack permissions
        On Error Resume Next
        Dim wmiobj, record, txtlog, msg, query

        Set wmiobj = GetObject("winmgmts:{impersonationLevel=impersonate," &_
                               "(Backup,Security)}!\\.\root\cimv2")

        query = "select * from Win32_NTEventLogFile where " &_
                "LogfileName='" & logname & "'"
        For Each record in wmiobj.ExecQuery(query)
            record.BackupEventLog(directory & logname & "-log.evt")
        Next

        '
        ' Query the entries in the log and write a simple text file that
        ' is more easily parseable by scripts, since the evt / evtx format
        ' is completely undocumented. Line format:
        '
        ' [timestamp]:[user]:[source]:[level]:[message]
        '
        ' Any new lines embedded in the messages are replaced by a space.
        ' Carriage returns are removed.
        '
        Set txtlog = Fso.CreateTextFile(directory & logname & "-log.txt", True, True)

        query = "SELECT * FROM Win32_NTLogEvent WHERE Logfile = '" & logname & "'"
        For Each record in wmiobj.ExecQuery(query)
            msg = Replace(record.Message, Chr(10), " ")
            msg = Replace(msg, Chr(13), "")
            txtlog.WriteLine("" &_
               record.TimeGenerated & ":" &_
               record.User & ":" &_
               record.SourceName & ":" &_
               record.EventType & ":" &_
               msg)
        Next
        txtlog.Close

        On Error Goto 0
    End Sub

    Sub CopyPowerManagementScripts
        Fso.CopyFile  VMTools & "\*.bat", workdir & "\Misc\"
    End Sub

    ' Save the MSinfo report, this takes a while and hence not saving text.
    Sub MSInfo
        Dim msinfo
        msinfo = Wsh.RegRead("HKLM\SOFTWARE\Microsoft\Shared Tools\MSInfo\Path")
        Wsh.Run Quote(msinfo) & " /nfo " & workdir & "\Misc\MSinfo.nfo", 0, True
    End Sub

    Sub Service
        Dim fp, wmi, s, Services
        Set fp = Fso.CreateTextFile(workdir & "\Misc\Service.txt", _
                                    True, True)
        Set wmi = GetObject("winmgmts:" _
            & "{impersonationLevel=impersonate}!\\.\root\cimv2")
        Set Services = wmi.ExecQuery _
                ("SELECT * FROM Win32_Service")
        For Each s in Services
            fp.WriteLine "System Name: " & s.SystemName
            fp.WriteLine "Service Name: " & s.Name
            fp.WriteLine "Service Type: " & s.ServiceType
            fp.WriteLine "Service State: " & s.State
            fp.WriteLine "ExitCode: " & s.ExitCode
            fp.WriteLine "Process ID: " & s.ProcessID
            fp.WriteLine "Accept Pause: " & s.AcceptPause
            fp.WriteLine "Accept Stop: " & s.AcceptStop
            fp.WriteLine "Caption: " & s.Caption
            fp.WriteLine "Description: " & s.Description
            fp.WriteLine "Desktop Interact: " & s.DesktopInteract
            fp.WriteLine "Display Name: " & s.DisplayName
            fp.WriteLine "Error Control: " & s.ErrorControl
            fp.WriteLine "Path Name: " & s.PathName
            fp.WriteLine "Started: " & s.Started
            fp.WriteLine "StartMode: " & s.StartMode
            fp.WriteLine "StartName: " & s.StartName
            fp.Writeline
        Next
        fp.Close
    End Sub

    Sub BootIni
        Dim i, bootdrive, bootini
        For i=0 to 23
            bootdrive = Chr(Asc("C")+i)
            bootini = bootdrive & ":\boot.ini"
            If Fso.FileExists(bootini) Then
                On Error Resume Next
		Dim bootinidest, f
		bootinidest = workdir & "\Misc\" & bootdrive & "_boot.ini"
                Fso.CopyFile  bootini, bootinidest

		' Unset the hidden and system bits if set.
		Set f = Fso.GetFile(bootinidest)
		If f.attributes and 4 Then
			f.attributes = f.attributes - 4
		End If
		If f.attributes and 2 Then
			f.attributes = f.attributes - 2
		End If
                ' GetFile would fail if the boot.ini was not copied
                On Error Goto 0
                If bootdrive = "C" Then
                    Exit For
                End If
            End If
        Next
    End Sub

    Sub Generate()
        Dim currDir
        Update VMSUPPORT_BEGINNING

        Set Fso = CreateObject("Scripting.FileSystemObject")

        DumpKey HKLM, "SOFTWARE\VMware, Inc.", workdir & "\Misc\vmware_reg.txt"
        DumpKey HKLM, "SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkCards", workdir & "\Misc\networkcards_reg.txt"
        RunCmd "ipconfig /all", workdir & "\Misc\ipconfig.txt"
        RunCmd "netstat -aens", workdir & "\Misc\netstat.txt"
        RunCmd "route print", workdir & "\Misc\route.txt"
	RunCmd "netsh winsock show catalog", workdir & "\Misc\winsock_catalog.txt"
        CopyPowerManagementScripts
        BootIni
        CopyConfig
        Service

        Update VMSUPPORT_RUNNING

        MSInfo
        CopyEventLogs

        currDir = Wsh.CurrentDirectory
        Wsh.CurrentDirectory = tmpdir
        RunCmd zipExe & " -r " & workdir & ".zip " & Fso.GetBaseName(workdir), _
               tmpDir & "\out.txt"
        Fso.DeleteFile tmpDir & "\out.txt", true
        Wsh.CurrentDirectory = currDir

        Wsh.exec(xferlogs & " enc " & workdir & ".zip ")
        Wscript.Echo "Support information has been uploaded to the Virtual "_
        & "Machine's log file, please run vm-support on the host to send"_
        & " the information to VMware support."
        If Fso.FolderExists(workdir) Then
           Fso.DeleteFolder workdir, true
        End If

        Update VMSUPPORT_ENDING

    End Sub

End class

If ScriptEngineMajorVersion < 5 or (ScriptEngineMajorVersion = 5 and ScriptEngineMinorVersion < 6) Then
    Wscript.Echo "This vm-support script expects Windows Script Version 5.6 or above.", _
                 Chr(10), _
                 "Windows Script update can be obtained from:", _
                 Chr(10), _
                 "http://www.microsoft.com/downloads/details.aspx?FamilyId=C717D943-7E4B-4622-86EB-95A22B832CAA&displaylang=en"
    Wscript.quit 0
End If

updateMode = False
'Parse the command line arguments
ParseArgs
Dim info
Set info = new VMsupport
info.Generate
