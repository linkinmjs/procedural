@echo off
rem Doble click y listo: levanta el servidor del Level Workshop y abre el
rem editor en el navegador. Cerrar esta ventana detiene el servidor.
cd /d "%~dp0..\.."
start "" /b cmd /c "timeout /t 1 /nobreak >nul && start "" http://localhost:8080/tools/level-editor/"
node tools\level-editor\serve.js
pause
