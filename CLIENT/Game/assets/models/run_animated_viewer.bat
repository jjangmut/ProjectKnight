@echo off
echo ===================================================
echo   Project Knight - Paladin 3D Animation Viewer
echo ===================================================
echo Starting local web server on port 8080...
start "" "http://localhost:8080/view_paladin_animated.html"
python -m http.server 8080
pause
