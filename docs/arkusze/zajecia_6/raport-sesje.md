# Zajęcia 6 - elementy sesji i scenariusze sprawdzenia

## 1.1 Elementy sesji

| Element | Gdzie powstaje | Gdzie leży | Ważny przez | Jak unieważnić | Problem | Decyzja i źródło |
|---|---|---|---|---|---|---|
| Hasło | Użytkownik; serwer zapisuje hash | Tylko hash Argon2id w bazie; hasło jest przesyłane podczas logowania i nie jest zapisywane przez klienta | Do zmiany przez użytkownika | Zmiana hasła; poprzednie tokeny są wtedy unieważniane | Brak stwierdzonego zapisu hasła po stronie aplikacji | Pozostawić Argon2id; `backend/app/security.py:12-29`; `backend/app/main.py:289-305` |
| Token dostępu | Serwer po poprawnym logowaniu lub odświeżeniu | `flutter_secure_storage` na urządzeniu; w żądaniu nagłówek `Authorization: Bearer` | 15 minut domyślnie | Wygaśnięcie, wyczyszczenie magazynu lub unieważnienie sesji po stronie serwera | Krótko ważny; wymaga sprawdzenia zachowania UI po nieudanym odświeżeniu | Pozostawić krótki TTL; `backend/app/core/config.py:15-16`; `lib/data/datasources/api_client.dart:160-163` |
| Token odświeżania | Serwer po poprawnym logowaniu lub odświeżeniu | `flutter_secure_storage`; serwer przechowuje tylko SHA-256 tokenu | 14 dni domyślnie | Wylogowanie, zmiana hasła, wygaśnięcie; ponowne użycie unieważnionego tokenu unieważnia rodzinę | Rotacja jest zaimplementowana; trzeba sprawdzić ją żądaniami | Pozostawić rotację; `backend/app/main.py:137-157`; `backend/app/main.py:249-277`; `backend/app/models/refresh_token.py:7-18` |
| Dane użytkownika / stan widoku | Serwer po logowaniu i chronionych odczytach | Pamięć aplikacji oraz stan ekranów | Do wylogowania lub odświeżenia danych | Wylogowanie i przejście do ekranu logowania | Do sprawdzenia, czy po wylogowaniu nie da się wrócić do danych przyciskiem „wstecz” | Czyścić stan razem z sesją; `lib/data/repositories/auth_repository.dart:12-27`; `lib/data/repositories/auth_repository.dart:64-76` |
| Klucz magazynu systemowego | Android Keystore / iOS Keychain przez bibliotekę | Systemowy secure storage | Do usunięcia tokenów lub wyczyszczenia danych aplikacji | `clearTokens()` i usunięcie danych aplikacji | iOS używa `unlocked_this_device`, Android szyfrowanych SharedPreferences | Pozostawić secure storage; `lib/data/datasources/secure_storage_service.dart:12-29`; `lib/data/datasources/secure_storage_service.dart:61-73` |
| Klucz lub dane biometrii | Nie dotyczy — aplikacja nie ma logowania biometrią | Nie dotyczy | Nie dotyczy | Nie dotyczy | Brak implementacji biometrii w aktualnym przepływie | Nie dodawać poza zakresem; sprawdzenie zależności i przepływu aplikacji |

### Przepływ wymagający potwierdzenia na zajęciach

1. Zalogować użytkownika i potwierdzić, że odpowiedź zawiera oba tokeny.
2. Sprawdzić, że chronione żądanie wysyła access token w nagłówku
   `Authorization`.
3. Wymusić odpowiedź `401`, sprawdzić wywołanie `/api/auth/refresh`,
   zapis nowej pary i ponowienie pierwotnego żądania.
4. Użyć starego refresh tokenu po rotacji i potwierdzić `401`.
5. Wylogować się, sprawdzić odpowiedź `204`, brak tokenów w magazynie oraz
   odrzucenie starej sesji przez serwer.

## 1.2 Scenariusze do sprawdzenia

