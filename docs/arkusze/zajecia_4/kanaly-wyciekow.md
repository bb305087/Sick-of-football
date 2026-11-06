# D4. Mapa kanałów wycieku

| Kanał | Czy dotyczy aplikacji? | Stan obecny | Działanie zamykające kanał |
|---|---|---|---|
| Pamięć aplikacji | Tak | Tokeny i dane API są obecne w pamięci procesu podczas działania | Nie utrzymywać danych dłużej niż potrzebne; czyścić stan po wylogowaniu |
| Pamięć współdzielona / pliki | Tak, ograniczenie do zdjęć i plików systemowego pickera | Zdjęcie może istnieć w cache/plikach systemu; aplikacja nie ma własnego trwałego cache | Usuwać kopie tymczasowe i nie zapisywać danych medycznych lokalnie |
| Logi | Tak | Klient nie loguje sekretów; backend/infrastruktura wymaga weryfikacji | Maskować Authorization, body, hasła, tokeny i dane medyczne; ograniczyć retencję |
| Kopie zapasowe | Tak | Brak jawnych reguł backupu Androida | Dodać `dataExtractionRules`, wykluczyć sekrety/cache; użyć `ThisDeviceOnly` na iOS |
| Schowek | Potencjalnie | Kod aplikacji nie używa schowka do tokenów ani haseł | Nie implementować kopiowania sekretów; dla kodów zaproszeń ustalić osobną politykę |
| Zrzuty ekranu | Tak | Brak `FLAG_SECURE` i zasłony przy przejściu do tła | Chronić ekran raportów medycznych i widoki z danymi osobowymi |
| Klawiatura | Tak | Formularze logowania przyjmują hasło; ustawienia autofill wymagają weryfikacji | `obscureText`, `textContentType: password`, wyłączenie uczenia dla sekretów |
| Cache HTTP / WebView | Ograniczone | `ApiClient` nie implementuje cache; aplikacja nie zawiera WebView | Nie cache'ować odpowiedzi z danymi osobowymi; `Cache-Control: no-store` dla endpointów wrażliwych |

## Priorytety

1. **Wysoki:** wyłączyć cleartext HTTP w produkcji i wymusić HTTPS.
2. **Wysoki:** zdefiniować backup exclusions dla Androida i sprawdzić Keychain
   accessibility na iOS.
3. **Wysoki:** potwierdzić maskowanie logów backendu i reverse proxy.
4. **Średni:** zablokować screenshoty lub zasłonić ekran raportów medycznych.
5. **Średni:** usunąć pliki tymczasowe zdjęć po udanym i nieudanym wyborze.

## Weryfikacja

- test instalacji na Androidzie z włączonym backupem;
- test logowania z inspekcją Logcat i logów serwera;
- test wylogowania i ponownego uruchomienia aplikacji;
- test przełącznika zadań na ekranie raportu medycznego;
- test odrzucenia uprawnień galerii/aparatu;
- test transportu, który odrzuca niezabezpieczony endpoint HTTP.
