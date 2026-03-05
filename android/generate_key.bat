@echo off
"D:\Program Files\Java\jdk-25.0.2\bin\keytool.exe" -genkey -v -keystore heinplaytv.keystore -alias heinplaytv -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=HeinPlayTV, OU=Development, O=Hein, L=Beijing, ST=Beijing, C=CN" -storepass "HeinPlayTV2026!@#" -keypass "HeinPlayTV2026!@#"
echo Keystore generated successfully!