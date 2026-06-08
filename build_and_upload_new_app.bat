@echo off
echo ===================================================
echo Building Nova Study Release APK...
echo ===================================================
cd NEW-APP
call D:\flutter\bin\flutter.bat build apk --release

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter build failed with exit code %ERRORLEVEL%.
    exit /b %ERRORLEVEL%
)

echo ===================================================
echo Uploading APK to Catbox...
echo ===================================================
set APK_PATH=build\app\outputs\flutter-apk\app-release.apk

if not exist "%APK_PATH%" (
    echo [ERROR] APK file not found at %APK_PATH%
    exit /b 1
)

for /f "tokens=*" %%i in ('curl.exe -s -F "reqtype=fileupload" -F "fileToUpload=@%APK_PATH%" https://catbox.moe/user/api.php') do set UPLOAD_URL=%%i

if "%UPLOAD_URL%"=="" (
    echo [ERROR] Upload failed or returned empty response.
    exit /b 1
)

echo ===================================================
echo UPLOAD SUCCESSFUL!
echo Download URL: %UPLOAD_URL%
echo ===================================================
