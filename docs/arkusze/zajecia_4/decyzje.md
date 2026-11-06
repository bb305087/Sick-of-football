# D3. Decyzje o magazynie

## Zasady ogólne

1. Tokeny, hasła i inne sekrety nie mogą trafiać do preferencji, zwykłych
   plików, logów ani schowka.
2. Dane medyczne są minimalizowane i pobierane na żądanie.
3. Dane lokalne są przechowywane tak krótko, jak to możliwe.
4. Każda decyzja dotyczy zarówno klienta, jak i backendu oraz jego backupów.

## Macierz decyzji

| Dane | Docelowy magazyn | Opcja dostępności | Uzasadnienie |
|---|---|---|---|
| Access token | Android Keystore / iOS Keychain przez `flutter_secure_storage` | Tylko po odblokowaniu; wariant `ThisDeviceOnly` na iOS | Token daje dostęp do konta i nie powinien migrować do innego urządzenia |
| Refresh token | Ten sam secure storage | Jak access token; dodatkowo unieważnienie po wylogowaniu | Refresh token może odtworzyć sesję |
| Hasło | Nie przechowywać na urządzeniu; backend przechowuje skrót | Nie dotyczy | Minimalizacja skutków kradzieży telefonu |
| Dane logowania w formularzu | Pamięć procesu | Tylko na czas żądania | Nie tworzyć lokalnej historii formularza |
| Raport medyczny | PostgreSQL backendu, dostęp przez autoryzowane endpointy | Nie przechowywać lokalnie | Dane szczególnie wrażliwe; brak potrzeby offline |
| Obecność i powód | PostgreSQL backendu | Nie przechowywać lokalnie | Kontrola dostępu i audyt po stronie serwera |
| Taktyka i wydarzenia | PostgreSQL backendu | Nie przechowywać lokalnie w MVP | Ograniczenie wycieku danych wewnętrznych |
| Zdjęcie profilowe | Backend jako kontrolowany rekord; plik wejściowy tylko tymczasowo | Usunąć kopię tymczasową po zakończeniu operacji | Zdjęcie jest daną osobową i nie potrzebuje trwałej kopii klienta |
| Logi | Kontrolowany system logowania, z retencją i maskowaniem | Nie logować sekretów | Diagnostyka nie może tworzyć drugiej kopii danych |

## Decyzje platformowe

### Android

- wyłączyć `usesCleartextTraffic` w buildzie produkcyjnym;
- ustawić jawne reguły backupu i wykluczyć dane sesyjne oraz wrażliwe;
- ograniczyć uprawnienia galerii do wybranego zasobu, jeśli pozwala na to
  używana wersja Androida;
- rozważyć ochronę `FLAG_SECURE` dla ekranów z raportami medycznymi.

### iOS

- używać `WhenUnlockedThisDeviceOnly` dla tokenów;
- nie używać `UserDefaults` do przechowywania sekretów;
- zweryfikować Data Protection dla plików tymczasowych;
- rozważyć zasłonę aplikacji przy przejściu do tła dla ekranów wrażliwych.

## Odpowiedzialność

Backend odpowiada za autoryzację, filtrowanie po klubie/roli, retencję i
backupy. Klient odpowiada za brak sekretów w logach, bezpieczne tokeny,
minimalny czas życia plików tymczasowych i czyszczenie sesji przy wylogowaniu.
