# Model zagrożeń v1 — Sick of Football

## Skala oceny ryzyka

Ryzyko wyznaczono jako **Prawdopodobieństwo × Wpływ**:

- **Prawdopodobieństwo:** 1 — niskie, 2 — średnie, 3 — wysokie.
- **Wpływ:** 1 — niski, 2 — średni, 3 — wysoki.
- **Wynik:** 1–2 — niskie, 3–4 — średnie, 6–9 — wysokie.

Decyzje:

- **Mitygować** — wdrożyć zabezpieczenia i ponownie ocenić ryzyko.
- **Unikać** — usunąć funkcję lub sposób jej realizacji, który tworzy nieakceptowalne ryzyko.
- **Akceptować warunkowo** — dopuścić ryzyko tylko przy monitorowaniu i spełnieniu warunków.

## Rejestr zagrożeń

| ID | STRIDE | Zagrożenie i przykład w aplikacji | Aktywo / skutek | P | W | Ryzyko | Decyzja |
| :--- | :---: | :--- | :--- | :---: | :---: | :---: | :--- |
| T-01 | S | **Przejęcie konta przez skradziony token JWT.** Token uzyskany z kopii zapasowej, logów lub zainfekowanego urządzenia pozwala działać jako użytkownik. | Konto, dane zespołu, sesja | 2 | 3 | Wysokie (6) | **Mitygować:** krótki czas życia access tokenu, rotacja refresh tokenów, unieważnianie sesji i bezpieczne przechowywanie tokenów. |
| T-02 | S | **Podszywanie się pod innego użytkownika.** Atakujący zmienia `userId` w żądaniu API i wykonuje operację w cudzym imieniu. | Tożsamość i dane użytkownika | 3 | 3 | Wysokie (9) | **Mitygować:** tożsamość pobierać z tokenu po stronie serwera, nie ufać `userId` z klienta. |
| T-03 | T | **Zmodyfikowany plik APK.** Zmieniona aplikacja przechwytuje hasła lub modyfikuje wyświetlaną rolę użytkownika. | Integralność aplikacji i dane logowania | 2 | 3 | Wysokie (6) | **Mitygować:** podpisywanie wydań, Play Integrity/App Attest, wykrywanie debugowania i root/jailbreak jako warstwa dodatkowa. |
| T-04 | T | **Manipulacja żądaniami API przez proxy.** Użytkownik zmienia identyfikator wydarzenia, status obecności albo dane drużyny. | Obecności, wydarzenia, skład | 3 | 3 | Wysokie (9) | **Mitygować:** walidacja danych i autoryzacja obiektu na backendzie; testy z Burp Suite lub równoważnym proxy. |
| T-05 | R | **Brak rejestru zmian danych.** Użytkownik może zaprzeczyć zmianie składu, taktyki albo zgłoszenia obecności. | Niezaprzeczalność operacji | 2 | 2 | Średnie (4) | **Mitygować:** log audytowy z aktorem, czasem, obiektem, operacją i wynikiem; logów nie wolno modyfikować zwykłym użytkownikom. |
| T-06 | I | **Token lub dane osobowe w logach.** Debugowanie zapisuje JWT, e-mail albo powody nieobecności. | Tokeny i dane osobowe | 2 | 3 | Wysokie (6) | **Unikać:** zakazać logowania sekretów i danych zdrowotnych; maskować dane i kontrolować dostęp do logów. |
| T-07 | I | **Niezabezpieczona komunikacja.** Dane logowania lub dane drużyny są przesyłane przez HTTP albo przy błędnej walidacji certyfikatu. | Hasła, tokeny, dane aplikacji | 2 | 3 | Wysokie (6) | **Unikać:** wymusić HTTPS/TLS, odrzucać HTTP i nie stosować wyłączania weryfikacji certyfikatu w produkcji. |
| T-08 | I | **Wyciek danych wrażliwych z kopii lub urządzenia.** Powody nieobecności, kontuzje lub choroby trafiają do niezabezpieczonego cache albo kopii zapasowej. | Szczególnie wrażliwe dane zdrowotne | 2 | 3 | Wysokie (6) | **Mitygować:** minimalizacja danych, szyfrowanie, brak wrażliwego cache bez potrzeby, ograniczenie retencji i kontrola eksportu/kopii. |
| T-09 | I | **Niebezpieczny deep link zaproszenia.** Link `bklasa://invite/...` jest przechwycony lub spreparowany i otwiera nieautoryzowaną akcję. | Zaproszenia i członkostwo w klubie | 2 | 3 | Wysokie (6) | **Mitygować:** jednorazowe, krótko ważne tokeny zaproszeń, potwierdzenie użytkownika i ponowna autoryzacja na backendzie. |
| T-10 | I | **Nieizolowany WebView.** Zewnętrzna treść może przekierować użytkownika, wykonać niepożądany skrypt albo uzyskać dostęp do interfejsu aplikacji. | Dane sesji i urządzenie | 2 | 3 | Wysokie (6) | **Mitygować:** allowlista domen, brak mostka JavaScript bez potrzeby, izolacja WebView i filtrowanie przekierowań. |
| T-11 | D | **Brak limitu prób logowania.** Endpoint logowania jest wykorzystywany do brute force lub masowego tworzenia obciążenia. | Dostępność logowania i konta | 3 | 3 | Wysokie (9) | **Mitygować:** rate limiting per IP/konto/urządzenie, opóźnienia, blokady czasowe, monitoring i alerty. |
| T-12 | E | **Zmiana roli użytkownika.** Zmiana pola `role` z `Zawodnik` na `Trener` daje dostęp do zarządzania kadrą i taktyką. | Autoryzacja i dane klubu | 3 | 3 | Wysokie (9) | **Mitygować:** role nadawać tylko na backendzie, osobne uprawnienia dla operacji i testy negatywne dla każdego endpointu. |
| T-13 | E | **IDOR/BOLA w danych drużyny.** Zawodnik zmienia identyfikator klubu, raportu lub zawodnika i odczytuje dane innej drużyny. | Dane innych klubów i zdrowie zawodników | 3 | 3 | Wysokie (9) | **Mitygować:** sprawdzać relację użytkownik–klub–zasób przy każdym odczycie i zapisie; nie polegać na ukrywaniu przycisków w UI. |
| T-14 | E | **Dostęp do raportów zdrowotnych bez dodatkowej kontroli.** Trener lub przejęta sesja uzyskuje pełne raporty medyczne bez wymaganej biometrii i ograniczenia zakresu. | Dane zdrowotne zawodników | 2 | 3 | Wysokie (6) | **Mitygować:** minimalny zakres danych, biometria dla Trenera, ponowna autoryzacja, kontrola celu dostępu i audyt odczytów. |

