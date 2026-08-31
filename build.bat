@echo off
setlocal enabledelayedexpansion

REM CONFIG
set ProjectName=iridium
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

taskkill /f /im love-12.exe >nul 2>&1

if exist "%TempDir%" (
    rmdir /s /q "%TempDir%"
    timeout /t 1 >nul
)

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

echo Creating .love archive

powershell -Command "Get-ChildItem -Exclude 'objects','tools','release','logs','build_temp' | Compress-Archive -DestinationPath '%ZipFile%' -Force"

if not exist "%ZipFile%" (
    echo Failed to create zip
    exit /b 1
)

move /y "%ZipFile%" "%LoveFile%" >nul

echo Building Windows executable

copy /b "%LoveExe%" + "%LoveFile%" "%ReleaseDir%\temp.exe" >nul
rename "%ReleaseDir%\temp.exe" "%ProjectName%.exe"

echo Copying LOVE DLLs

copy "%LovePath%\*.dll" "%ReleaseDir%" >nul

echo Copying license

copy "%LovePath%\license.txt" "%ReleaseDir%\license.txt" >nul

mkdir "%ReleaseDir%\mods"

echo Building PS Vita VPK

mkdir "%VitaBuildDir%"
xcopy /E /I /Y /Q "%VitaTemplateDir%\*" "%VitaBuildDir%\" >nul

if not exist "%VitaBuildDir%\eboot.bin" (
    echo Vita template missing eboot.bin in %VitaTemplateDir%
    exit /b 1
)

copy /Y "%LoveFile%" "%VitaBuildDir%\game.love" >nul

"tools\7za.exe" a -tzip -mx=0 "%OutputVpk%" ".\%VitaBuildDir%\*"

if not exist "%OutputVpk%" (
    echo Failed to create VPK.
    exit /b 1
)

echo Build complete
echo Windows output: %OutputExe%
echo Vita output: %OutputVpk%

endlocal
