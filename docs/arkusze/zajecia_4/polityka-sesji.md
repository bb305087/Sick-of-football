# D5. Polityka sesji

## Logowanie

1. Użytkownik podaje e-mail i hasło w formularzu.
2. Backend zwraca access token, refresh token i dane użytkownika.
3. Oba tokeny są zapisywane przez `SecureStorageService` w
   `flutter_secure_storage`.
4. Access token jest dodawany do nagłówka `Authorization` żądań chronionych.

Hasło nie jest zapisywane lokalnie. Dane formularza powinny istnieć wyłącznie
w pamięci do czasu zakończenia żądania.

## Użycie i wygaśnięcie tokenów

Każdy chroniony odczyt wymaga access tokenu. Jeśli tokenu nie ma lub jest pusty,
klient przerywa operację i zgłasza konieczność ponownego logowania. Obsługa
odświeżania tokenu oraz jego unieważnienie są odpowiedzialnością backendu i
powinny być objęte osobnymi testami.

Po otrzymaniu odpowiedzi 401 aplikacja nie powinna pozostawiać użytkownika w
widoku udającym aktywną sesję. Należy wyczyścić tokeny i przekierować do
logowania.

## Wylogowanie

Wylogowanie wywołuje `SecureStorageService.clearTokens()`, które usuwa tokeny z
secure storage. Dodatkowo aplikacja powinna:

- wyczyścić dane dashboardu z pamięci;
- usunąć wybrane zdjęcie/plik tymczasowy;
- wyczyścić formularze i lokalne komunikaty sesji;
- unieważnić refresh token po stronie backendu, jeśli API to obsługuje;
- uniemożliwić powrót do chronionego widoku przyciskiem „wstecz”.

## Reinstalacja i nowe urządzenie

Po reinstalacji aplikacja nie powinna odtwarzać starej sesji z kopii zapasowej.
W tym celu tokeny muszą korzystać z ustawień typu `ThisDeviceOnly` na iOS, a
Android musi mieć jawnie zdefiniowane wykluczenia backupu dla danych sesyjnych.
Na nowym urządzeniu wymagane jest ponowne logowanie.

## Kopie zapasowe i retencja

- tokeny: brak eksportu i brak migracji na inne urządzenie;
- cache i pliki tymczasowe: nie są częścią backupu, usuwane po użyciu;
- dane backendowe: backupy kontroluje operator backendu, z ograniczonym dostępem
  i retencją;
- raporty medyczne: nie kopiować do logów ani lokalnego cache.

## Odpowiedzialność za zakończenie sesji

| Zdarzenie | Wymagane działanie klienta | Wymagane działanie backendu |
|---|---|---|
| Ręczne wylogowanie | Usunięcie tokenów i stanu w pamięci | Unieważnienie refresh tokenu/sesji |
| 401 od API | Wyczyszczenie sesji i ekran logowania | Zwrócenie poprawnego statusu i brak ujawnienia danych |
| Wygaśnięcie refresh tokenu | Ponowne logowanie | Unieważnienie rodziny tokenów |
| Reinstalacja | Brak odtworzenia sekretów z backupu | Stare sesje mogą zostać unieważnione przez politykę retencji |
| Utrata urządzenia | Użytkownik powinien zmienić hasło/unieważnić sesje | Endpoint unieważnienia wszystkich sesji |
