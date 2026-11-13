# Raport bezpieczeństwa — Sick of Football

## 1. Kryptografia

### 1.1. Kryptografia w aplikacji

| Miejsce w aplikacji | Zadanie | Co jest teraz (plik:linia) | Klucz: skąd i gdzie | Problem | Decyzja i źródło |
|---|---|---|---|---|---|
| Hasła użytkowników | Ochrona haseł | `backend/app/security.py` — `argon2.PasswordHasher` do haszowania i weryfikacji | Klucz nie występuje; Argon2id przechowuje jedynie nieodwracalny hash w bazie | Brak stwierdzonego użycia zwykłego SHA-256 ani szyfrowania hasła | Pozostawić Argon2id; utrzymywać parametry biblioteki i `check_needs_rehash`. Źródło: OWASP Password Storage Cheat Sheet |
| Access token i refresh token | Poufność sesji | `lib/data/datasources/secure_storage_service.dart` — `flutter_secure_storage` | Klucze zarządzane przez Android Keystore/iOS Keychain; jawne opcje platformowe w `secure_storage_service.dart` | Brak szyfrowania aplikacyjnego nie jest problemem, jeśli sekret pozostaje w magazynie systemowym | Pozostawić secure storage, nie przenosić tokenów do preferencji. Na iOS używać `unlocked_this_device`; na Androidzie zaszyfrowanych preferencji. Źródło: dokumentacja `flutter_secure_storage`, OWASP MASVS-STORAGE |
| Odświeżanie sesji | Autentyczność i losowość tokenów | `backend/app/security.py` — `secrets.token_urlsafe(48)` oraz SHA-256 digest; klient odświeża token w `api_client.dart` | Surowy refresh token trafia tylko do secure storage; backend przechowuje digest | Brak stwierdzonego przewidywalnego generatora | Pozostawić CSPRNG i rotację refresh tokenów. Digest nie powinien być odwracany. Źródło: OWASP MASVS-AUTH i dokumentacja Python `secrets` |
| Powód nieobecności | Poufność i integralność danych szczególnie wrażliwych | `backend/app/crypto.py` — AES-GCM; użycie przy zapisie w `backend/app/main.py` | Klucze AES-256 pochodzą z konfiguracji środowiska; wersja klucza jest zapisywana obok ciphertextu | Klucz nie może trafić do repozytorium ani logów; wymagana bezpieczna konfiguracja środowiska | Pozostawić AES-256-GCM, 12-bajtowy losowy nonce i AAD wiążące rekord z wydarzeniem i użytkownikiem. Rotację umożliwia `key_id`. Źródło: OWASP MASVS-CRYPTO i dokumentacja `cryptography` |
| Identyfikatory tokenów i nonce | Losowość | `backend/app/security.py`; `backend/app/crypto.py` — `secrets` i `os.urandom` | Generator kryptograficzny po stronie backendu | Brak stwierdzonego `random`, `Math.random` lub stałego nonce | Pozostawić obecne generatory; każda operacja AES-GCM musi tworzyć nowy nonce. |

### 1.2. Kategorie błędów

| Kategoria | Wynik | Jak szukaliśmy |
|---|---|---|
| Klucz w kodzie | **Sprawdzone, brak** | Przegląd `backend/app`, `lib` i plików konfiguracyjnych pod kątem kluczy, sekretów i stałych haseł. Sekrety są pobierane z konfiguracji środowiska (`backend/app/main.py`, `backend/README.md`). |
| Przestarzały algorytm lub tryb | **Sprawdzone, brak** | Wyszukanie `AES`, `ECB`, `CBC`, `DES`, `MD5`, `SHA1`; właściwe szyfrowanie danych używa `AESGCM` (`backend/app/crypto.py`). |
| Przewidywalna losowość | **Sprawdzone, brak** | Wyszukanie `random`, `Math.random` i generatorów nonce; znaleziono `secrets.token_urlsafe` i `os.urandom`, bez użycia zwykłego generatora pseudolosowego. |
| Powtarzane wartości jednorazowe | **Sprawdzone, brak w implementacji** | `backend/app/crypto.py` tworzy nonce przy każdym szyfrowaniu; należy utrzymać tę właściwość podczas rotacji kluczy. |
| Hasło jako zwykły skrót | **Sprawdzone, brak** | Hasła przechodzą przez `PasswordHasher` (`backend/app/security.py`); SHA-256 służy wyłącznie do digestu opaque refresh tokenu (`security.py`). |
| Szyfrowanie bez integralności | **Sprawdzone, brak** | AES-GCM zapewnia poufność i tag uwierzytelniający; `decrypt` odrzuca zmieniony ciphertext lub AAD (`backend/app/crypto.py`). |

