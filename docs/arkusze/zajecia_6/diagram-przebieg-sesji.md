# Raport — przebieg sesji i logowania

## Diagram sekwencji

```mermaid
sequenceDiagram
    participant U as Użytkownik
    participant A as Aplikacja Flutter
    participant M as Magazyn urządzenia
    participant S as Serwer

    rect rgb(240, 248, 255)
        Note over U,A: Logowanie
        U->>A: Podaje e-mail i hasło
        A->>S: POST /api/auth/login<br/>e-mail + hasło
        alt Dane poprawne
            S-->>A: 200 — access token<br/>refresh token + dane użytkownika
            A->>M: Zapis access_token i refresh_token
            Note over M: flutter_secure_storage<br/>Android: zaszyfrowane SharedPreferences<br/>iOS: Keychain
            A-->>U: Otwarcie ekranu głównego
        else Dane niepoprawne lub użytkownik zablokowany
            S-->>A: 401 lub 429
            A-->>U: Komunikat o błędzie logowania
        end
    end

    rect rgb(245, 245, 245)
        Note over A,S: Standardowe żądanie chronione
        A->>M: Odczyt access_token
        M-->>A: access_token
        A->>S: Żądanie API<br/>Authorization: Bearer access_token
        S-->>A: 2xx — dane lub 401
    end

    rect rgb(255, 248, 220)
        Note over A,S: Wygasnięcie access tokenu
        alt Access token lub refresh token są dostępne
            A->>S: POST /api/auth/refresh<br/>refresh_token
            S->>S: Sprawdzenie tokenu, właściciela i ważności
            alt Refresh token jest ważny
                S-->>A: Nowa para: access token + refresh token
                S->>S: Unieważnia stary refresh token i tworzy jego następcę
                A->>M: Zastąp oba tokeny nową parą
                A->>S: Ponów oryginalne żądanie<br/>Authorization: Bearer nowy access_token
                S-->>A: 2xx — dane
            else Refresh token jest nieznany, unieważniony lub wygasły
                S-->>A: 401
                A->>M: Usuń access_token i refresh_token
                A-->>U: Przekierowanie do logowania
            end
        else Brak access tokenu lub refresh tokenu
            A->>M: Usuń zapisane tokeny
            A-->>U: Sesja wygasła — wymagane ponowne logowanie
        end
    end

    rect rgb(252, 240, 240)
        Note over U,S: Ręczne wylogowanie
        U->>A: Wybiera „Wyloguj”
        A->>M: Odczytaj refresh_token
        M-->>A: refresh_token
        A->>S: POST /api/auth/logout<br/>refresh_token
        S->>S: Unieważnia rodzinę refresh tokenów
        S-->>A: 204 — brak treści
        Note over A,M: Niezależnie od odpowiedzi serwera
        A->>M: Usuń access_token i refresh_token
        A->>A: Usuń stan widoków i wróć do ekranu logowania
        A-->>U: Wyświetl ekran logowania
    end
```

## Podsumowanie danych sesji

- **Dane logowania:** e-mail i hasło; hasło nie jest zapisywane na urządzeniu.
- **Z serwera po logowaniu:** access token, refresh token oraz dane użytkownika.
- **Magazyn urządzenia:** oba tokeny przechowuje `flutter_secure_storage`.
  Android używa zaszyfrowanych SharedPreferences, a iOS Keychain z dostępnością
  `unlocked_this_device`.
- **Identyfikacja żądań:** chronione żądania wysyłają nagłówek
  `Authorization: Bearer <access token>`.
- **Access token:** ważny domyślnie 15 minut.
- **Refresh token:** ważny domyślnie 14 dni; przy odświeżeniu odbywa się rotacja
  — stary token jest unieważniany, a serwer zwraca nową parę.
- **Logowanie zewnętrzne:** aplikacja nie korzysta obecnie z zewnętrznego
  dostawcy tożsamości; przepływ opiera się na koncie e-mail i hasło.
