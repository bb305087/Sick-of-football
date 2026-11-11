# Testowanie ochrony zrzutów ekranu

Widok szczegółów raportu medycznego włącza Androidowe `FLAG_SECURE`. Zrzuty
ekranu wykonywane przez Androida powinny więc zawierać czarny obraz zamiast
treści raportu.

Przycisk wykonywania zrzutu ekranu na pasku emulatora Androida nie obsługuje
tej flagi okna w niezawodny sposób, ponieważ przechwytuje obraz emulatora poza
oknem aplikacji. Do weryfikacji używaj ADB.

## Wymagania wstępne

Uruchom aplikację Flutter i otwórz widok szczegółów raportu medycznego. Pozostaw
otwarty terminal, w którym działa `flutter run`, i użyj drugiego terminala
PowerShell.

W katalogu głównym projektu dodaj Android SDK Platform Tools do bieżącej sesji
terminala:

```powershell
cd D:\sick_of_football
$env:Path += ";C:\Users\Bartek\AppData\Local\Android\Sdk\platform-tools"
```

Sprawdź, czy emulator lub fizyczne urządzenie jest podłączone:

```powershell
adb devices
```

Urządzenie musi mieć status `device`, na przykład:

```text
emulator-5554    device
```

## Wykonanie chronionego zrzutu ekranu

Uruchom to polecenie, gdy raport medyczny jest widoczny:

```powershell
cmd /c '"C:\Users\Bartek\AppData\Local\Android\Sdk\platform-tools\adb.exe" exec-out screencap -p > report.png'
```

Zrzut zostanie zapisany jako `D:\sick_of_football\report.png`. Otwórz go i
sprawdź, czy treść aplikacji jest czarna.

Nie używaj bezpośrednio PowerShella do przekierowania danych binarnych:

```powershell
adb exec-out screencap -p > report.png
```

To polecenie może utworzyć nieprawidłowy plik PNG, ponieważ PowerShell może
zmodyfikować dane binarne. Polecenie `cmd /c` zachowuje bajty zrzutu.

## Oczekiwane rezultaty

- Zrzut ADB podczas oglądania raportu medycznego: czarna treść aplikacji.
- Zrzut ADB na innych ekranach: normalna treść aplikacji.
- Zrzuty wykonywane przyciskiem emulatora: nie są poprawnym testem tego
  mechanizmu.
- Na fizycznym urządzeniu z Androidem zwykły zrzut systemowy powinien zostać
  zablokowany lub utworzyć czarny obraz.
