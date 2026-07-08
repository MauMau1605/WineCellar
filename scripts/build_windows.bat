@echo off
echo Construction de l'executable Windows pour WineCellar...

:: Utilise l'installation locale de Flutter détectée sur votre système
set FLUTTER_BIN=C:\MesProgrammes\flutter\bin\flutter.bat

:: Exécute le build
call "%FLUTTER_BIN%" build windows

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Erreur lors du build.
	pause
    exit /b %ERRORLEVEL%
)

echo.
echo ✅ Build terminé avec succès !
echo L'exécutable se trouve dans le dossier :
echo build\windows\x64\runner\Release\
pause
