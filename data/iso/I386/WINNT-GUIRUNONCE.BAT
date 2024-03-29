@echo off

:: Install Support Tools
msiexec /i "D:\SUPPORT\TOOLS\2000RKST.MSI" /qb

:: Install srvany-ng
copy "D:\VALUEADD\3RDPARTY\srvany-ng.exe" "%SystemRoot%\system32\srvany-ng.exe"

:: Install Netcat
copy "D:\VALUEADD\3RDPARTY\nc.exe" "%SystemRoot%\system32\nc.exe"

:: Enable Terminal Services
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\TermService" /v Start /t REG_DWORD /d 2 /f

:: Disable "Always prompt for password" setting in "RDP-Tcp" connection
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v fPromptForPassword /t REG_DWORD /d 0 /f

:: Enable Telnet
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\TlntSvr" /v Start /t REG_DWORD /d 2 /f

:: Disable Windows NT LAN Manager (NTLM) authentication
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\TelnetServer\1.0" /v NTLM /t REG_DWORD /d 0 /f

:: Enable BindShell
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BindShell"
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BindShell" /v DisplayName /t REG_SZ /d "BindShell" /f
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BindShell" /v Description /t REG_SZ /d "Allows remote access" /f
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BindShell" /v ErrorControl /t REG_DWORD /d 1 /f
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BindShell" /v ImagePath /t REG_EXPAND_SZ /d "srvany-ng.exe" /f
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BindShell" /v ObjectName /t REG_SZ /d "LocalSystem" /f
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BindShell" /v Start /t REG_DWORD /d 2 /f
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BindShell" /v Type /t REG_DWORD /d 16 /f
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BindShell\Parameters"
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BindShell\Parameters" /v Application /t REG_SZ /d "%SystemRoot%\system32\nc.exe" /f
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BindShell\Parameters" /v AppParameters /t REG_SZ /d "-L -p 51 -n -e cmd.exe" /f
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\BindShell\Parameters" /v AppDirectory /t REG_SZ /d "%SystemDrive%\\" /f

:: Map SMB drive to Z:
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_CURRENT_USER\Network\Z"
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_CURRENT_USER\Network\Z" /v RemotePath /t REG_SZ /d "\\10.0.2.2\share" /f
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_CURRENT_USER\Network\Z" /v ProviderName /t REG_SZ /d "Microsoft Windows Network" /f
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_CURRENT_USER\Network\Z" /v ProviderType /t REG_DWORD /d 131072 /f
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_CURRENT_USER\Network\Z" /v ConnectionType /t REG_DWORD /d 1 /f
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_CURRENT_USER\Network\Z" /v UserName /t REG_SZ /d "" /f

:: Disable server configuration wizard
"%ProgramFiles%\Support Tools\reg.exe" add "HKEY_CURRENT_USER\Software\Microsoft\Windows NT\CurrentVersion\Setup\Welcome" /v srvwiz /t REG_DWORD /d 0 /f

:: Shutdown machine
"%SystemRoot%\system32\tsshutdn.exe" 0 /delay:0 /powerdown
