# Karta projektu - Bezpieczeństwo Aplikacji i Systemów Mobilnych

Szablon do wypełnienia przez sekcję na zajęciach 1. Finalną wersję umieszczacie w `README` repozytorium przed zajęciami 2. Karta jest punktem odniesienia przez cały semestr: zmiany zgłaszacie prowadzącemu.

## Informacje o sekcji

| Pole | Wartość |
| :--- | :--- |
| **Nazwa sekcji / aplikacji** | Sick of Football |
| **Technologia** | Flutter |
| **Skład sekcji (imię i nazwisko)** | Bartosz Bazan, Oskar Sobolewski, Adam Grelewicz |
| **Link do repozytorium** | [https://github.com/bb305087/Sick-of-football](https://github.com/bb305087/Sick-of-football) |
| **Backend** | Python FastAPI + PostgreSQL |

---

## 1. Koncepcja aplikacji

Opiszcie aplikację w maksymalnie trzech zdaniach: co robi, dla kogo i jaki problem rozwiązuje.

> Aplikacja służy do zarządzania amatorskimi drużynami piłkarskimi, ułatwiając komunikację na linii trener-zawodnicy. Rozwiązuje problem nieprzewidywalnej frekwencji na treningach i meczach, pozwalając zawodnikom zgłaszać absencje (np. praca, kontuzja, choroba), a trenerowi udostępniać przedmeczowe założenia taktyczne.

* **Grupa docelowa:** Trenerzy, zarząd i zawodnicy klubów z niższych lig piłkarskich (np. B-Klasa, A-Klasa)
* **Temat startowy, z którego korzystacie (jeśli dotyczy):** —

---

## 2. Role użytkowników

Wymagane są co najmniej dwie role. Kolumna „Czego NIE może” jest równie ważna jak „Co może” – to z niej wyjdą testy autoryzacji.

| Rola | Co może | Czego NIE może |
| :--- | :--- | :--- |
| **Trener (Admin)** | Tworzyć wydarzenia (treningi, mecze), zarządzać kadrą zespołu, publikować materiały taktyczne (np. schematy stałych fragmentów gry), przeglądać pełne raporty o powodach nieobecności zawodników | Odczytywać danych drużyn, statystyk i zawodników z innych klubów zarejestrowanych w systemie |
| **Zawodnik (Użytkownik)** | Zgłaszać swoją dostępność na wydarzenia (obecny, praca, kontuzja/choroba), przeglądać udostępnioną mu taktykę meczową | Przeglądać szczegółowych powodów nieobecności (szczególnie medycznych) innych zawodników, usuwać wydarzeń z kalendarza, dodawać siebie do pierwszego składu ustalonego przez trenera |

---

## 3. Dane i ich klasyfikacja

Wypiszcie wszystkie dane, które aplikacja zbiera, przetwarza lub przechowuje. Przy każdej pozycji określić poziom wrażliwości.

| Dane | Skąd pochodzą | Gdzie są przechowywane | Klasyfikacja | Uzasadnienie |
| :--- | :--- | :--- | :--- | :--- |
| **Powody nieobecności** (kontuzje, choroby) | Wprowadzane przez zawodników | Backend | Szczególnie wrażliwe | Informacje o stanie zdrowia to dane wrażliwe (podlegające np. pod RODO), wymagają restrykcyjnej ochrony prywatności |
| **Taktyka i składy meczowe** | Wprowadzane przez trenera | Backend | Wewnętrzne | Dane nie powinny wyciec do rywali z ligi |
| **Tokeny sesyjne (JWT)** | Generowane przez Backend po zalogowaniu | Urządzenie (`Secure Storage`) | Poufne | Ich kradzież może przejąć sesję użytkownika |

### Poziomy klasyfikacji

| Poziom | Przykłady | Minimalna ochrona |
| :--- | :--- | :--- |
| **Publiczne** | opis wydarzenia, cennik, regulamin | brak szczególnych wymagań |
| **Wewnętrzne** | preferencje, historia wyszukiwań, ustawienia | izolacja od innych aplikacji |
| **Poufne** | e-mail, tokeny sesji, historia transakcji | bezpieczny magazyn systemowy, szyfrowanie |
| **Szczególnie wrażliwe** | zdrowie, biometria, finanse, dokładna lokalizacja | minimalizacja danych; często brak przechowywania lokalnego |

---

## 4. Mapowanie na umowę o powierzchni ataku

Każdy projekt musi zawierać wszystkie poniższe funkcie. Opiszcie, jak konkretnie pojawią się w waszej aplikacji.

| Wymagana funkcja | Jak realizujemy ją w naszej aplikacji | Planowane na zajęcia |
| :--- | :--- | :---: |
| **Logowanie z tokenami i co najmniej dwie role** | Realizacja przez Access/Refresh tokeny (JWT). Role (Trener, Zawodnik) weryfikowane każdorazowo na backendzie. | Z5 |
| **Własny backend/API lub Firebase/Supabase z regułami dostępu** | Zastosowanie FastAPI. Zawodnik ma bezwzględnie zablokowany dostęp do endpointów `/api/tactics/edit` oraz pełnego `/api/medical-reports`. | Z2 / Z5 |
| **Lokalne przechowywanie danych wrażliwych (tokeny, dane osobowe, cache)** | Zapis tokenów sesyjnych oraz pobranej taktyki przy użyciu bezpiecznej paczki `flutter_secure_storage`. | Z4 |
| **Co najmniej trzy uprawnienia systemowe (kamera, lokalizacja, pliki, BLE)** | **Powiadomienia Push** (przypomnienia o treningu/meczu), **Aparat** (dodawanie zdjęć profilowych lub zwolnień do profilu zdrowotnego), **Kalendarz** (eksport i zapis dat meczów do lokalnego kalendarza w telefonie). | Z3 |
| **Deep link lub universal link** | Zapraszanie zawodnika do "szatni" klubu w aplikacji specjalnym linkiem wysyłanym SMS-em (np. `bklasa://invite/123456`). | Z3 |
| **WebView lub wczytywanie treści zewnętrznych** | Wyświetlanie aktualnej tabeli ligowej lub terminarza pobieranego np. ze strony Łączy Nas Piłka w izolowanym widoku. | Z3 |
| **Biometria jako opcja odblokowania** | Wymóg autoryzacji odciskiem palca / FaceID dla Trenera przed wejściem w zakładkę ze zgłoszeniami zdrowotnymi zawodników. | Z5 |

---

## 5. Architektura

Wymieńcie główne komponenty i połączenia między nimi. Wstępny szkic (zdjęcie z tablicy też się liczy) dołączcie do repozytorium – na zajęciach 2 zamienimy go w diagram przepływu danych.

| Komponent | Technologia | Z czym się komunikuje |
| :--- | :--- | :--- |
| **Aplikacja mobilna** | Flutter | Backend API |
| **Backend/API** | Python FastAPI | Aplikacja mobilna, baza danych PostgreSQL |
| **Baza danych** | PostgreSQL | Backend API |
| **Usługi zewnętrzne** (logowanie, mapy, analityka, push...) | Firebase Cloud Messaging | Backend API, aplikacja mobilna |

---

## 6. Podział ról w zespole

| Osoba | Główna odpowiedzialność | Odpowiedzialność za bezpieczeństwo (obszar MASVS) |
| :--- | :--- | :--- |
| **Bartosz Bazan** | Warstwa front-endowa | Uwierzytelnianie (**MASVS-AUTH**), jakość kodu (**MASVS-CODE**), **MASVS-CRYPTO** |
| **Oskar Sobolewski** | Badanie bezpieczeństwa aplikacji mobilnej wraz z prowadzeniem dokumentacji | Weryfikacja, czy autoryzacja faktycznie odbywa się na serwerze, a nie tylko w aplikacji (**MASVS-AUTH**), badanie IDOR/BOLA używając proxy (np. Burp Suite) do nasłuchiwania i modyfikowania żądań HTTP (**MASVS-NETWORK**), **MASVS-CRYPTO** |
| **Adam Grelewicz** | Warstwa back-endowa, komunikacja z API i bazą danych | Uwierzytelnianie (**MASVS-AUTH**), bezpieczne przechowywanie danych na urządzeniu (**MASVS-STORAGE**), **MASVS-CRYPTO** |

---

## 7. Plan dojścia do MVP (zajęcia 5)

| Zajęcia | Co będzie gotowe |
| :---: | :--- |
| **Z2** | Repozytorium, szkielet aplikacji (Flutter + FastAPI), wstępny model bazy danych i szkic architektury systemu. |
| **Z3** | Wdrożenie uprawnień systemowych (Aparat, Kalendarz, Powiadomienia Push), konfiguracja Deep Linków oraz wdrożenie izolowanego WebView (tabela ligowa). |
| **Z4** | Implementacja `flutter_secure_storage` do bezpiecznego zapisu wrażliwych danych (cache taktyki meczowej i wstępnych tokenów) na urządzeniu. |
| **Z5 (MVP)** | Działająca, połączona aplikacja z podstawowym obiegiem (Trener dodaje wydarzenie, Zawodnik zgłasza obecność). Wdrożenie szyfrowania lokalnych danych, zaimplementowana biometria. Funkcje z umowy są zrealizowane w podstawowej formie. |

---

## 8. Największe ryzyko według sekcji

Co według was zagrożone jest w pierwszej kolejności i dlaczego? Wpiszcie 1-3 pozycje. Na koniec semestru sprawdzimy, czy mieliście rację.

1. **Bezpieczeństwo API**
2. **Reverse engineering**
3. **Kryptografia**

---

## Akceptacja prowadzącego

| Data | Status | Uwagi |
| :---: | :---: | :--- |
| | *zaakceptowano / do poprawy* | |