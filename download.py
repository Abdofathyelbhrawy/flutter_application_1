import urllib.request
import os

url1 = "https://github.com/googlefonts/cairo/raw/main/fonts/ttf/Cairo-Regular.ttf"
url2 = "https://github.com/googlefonts/cairo/raw/main/fonts/ttf/Cairo-Bold.ttf"

os.makedirs("assets/fonts", exist_ok=True)

print("Downloading Regular...")
urllib.request.urlretrieve(url1, "assets/fonts/Cairo-Regular.ttf")

print("Downloading Bold...")
urllib.request.urlretrieve(url2, "assets/fonts/Cairo-Bold.ttf")

print("Done downloading.")
