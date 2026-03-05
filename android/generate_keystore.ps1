$keytoolPath = "C:\Program Files\Common Files\Oracle\Java\javapath\keytool.exe"
& "$keytoolPath" -genkey -v -keystore heinplaytv.keystore -alias heinplaytv -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=HeinPlayTV, OU=Development, O=Hein, L=Beijing, ST=Beijing, C=CN" -storepass "HeinPlayTV2026!@#" -keypass "HeinPlayTV2026!@#"
Write-Host "Keystore generated successfully!"