| Scenariusz | Co powinno się stać | Co dzieje się u nas teraz | Jak sprawdziliśmy / do wykonania |
|---|---|---|---|
| Poprawne logowanie | Serwer zwraca sesję, a klient zapisuje tokeny bez zapisywania hasła | Jest `POST /api/auth/login`, zapis access i refresh tokenu oraz limit `10/minute` | Test API `backend/tests/test_api.py:29-40`; przejście logowania w aplikacji |
| Błędne logowanie i blokada | Błąd nie ujawnia, czy konto istnieje; kolejne próby są ograniczane | `401` dla błędnych danych; po 5 błędach konto jest blokowane na 15 minut, odpowiedź `429` | `backend/app/main.py:121-136`; wykonać serię błędnych logowań |
| Zwykłe żądanie chronione | Brak tokenu daje `401`, poprawny token daje dane zgodne z rolą | Klient dodaje nagłówek Bearer; endpointy rozróżniają role, np. raporty medyczne | `lib/data/datasources/api_client.dart:160-163`; `backend/tests/test_api.py:119-156` |
| Token access wygasa w trakcie pracy | Aplikacja odświeża sesję, ponawia żądanie; przy błędzie kieruje do logowania | Po `401` klient próbuje refresh; przy nieprawidłowym refreshu czyści tokeny | `lib/data/datasources/api_client.dart:88-156`; wymusić `401` i sprawdzić ekran |
| Rotacja refresh tokenu | Każde odświeżenie zwraca nową parę, a stara para przestaje działać | Serwer unieważnia stary token i zapisuje następcę w tej samej rodzinie | `backend/app/main.py:262-277`; wykonać dwa refreshy tym samym tokenem |
| Wylogowanie | Tokeny są usunięte z urządzenia, sesja jest unieważniona na serwerze, dane widoku znikają | Klient wysyła refresh token do `/logout`, a `finally` czyści tokeny; serwer unieważnia rodzinę | `lib/data/repositories/auth_repository.dart:64-76`; `backend/app/main.py:279-287`; sprawdzić stary token po logout |
| Zgubiony telefon | Tokeny nie powinny dać dostępu na innym urządzeniu; użytkownik powinien móc unieważnić sesje | Tokeny są w magazynie systemowym i oznaczone `unlocked_this_device`; dostępny jest endpoint `logout-all`, ale brak scenariusza UI do jego użycia | `lib/data/datasources/secure_storage_service.dart:17-27`; `backend/app/api/v1.py:211`; sprawdzić na urządzeniu / emulatorze |
| Zmiana hasła | Nowe hasło działa, stare nie działa, a wszystkie poprzednie sesje są zakończone | Serwer ustawia `tokens_valid_after` i unieważnia aktywne refresh tokeny użytkownika | `backend/app/main.py:289-305`; zmienić hasło w dwóch sesjach i sprawdzić obie |
| Reinstalacja aplikacji | Sesja nie powinna wrócić z kopii zapasowej; wymagane jest logowanie | Inicjalizacja magazynu czyści tokeny przy pierwszym uruchomieniu instalacji; zachowanie backupu wymaga testu platformowego | `lib/data/datasources/secure_storage_service.dart:75-87`; odinstalować, zainstalować ponownie i sprawdzić |
| Przechwycony access token | Token powinien działać tylko do wygaśnięcia i nie umożliwiać odświeżenia sesji | Access token ma TTL 15 minut, a refresh jest osobnym sekretem | `backend/app/core/config.py:15-16`; użyć kopii access tokenu przed i po TTL |
| Logowanie zewnętrznym dostawcą | Hasło powinno trafić wyłącznie do dostawcy, z PKCE i przeglądarką systemową | Nie dotyczy: aplikacja używa logowania e-mail + hasło | `lib/data/repositories/auth_repository.dart:12-27`; potwierdzić brak takiego przepływu |
| Logowanie biometrią | Biometria powinna odblokowywać klucz w secure storage, nie tylko zwracać `true/false` | Nie dotyczy: brak przepływu biometrycznego w aktualnej aplikacji | Wyszukanie zależności i przejście aplikacji; brak implementacji do testu |

