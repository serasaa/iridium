@echo off
setlocal enabledelayedexpansion

REM CONFIG
set ProjectName=rt
set ReleaseRoot=release
set ReleaseDir=%ReleaseRoot%\windowsBin
set VitaTemplateDir=tools\buildTemplates\vita
set LovePath=C:\Program Files\LOVE-12
set TempDir=build_temp

set LoveExe=%LovePath%\love-12.exe
set ZipFile=%TempDir%\game.zip
set LoveFile=%TempDir%\%ProjectName%.love
set VitaBuildDir=%TempDir%\vita
set OutputExe=%ReleaseDir%\%ProjectName%.exe
set OutputVpk=%ReleaseRoot%\%ProjectName%.vpk

echo Cleaning old build...

REM kill anything that might still be holding files (important)
taskkill /f /im love-12.exe >nul 2>&1

REM force delete with retry (Windows can be stubborn)
if exist "%TempDir%" (
    rmdir /s /q "%TempDir%"
    timeout /t 1 >nul
)

REM second safety pass (fixes random "file still exists")
if exist "%TempDir%" (
    rmdir /s /q "%TempDir%"
)

if exist "%ReleaseDir%" (
    rmdir /s /q "%ReleaseDir%"
    timeout /t 1 >nul
)

if exist "%ReleaseDir%" (
    rmdir /s /q "%ReleaseDir%"
)

if exist "%OutputVpk%" (
    del /f /q "%OutputVpk%"
)

mkdir "%TempDir%"
mkdir "%ReleaseRoot%"
mkdir "%ReleaseDir%"

echo Creating .love archive...

powershell -Command "Get-ChildItem -Exclude 'objects','tools','release','logs','build_temp' | Compress-Archive -DestinationPath '%ZipFile%' -Force"

if not exist "%ZipFile%" (
    echo Failed to create zip
    exit /b 1
)

move /y "%ZipFile%" "%LoveFile%" >nul

echo Building Windows executable...

copy /b "%LoveExe%" + "%LoveFile%" "%ReleaseDir%\temp.exe" >nul
rename "%ReleaseDir%\temp.exe" "%ProjectName%.exe"

echo Copying LOVE DLLs...

copy "%LovePath%\*.dll" "%ReleaseDir%" >nul

echo Copying license...

copy "%LovePath%\license.txt" "%ReleaseDir%\license.txt" >nul

mkdir "%ReleaseDir%\mods"

echo Building PS Vita VPK with 7-Zip because PowerShell is a liar...

mkdir "%VitaBuildDir%"
xcopy /E /I /Y /Q "%VitaTemplateDir%\*" "%VitaBuildDir%\" >nul

if not exist "%VitaBuildDir%\eboot.bin" (
    echo Vita template missing eboot.bin in %VitaTemplateDir%
    exit /b 1
)

copy /Y "%LoveFile%" "%VitaBuildDir%\game.love" >nul

REM The magic 7-Zip line! 
REM a = add to archive, -tzip = force standard zip format, -mx=0 = absolute zero compression
"tools\7za.exe" a -tzip -mx=0 "%OutputVpk%" ".\%VitaBuildDir%\*"

if not exist "%OutputVpk%" (
    echo Failed to create VPK. Did you put 7za.exe in the tools folder, sister?
    exit /b 1
)

echo Build complete
echo Windows output: %OutputExe%
echo Vita output: %OutputVpk%

endlocal
