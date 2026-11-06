# D1. Inwentaryzacja danych

## Zakres

Inwentaryzacja obejmuje dane przetwarzane przez aplikację Flutter, backend FastAPI
i bazę PostgreSQL. Klasyfikacja opisuje wpływ ujawnienia danych, a nie tylko
miejsce ich fizycznego zapisu.

## Dane użytkownika i sesji

| Dane | Źródło | Lokalnie na urządzeniu | Backend / baza | Klasyfikacja | Retencja |
|---|---|---|---|---|---|
| Adres e-mail | Formularz rejestracji/logowania | Nie jest zapisywany lokalnie przez aplikację | Konto użytkownika | Poufne | Do usunięcia konta zgodnie z polityką backendu |
| Hasło | Formularz logowania/rejestracji | Nie powinno być zapisywane | Backend przechowuje wyłącznie bezpieczny skrót | Szczególnie wrażliwe | Tylko na czas obsługi formularza po stronie klienta |
| Access token JWT | Odpowiedź logowania | `flutter_secure_storage`, klucz `access_token` | Token używany do autoryzacji żądań | Poufne | Do wylogowania lub wygaśnięcia |
| Refresh token | Odpowiedź logowania | `flutter_secure_storage`, klucz `refresh_token` | Powiązany z sesją w bazie | Poufne | Do unieważnienia sesji |
| Rola i dane profilu | Odpowiedź backendu | W pamięci podczas działania dashboardu | Konto użytkownika | Poufne | Do czasu zakończenia sesji; źródłem prawdy jest backend |

## Dane funkcjonalne

| Dane | Źródło | Lokalnie na urządzeniu | Backend / baza | Klasyfikacja |
|---|---|---|---|---|
| Wydarzenia: treningi, mecze, terminy i lokalizacje | Trener | Tylko w pamięci widoku | API i PostgreSQL | Wewnętrzne |
| Obecność i powód nieobecności | Zawodnik | Tylko w pamięci formularza przed wysłaniem | API i PostgreSQL | Poufne; powód medyczny szczególnie wrażliwy |
| Raporty medyczne: diagnoza, szczegóły, daty | Uprawniony użytkownik | Tylko w pamięci formularza/widoku | API i PostgreSQL | Szczególnie wrażliwe |
| Taktyki, ustawienia i skład | Trener | Tylko w pamięci widoku | API i PostgreSQL | Wewnętrzne |
| Zaproszenia do klubu | Trener | Wyświetlane w pamięci | API i PostgreSQL | Poufne |
| Zdjęcie profilowe | Galeria/aparat | Plik wybrany przez `image_picker` i obiekt `File` w pamięci | Base64 w API i rekord profilu | Dane osobowe, poufne |

## Dane techniczne i pochodne

| Dane | Miejsce | Klasyfikacja | Uwagi |
|---|---|---|---|
| Żądania HTTP i odpowiedzi JSON | Pamięć klienta, serwer HTTP, ewentualne logi infrastruktury | Zależna od zawartości | Klient nie definiuje własnego cache HTTP |
| Logi backendu | stdout/logging FastAPI i środowisko uruchomieniowe | Zależna od zawartości | Nie wolno umieszczać tokenów, haseł ani danych medycznych |
| Pliki tymczasowe wybrane przez system | Katalog cache/tymczasowy systemu | Poufne, jeśli zawierają zdjęcie | Po anulowaniu lub zakończeniu operacji należy ograniczać czas przechowywania |

## Dane, których aplikacja obecnie nie zapisuje lokalnie

- brak własnej bazy SQLite;
- brak `shared_preferences`/`UserDefaults` dla tokenów;
- brak lokalnego cache taktyk, wydarzeń i raportów medycznych;
- brak zapisywania haseł;
- brak użycia schowka przez kod aplikacji.

## Źródła w kodzie

- [`secure_storage_service.dart`](../../../lib/data/datasources/secure_storage_service.dart)
  definiuje zapis i usuwanie tokenów;
- [`auth_repository.dart`](../../../lib/data/repositories/auth_repository.dart)
  zapisuje tokeny po logowaniu i usuwa je przy wylogowaniu;
- [`dashboard_repository.dart`](../../../lib/data/repositories/dashboard_repository.dart)
  pobiera dane chronione tokenem i wysyła zdjęcie profilowe;
- [`add_profile_photo_screen.dart`](../../../lib/presentation/screens/profile/add_profile_photo_screen.dart)
  obsługuje wybór zdjęcia z galerii/aparatu.