## 2. Stan aplikacji i plan

### 2.1. Stan Aplikacji

| Obszar | Status | Największe ryzyko / dowód |
|---|---|---|
| Funkcje MVP | **Warunkowo** | Są endpointy logowania, profilu, wydarzeń, obecności, taktyki, zdjęcia profilowego i raportów medycznych (`backend/app/main.py`) oraz odpowiadające ekrany Fluttera. Do potwierdzenia pozostaje pełny przebieg demo na urządzeniu. |
| Build z repozytorium | **Warunkowo** | Backend ma instrukcję uruchomienia Docker Compose i testy w `backend/README.md`; trzeba jeszcze potwierdzić czysty build Fluttera na docelowym środowisku bez ręcznych zmian w plikach platformowych. |
| Model zagrożeń | **Gotowe** | Model znajduje się w `docs/arkusze/zajecia_2/MODEL-ZAGROZEN-V1.md`, a dokumenty dotyczące magazynu, sesji i kanałów wycieku w `docs/arkusze/zajecia_4/`. |
| Uprawnienia | **Warunkowo** | Manifest Androida deklaruje Internet, kamerę, kalendarz i obrazy; zależności zawierają `image_picker`, `permission_handler` i `device_calendar` (`android/app/src/main/AndroidManifest.xml`, `pubspec.yaml`). Należy sprawdzić odmowę uprawnień i minimalny zakres na fizycznym urządzeniu. |
| Przechowywanie danych | **Gotowe z zastrzeżeniem** | Tokeny są zapisywane w `flutter_secure_storage`, z migracją i czyszczeniem przy pierwszej instalacji (`lib/data/datasources/secure_storage_service.dart`). Dane medyczne i powody nieobecności pozostają po stronie backendu. |
| Kryptografia | **Gotowe z zastrzeżeniem** | AES-GCM, Argon2id, CSPRNG i systemowy magazyn sekretów są zaimplementowane. Największe ryzyko to poprawne dostarczenie i rotacja sekretów środowiskowych, a nie wybór algorytmu. |

### 2.2. Plan do zajęć 6

| Zadanie | Odpowiedzialny | Sposób sprawdzenia |
|---|---|---|
| Wykonać czysty build Fluttera i uruchomić aplikację na emulatorze lub urządzeniu | Bartosz Bazan | Nowy checkout, `flutter pub get`, build/run bez ręcznej edycji konfiguracji; zapisać wynik w raporcie |
| Przejść demo MVP: logowanie, wydarzenie, obecność i odczyt taktyki | Cała sekcja | Nagranie lub demonstracja na żywo; sprawdzić role trenera i zawodnika |
| Zweryfikować konfigurację sekretów backendu i rotację klucza AES | Adam Grelewicz | Uruchomienie z `.env`, test szyfrowania/odszyfrowania oraz test starego `key_id`; brak sekretów w logach |
| Przetestować odmowę i ponowne nadanie uprawnień kamery, obrazów i kalendarza | Bartosz Bazan | Test na fizycznym Androidzie/iOS; aplikacja pokazuje błąd lub bezpieczny stan zamiast zawieszenia |
| Sprawdzić autoryzację endpointów i izolację danych między klubami/rolami | Oskar Sobolewski | Testy API z tokenem zawodnika, próbą dostępu do raportów medycznych i cudzych rekordów; oczekiwane `401/403` |
| Uzupełnić dowody uruchomieniowe oraz datę przeglądu dokumentów | Oskar Sobolewski | Dodać do raportu wersję commita, wynik testów i ewentualne poprawki |