New-Item -ItemType Directory -Force -Path "assets\fonts"
Invoke-WebRequest -Uri "https://github.com/googlefonts/cairo/raw/main/fonts/ttf/Cairo-Regular.ttf" -OutFile "assets\fonts\Cairo-Regular.ttf"
Invoke-WebRequest -Uri "https://github.com/googlefonts/cairo/raw/main/fonts/ttf/Cairo-Bold.ttf" -OutFile "assets\fonts\Cairo-Bold.ttf"
