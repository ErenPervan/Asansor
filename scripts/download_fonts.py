import os
import urllib.request

fonts_dir = "d:/Asansor/assets/fonts"
os.makedirs(fonts_dir, exist_ok=True)

base_url = "https://raw.githubusercontent.com/google/fonts/main/ofl/nunitosans/static/"

files = {
    "NunitoSans-Regular.ttf": "NunitoSans_7pt-Regular.ttf",
    "NunitoSans-Bold.ttf": "NunitoSans_7pt-Bold.ttf",
    "NunitoSans-Italic.ttf": "NunitoSans_7pt-Italic.ttf",
    "NunitoSans-BoldItalic.ttf": "NunitoSans_7pt-BoldItalic.ttf",
}

for local_name, remote_name in files.items():
    url = base_url + remote_name
    dest = os.path.join(fonts_dir, local_name)
    print(f"Downloading {local_name}...")
    urllib.request.urlretrieve(url, dest)

print("Fonts downloaded successfully.")