## 1.3 Polityka sesji

| Parametr | U nas teraz | Docelowo na potrzeby projektu | Uzasadnienie i źródło |
|---|---|---|---|
| Ważność access tokenu | 15 minut | 15 minut | Ogranicza okno użycia przechwyconego tokenu; `backend/app/core/config.py:15` |
| Ważność refresh tokenu | 14 dni | 14 dni | Utrzymuje wygodę użytkownika przy rotacji; `backend/app/core/config.py:16`; rotacja `backend/app/main.py:262-277` |
| Wylogowanie po bezczynności | Brak osobnego timera bezczynności | 15 minut bezczynności aplikacji, jeśli łatwe do wdrożenia; w przeciwnym razie nie zmieniać bez testu UX | Obecny access token ogranicza sesję, ale nie ma dowodu timera bezczynności; do decyzji sekcji |
| Limit nieudanych logowań | 5 błędów, blokada na 15 minut; limit trasy 10/minutę | Pozostawić | Ograniczenie brute force jest po stronie serwera, `backend/app/main.py:121-136` |
| Operacje wymagające ponownego potwierdzenia | Zmiana hasła wymaga aktualnego access tokenu i bieżącego hasła | Zmiana hasła oraz operacje administracyjne wymagają ponownego potwierdzenia | Endpoint zmiany hasła sprawdza aktualne hasło, `backend/app/main.py:289-297` |
| Kod lub link resetu hasła | Brak endpointu resetu hasła w aktualnym przepływie | Nie wprowadzać do zakresu tych zajęć; osobna funkcja do zaprojektowania | W kodzie opisany jest tylko endpoint zmiany hasła; brak bezpiecznego resetu do potwierdzenia |
| Liczba aktywnych sesji i urządzeń | Serwer przechowuje wiele rekordów refresh tokenów; brak limitu liczby urządzeń | Pozostawić bez limitu w MVP, ale umożliwić `logout-all` po utracie urządzenia | Model ma `family_id`, `user_agent` i `ip`, `backend/app/models/refresh_token.py:7-18`; endpoint `backend/app/api/v1.py:211` |

## 1.4 Decyzje i dowody

1. **Pozostawiamy krótkotrwały access token i osobny refresh token.** Access token
   trwa 15 minut, refresh 14 dni; odświeżenie rotuje refresh token i zapisuje
   jego następcę. Dowód: `backend/app/core/config.py:15-16`,
   `backend/app/main.py:262-277`.
2. **Pozostawiamy tokeny w secure storage, nie w zwykłych preferencjach.**
   Android używa szyfrowanych SharedPreferences, a iOS Keychain
   `unlocked_this_device`. Dowód: `lib/data/datasources/secure_storage_service.dart:12-29`.
3. **Wylogowanie musi czyścić klienta niezależnie od odpowiedzi serwera.**
   Klient realizuje to w bloku `finally`; serwer unieważnia całą rodzinę tokenów.
   Dowód: `lib/data/repositories/auth_repository.dart:64-76`,
   `backend/app/main.py:279-287`.
4. **Zmiana hasła kończy aktywne sesje.** Serwer aktualizuje znacznik ważności
   tokenów i unieważnia wszystkie aktywne refresh tokeny użytkownika.
   Dowód: `backend/app/main.py:298-305`.
5. **Nie dodajemy do raportu logowania Google ani biometrii jako istniejących
   funkcji.** Te elementy z szablonu PDF nie występują w aktualnym przepływie;
   oznaczamy je jako nie dotyczące aplikacji, zamiast dopisywać niepotwierdzone
   zachowanie.
6. **Brakujące dowody uruchomieniowe uzupełniamy podczas zajęć.** Do wykonania
   pozostają przede wszystkim test wygaśnięcia access tokenu, ponownego użycia
   refresh tokenu, reinstalacji i zachowania UI po `401`. Wynik należy wpisać
   bezpośrednio w tabeli scenariuszy, wraz z datą i numerem commita/testu.

