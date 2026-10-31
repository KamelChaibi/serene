"""Run once from the project root: python setup.py
Generates android/ via `flutter create`, then adds INTERNET permission,
the tel: query, and sets minSdk 23."""
import re, subprocess, pathlib, sys

subprocess.run("flutter create . --platforms=android --org org.serene",
               shell=True, check=True)

m = pathlib.Path("android/app/src/main/AndroidManifest.xml")
x = m.read_text(encoding="utf-8")
if "android.permission.INTERNET" not in x:
    block = ('\n    <uses-permission android:name="android.permission.INTERNET"/>\n'
             '    <queries>\n        <intent>\n'
             '            <action android:name="android.intent.action.VIEW"/>\n'
             '            <data android:scheme="tel"/>\n        </intent>\n    </queries>\n')
    x = re.sub(r"(<manifest[^>]*>)", r"\1" + block.replace("\\", "\\\\"), x, count=1)
    m.write_text(x, encoding="utf-8")

for name in ("build.gradle.kts", "build.gradle"):
    g = pathlib.Path("android/app") / name
    if g.exists():
        t = g.read_text(encoding="utf-8")
        t = t.replace("flutter.minSdkVersion", "23")
        g.write_text(t, encoding="utf-8")
        break
else:
    sys.exit("gradle file not found")
print("Done. Now: flutter pub get && flutter run --dart-define=API_URL=http://10.0.2.2:8787/chat")
