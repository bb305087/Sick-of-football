# D2. Raport „przed”

Raport opisuje stan aplikacji przed wdrożeniem pełnej polityki ochrony danych.
Wnioski wynikają z przeglądu kodu, konfiguracji Android/iOS oraz zależności
Fluttera. Nie zastępuje testu na fizycznym urządzeniu ani inspekcji systemowych
logów produkcyjnych.

## Co znajduje się na urządzeniu

### Tokeny

Access token i refresh token są zapisywane przez `flutter_secure_storage`.
Jest to właściwy mechanizm magazynowania sekretów, ponieważ korzysta z
systemowych mechanizmów bezpieczeństwa platformy. W kodzie nie ustawiono jednak
jawnie opcji dostępności i `ThisDeviceOnly` dla iOS ani parametrów wymagających
uwierzytelnienia użytkownika dla Androida.

### Zdjęcia

Zdjęcie profilowe pochodzi z galerii lub aparatu. Wybrany plik jest przekazywany
do `File`, a następnie kodowany do Base64 i wysyłany do API. Własny trwały zapis
zdjęcia po stronie Fluttera nie jest implementowany, ale systemowy picker może
utworzyć plik tymczasowy/cache.

### Pozostałe dane

W repozytorium klienta nie znaleziono użycia SQLite, `shared_preferences`,
`UserDefaults` ani własnego katalogu dokumentów. Dane wydarzeń, taktyk,
obecności i raportów medycznych są pobierane do pamięci widoków.

## Logi i błędy

W kodzie klienta nie znaleziono `print` ani `debugPrint` przekazujących tokeny,
hasła lub dane użytkowników. Backend używa standardowego loggera, dlatego
konfiguracja środowiska uruchomieniowego musi dodatkowo zapewnić maskowanie
autoryzacji, request body oraz danych medycznych.

## Kopie zapasowe

Androidowy manifest nie zawiera jawnych ustawień `android:allowBackup` ani
`dataExtractionRules`. Oznacza to, że polityka backupu nie jest opisana na
poziomie projektu i powinna zostać zweryfikowana dla docelowej wersji Androida.
Tokeny zapisane w secure storage podlegają zasadom biblioteki i systemu, ale
nie należy zakładać, że wszystkie dane aplikacji są automatycznie wyłączone z
kopii.

## Kanały dodatkowe

- **Schowek:** aplikacja nie kopiuje tokenów ani haseł do schowka.
- **Zrzuty ekranu:** nie ma konfiguracji `FLAG_SECURE` ani zasłony widoku przy
  przejściu do przełącznika zadań.
- **Klawiatura:** pola hasła korzystają z kontrolek Fluttera, ale należy
  potwierdzić `obscureText` i ustawienia autofill w ekranie logowania.
- **Cache HTTP:** `ApiClient` używa `http.Client` i nie tworzy własnego cache.
  Cache/proxy po stronie infrastruktury musi respektować `Cache-Control`.
- **Transport:** Android ma `android:usesCleartextTraffic="true"`. Jest to
  ryzyko w produkcji i wymaga wyłączenia po przejściu API na HTTPS.

## Najważniejsze obserwacje

| Obszar | Stan przed | Ocena |
|---|---|---|
| Tokeny | Secure storage, brak jawnych opcji dostępności | Częściowo poprawnie |
| Dane medyczne | Brak lokalnej trwałej kopii po stronie klienta | Dobrze, ale zależne od backendu/logów |
| Backup Android | Brak jawnej polityki | Do uzupełnienia |
| Zrzuty ekranu | Brak ochrony | Do decyzji dla ekranów wrażliwych |
| Logi | Brak logowania sekretów w kliencie | Zweryfikować backend i produkcję |
| Transport | Cleartext dopuszczony w Androidzie | Nieakceptowalne dla produkcji |
