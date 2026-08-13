# Wniosek o dostępy — treść do wklejenia w ticket

Skopiuj sekcje **A–D** do zgłoszenia dla zespołu IAM / architekta. Sekcja **E** to odpowiedzi na pytania,
które padną — trzymaj ją pod ręką, nie wklejaj z góry.

Załączniki: diagram `docs/diagrams/D2-iam-and-wif.png` oraz katalog `iam-bootstrap/` (gotowy Terraform,
`terraform validate` przechodzi bez credentiali).

> **Wyślij to RAZEM z `docs/9-karta-wejscia.md`, nie zamiast niej.** Ten dokument mówi, o co **my prosimy**;
> karta pyta o **stan zastany i cudze procesy**. Trzy pozycje niżej zależą wprost od odpowiedzi z karty:
> zdanie „perimetr już istnieje" (§A), zasięg nadań IAM przy projektach rozsianych po folderach (§B.0)
> i to, czy w ogóle jest komu wykonać krok człowieka przy odzysku granicy (§B.4). Wysłanie samego wniosku
> daje komplet uprawnień do wdrożenia, o którym nadal nie wiemy, czy pasuje do organizacji.

---

## A. Czego dotyczy

Wdrażamy zarządzanie perimetrem VPC Service Controls jako kodem (repozytorium `CptDolphin/gcp-vpc-sc`).

**Wariant domyślny — perimetr i access policy JUŻ ISTNIEJĄ.** Nie prosimy wtedy o prawo ich tworzenia ani
kasowania, wyłącznie o możliwość **modyfikowania zawartości** (dokładanie projektów i reguł
ingress/egress). Repozytorium startuje w trybie brownfield (`perimeter.manage_skeleton: false`) i treść
perimetru zostaje u obecnego właściciela.

**Jeśli perimetru NIE MA** — potwierdźcie to, bo zmienia się jedna rzecz: pierwsze utworzenie granicy jest
wtedy **krokiem człowieka** z `roles/accesscontextmanager.policyAdmin` (§B.4 i §E). Pipeline nie dostaje
`servicePerimeters.create` w żadnym wariancie, także greenfieldowym — to nie jest skutek tego, że perimetr
akurat istnieje.

Cel biznesowy: dywizje mają dołączać do perimetru samoobsługowo (formularz w systemie ticketowym →
approval zespołu sieciowego), zamiast czekać na ręczną zmianę wykonywaną przez inżyniera.

## B. O co prosimy

```
0. WIDOK READ-ONLY dla ludzi z zespołu (najtańszy punkt, odblokowuje inwentaryzację i brownfield):
   - roles/resourcemanager.organizationViewer       [ORGANIZACJA]   konsola w ogóle pokazuje organizację
   - roles/accesscontextmanager.policyReader        [ORGANIZACJA]   odczyt polityki, perimetru, access levels
   - roles/browser                                  [ORGANIZACJA]   drzewo folderów/projektów (id <-> numer)
   - roles/cloudasset.viewer                        [ORGANIZACJA]   pre-flight + wykrycie martwego członka
   - roles/logging.viewer                           [ORGANIZACJA]   naruszenia dry-run = dowód przed promocją
   - roles/serviceusage.serviceUsageViewer          [ORGANIZACJA]   czy API objęte baselinem są włączone
   (minimum, gdyby trzeba było ciąć: organizationViewer + policyReader + browser)
   UWAGA 1: granty ACM na folderze/projekcie NIE działają — tylko organizacja albo pojedyncza polityka.
   UWAGA 2: nadanie „tylko na naszym folderze" dla POZOSTAŁYCH ról jest org-wide w przebraniu, jeśli
            projekty członkowskie leżą w wielu folderach — a leżą zwykle w wielu. Pytamy o to w karcie
            wejścia (§C3) przed, a nie po nadaniu.

1. Konto serwisowe  sa-vpcsc-plan@rwlab-vpcsc-adm-46bc.iam.gserviceaccount.com   (read-only, uruchamiane przez każdy PR)
   [ORGANIZACJA]
   - roles/accesscontextmanager.policyReader   odczyt perimetru do `terraform plan`; pre-flight 1 i 2
   - roles/cloudasset.viewer                   kontrola pozytywna sondy granicy + detektor martwego członka
   - roles/compute.networkViewer               pre-flight 3: Private Google Access na podsieciach
   - roles/dns.reader                          pre-flight 4: strefa DNS kierująca googleapis.com na restricted VIP
   - roles/monitoring.viewer                   refresh stanu czyta metryki i polityki alertów perimetru
   - roles/logging.viewer                      raport naruszeń dry-run (knob `grant_logging_viewer`, patrz E)
   [BUCKET STANU]
   - roles/storage.legacyBucketReader          na CAŁYM buckecie — backend GCS listuje workspace'y
   - roles/storage.objectAdmin                 z warunkiem na prefiks stanu (blokada .tflock to zapis)
   [BUCKET KONTRAKTÓW, jeśli używany]
   - roles/storage.objectViewer                refresh czyta opublikowany obiekt kontraktu

2. Konto serwisowe  sa-vpcsc-apply@rwlab-vpcsc-adm-46bc.iam.gserviceaccount.com  (jedyna tożsamość zapisująca)
   [ORGANIZACJA]
   - CUSTOM ROLA organizations/179248107504/roles/vpcScPerimeterWriter
       accesscontextmanager.policies.get / list
       accesscontextmanager.servicePerimeters.get / list / update
       accesscontextmanager.accessLevels.get / list / create / update / delete
     (BEZ servicePerimeters.create, BEZ servicePerimeters.delete, BEZ policies.*)
     `accessLevels.delete` JEST w tej roli świadomie — uzasadnienie w sekcji E.
   [PROJEKT MONITORINGU]
   - CUSTOM ROLA vpcScMonitoringWriter          pełny cykl życia metryk logowych i polityk alertów perimetru
     (bez sinków, bez kubełków, bez IAM — patrz E)
   [BUCKET STANU / KONTRAKTÓW]
   - roles/storage.legacyBucketReader           na całym buckecie stanu (jak wyżej)
   - roles/storage.objectAdmin                  z warunkiem na prefiks stanu; osobno na prefiks kontraktu

3. Konto serwisowe  sa-vpcsc-watch@…            (obserwator — publikuje telemetrię granicy)
   [PROJEKT MONITORINGU]
   - roles/monitoring.metricWriter              jedno uprawnienie, jeden projekt
   Zakres jest celowo minimalny: to konto nie czyta perimetru, stanu ani kontraktu. Przejęte, potrafi
   wyłącznie skłamać o telemetrii — a nie może być kontem `plan`, bo `plan` impersonuje KAŻDY pull request.

4. IAM Deny [ORGANIZACJA] dla kont plan i apply — polityka `vpcsc-ci-no-destroy`:
   accesscontextmanager.googleapis.com/servicePerimeters.delete
   accesscontextmanager.googleapis.com/policies.delete
   accesscontextmanager.googleapis.com/servicePerimeters.create
   KTO TO APPLIKUJE: potrzebny jest `roles/iam.denyAdmin` — JEDYNA rola niosąca `iam.denypolicies.create`;
   roli własnej z tym uprawnieniem zbudować SIĘ NIE DA (`customRolesSupportLevel = NOT_SUPPORTED`).
   Powinien go trzymać zespół IAM ROZŁĄCZNY z właścicielem perimetru — inaczej warstwa nie stoi PONAD
   rolami, tylko obok nich. Nam wystarcza odczyt (rola własna `vpcScDenyReader`): `terraform plan` schodzi
   do `No changes` na samym odczycie polityki. Jeśli nikt tego nie nada — powiedzcie wprost; wdrożenie
   ustawi wtedy `manage_deny_policy = false` i zapisze brak tej warstwy jako decyzję, a nie jako lukę.

5. Workload Identity Federation: pula + provider OIDC GitHub z attribute_condition ograniczającym do
   repozytorium CptDolphin/gcp-vpc-sc; wiązania roles/iam.workloadIdentityUser na obu kontach.
   Konto apply jest dodatkowo związane z GitHub environment, więc token z pull requesta go nie dosięga.

6. Bucket na stan Terraform: versioning + soft-delete, BEZ retention-lock. Bucket kontraktów — OSOBNY.
   Prefiksy stanu perimetru i stanu iam-bootstrap muszą być RÓŻNE: konta CI perimetru nie mogą nadpisać
   stanu stacku, który nadaje im uprawnienia.

7. KROK CZŁOWIEKA, o którym łatwo zapomnieć, bo nie jest uprawnieniem dla naszego pipeline'u:
   stack `violations-sink/` (kubełki logów, sinki ORG-LEVEL z include_children, widoki, granty
   logging.viewAccessor) applikuje CZŁOWIEK z org-level `roles/logging.configWriter`. Konto pipeline'u
   tej roli świadomie nie ma — para „sink + kubełek" to gotowa ścieżka wyprowadzenia logów gdzie indziej.
   BEZ TEGO KROKU: granica stoi i działa, ale obserwator nie ma czego czytać — raport naruszeń i detektor
   okna świeżej sieci milczą, a zgłosi to dopiero dead-man's-switch. Prosimy o wskazanie osoby lub grupy.

8. WARIANT MINIMALNY, jeśli punkt 1 wymaga dłuższej decyzji — nie blokujmy się nawzajem:
   scoped access policy na folderze-piaskownicy (--scopes=folders/<NUMER FOLDERU>, nie identyfikator projektu)
   + roles/accesscontextmanager.policyEditor
   dla sa-vpcsc-apply NA TEJ POLITYCE + roles/accesscontextmanager.policyReader na organizacji (read-only,
   potrzebne do wylistowania polityk). Daje nam to pełny test pipeline'u bez prawa zapisu na polityce
   produkcyjnej; utworzenie i delegację musi wykonać ktoś z uprawnieniami org-level (jednorazowo).
   CZEGO TEN WARIANT NIE ROZWIĄZUJE: limit 500 access leveli jest na ORGANIZACJĘ, więc scoped policy go
   nie dzieli — i oznacza osobny perimetr, czyli rezygnację z wymogu „jeden perimetr".

Czego NIE prosimy — świadomie, i co z tego wynika:
   - resourcemanager.projects.create / delete — cykl życia projektu NIE należy do tego repozytorium.
     Konsekwencja, którą trzeba przyjąć razem z tym zdaniem: offboarding kończy się NA GRANICY (usunięcie
     z perimetru i z access leveli). Projekt zostaje, a jego skasowanie przez inny zespół jest dla nas
     zdarzeniem ZEWNĘTRZNYM — patrz karta wejścia §C1, bo bez powiadomienia produkuje ono fałszywy dowód
     czystego okna dla bramki promocji.
   - accesscontextmanager.servicePerimeters.create — także w wariancie greenfield (patrz A i E).
   - żadnych uprawnień zapisujących w projektach dywizji.
   - prawa tworzenia ani usuwania polityki dostępu.
   - żadnych kluczy service accountów (dostęp wyłącznie keyless przez WIF).
```

## C. Uzasadnienie w trzech zdaniach

> Prosimy wyłącznie o prawo modyfikowania **zawartości** perimetru (`servicePerimeters.update`) plus
> zarządzanie poziomami dostępu. Google nie pozwala nadać uprawnień Access Context Managera niżej niż
> organizacja, więc zamiast zawężać zasięg, zawężamy zestaw operacji: rola custom bez `create`/`delete`
> na perimetrze plus IAM Deny na kasowaniu i tworzeniu. Dostęp jest keyless (WIF), rozdzielony na
> read-only dla pull requestów i zapisujący wyłącznie dla `main` za bramką ludzkiego zatwierdzenia.

## D. Co dostajecie od nas

- **Gotowy Terraform** (`iam-bootstrap/`) — applikuje go wasz zespół, nie nasz pipeline. Kod nadający
  uprawnienia nie powinien być stosowany przez tożsamość, która z nich korzysta.
- **Testy weryfikacyjne po apply**, w tym dwa **negatywne**: konto `plan` próbujące zmienić perimetr i konto
  `apply` próbujące go skasować — oba mają zakończyć się błędem. Trzeci negatyw dotyczy warstwy Deny:
  konto `apply` próbujące **utworzyć** perimetr również ma dostać odmowę, i to po zmianie roli.
- **Kartę wejścia** (`docs/9-karta-wejscia.md`) — listę pytań o stan zastany, z konsekwencją każdej
  odpowiedzi „nie" i mapą „odpowiedź → konkretny klucz konfiguracji".

---

## E. Odpowiedzi na pytania, które padną

**„Dlaczego rola na organizacji, a nie na naszym folderze?"**
Uprawnienia Access Context Managera można nadać wyłącznie na organizacji albo na konkretnej polityce
dostępu — grant na folderze lub projekcie **nie ma żadnego efektu**
([docs](https://docs.cloud.google.com/access-context-manager/docs/access-control)). To ograniczenie Google,
nie nasz wybór. Dlatego cała redukcja ryzyka idzie w zestaw operacji.

**„Dlaczego nie `roles/accesscontextmanager.policyEditor`?"**
Bo daje read-write na politykach **razem z prawem usunięcia perimetru**. Porównajcie sami:
`gcloud iam roles describe roles/accesscontextmanager.policyEditor` — różnica wobec naszej roli to dokładnie
`create` i `delete` na perimetrze.

**„Skoro nie prosicie o `servicePerimeters.create`, to kto utworzy perimetr?"**
Człowiek z `roles/accesscontextmanager.policyAdmin` na organizacji, ręcznie, według
`docs/3-runbook-promocja-i-break-glass.md` część D. To jest **6 sekund** jego pracy w ~3-minutowym odzysku;
resztę robi pipeline. Uzasadnienie podziału: uprawnienie potrzebne **raz na katastrofę** nie jest spłacane
obejściami, a uprawnienie potrzebne w **rutynie** — jest. Dodatkowo `update` mutuje obiekt pod ciągłą
obserwacją (drift, sonda, raport naruszeń), a `create` produkuje obiekt, o który nie pyta nic. Prosimy
o **wskazanie grupy** trzymającej `policyAdmin` — bez niej mamy procedurę odzysku bez wykonawcy.

**„Dlaczego CI ma `accessLevels.delete`, skoro nie ma `servicePerimeters.delete`?"**
Bo rozstrzyga **częstotliwość i istnienie obejścia**, nie groźność nazwy. `accessLevels.delete` trafia
w **każdy** offboarding dywizji z własnym poziomem; bez niego apply pada na OSTATNIM kroku, po tym jak
członek i reguła już zniknęły z granicy — czyli zostawia stan częściowo zastosowany na żywej granicy,
i to regularnie. Obejścia nie ma: katalog poziomów mógłby tylko rosnąć, a limit jest **500 na
ORGANIZACJĘ**. Ta sama rola ma przy tym `accessLevels.update`, które jest **groźniejsze** — przepisanie
poziomu na `0.0.0.0/0` poszerza granicę cicho, bez zniknięcia obiektu. `servicePerimeters.create` jest
odwrotnym przypadkiem: raz w życiu granicy, z tanim obejściem (człowiek), więc zostaje poza rolą i **poza**
tym, co wolno jej nadać podmianą w pośpiechu — stąd wpis w warstwie Deny.

**Residual, który mówimy wprost:** `accessLevels.delete` sięga każdego **nierefereowanego** poziomu
w polityce organizacji, także cudzego — zakres ACM jest org-level. Nasze poziomy odtwarza jeden apply
z repozytorium; cudzych nie odtworzy nic. Jeśli w polityce są poziomy nienależące do tego wdrożenia,
prosimy o ich listę (karta wejścia §A6).

**„Skoro macie WIF, po co jeszcze konta serwisowe?"**
WIF to **brama**, nie tożsamość: sam z siebie nie nadaje żadnych uprawnień. Uprawnienia ma konto serwisowe,
a pula z warunkiem decyduje, kto może je impersonować. Alternatywa (rola nadana wprost tożsamości
federowanej) jest możliwa, ale nie wszystkie API ją obsługują i traci się jeden punkt odcięcia dostępu.

**„Czy `cloudasset.viewer` na organizacji jest konieczny?"**
Tak, i ma **dwóch** konsumentów — dlatego nie znika przy porządkowaniu ról. Pierwszy to pre-flight:
sprawdzamy, czy projekt istnieje, czy jego numer zgadza się z ID i czy nie należy już do innej
konfiguracji egzekwowanej (projekt może być tylko w jednej). Bez tego wniosek „przechodzi", a apply pada
dopiero na API — po review i po zamknięciu ticketu. Drugi to **detektor martwego członka**: jedno
wywołanie Asset Inventory pyta o `state` wszystkich projektów organizacji. Alternatywą było
`resourcemanager.projects.get`, którego **nie ma żadne** nasze konto — czyli nowe nadanie na organizacji,
kilkaset wywołań na przebieg i ani jednego stanu więcej.

**„Po co `dns.reader`?"**
Perimetr kontroluje, *kto* woła API, ale nie zmienia, *którędy* ruch wychodzi. Bez prywatnej strefy DNS
kierującej `googleapis.com` na restricted VIP (`199.36.153.4/30`) ruch idzie publicznie — albo omija intencję
granicy, albo po włączeniu enforce zostaje zablokowany i wygląda jak awaria aplikacji. `dns.reader` pozwala to
**sprawdzić** przed dołączeniem; naprawia właściciel projektu, nie my.

**„Po co wam `logging.viewer` na CAŁEJ organizacji?"**
Bo wpis o naruszeniu VPC-SC ląduje w logu projektu będącego **właścicielem zasobu**, nie w logu
organizacji — a projektów członkowskich są dziesiątki i przybywają bez naszego udziału, więc nadania per
projekt byłyby listą nie do utrzymania. Bez tego odczytu nie da się **udowodnić**, że okno obserwacji było
czyste, czyli promocja do `enforced` staje się zgadywaniem. Druga, mniej oczywista konsekwencja odmowy:
przy włączonej sekcji `monitoring` ta sama rola daje `logging.logMetrics.get`, bez którego **każdy**
`terraform plan` pada na odświeżeniu metryk — także plan niedotyczący monitoringu.
**Węższa alternatywa istnieje i chętnie ją weźmiemy:** org-level sink z `include_children` do jednego
kubełka w projekcie administracyjnym plus `roles/logging.viewAccessor` na widoku (to jest właśnie stack
`violations-sink/` z §B.7). Wymaga jednak `logging.configWriter` po Waszej stronie — czyli zamienia
szeroką rolę dla automatu na wąską rolę dla człowieka. To jest wybór, nie ustępstwo; prosimy o decyzję.

**„Dlaczego jeden ze stacków ma applikować nasz człowiek, a nie wasz pipeline?"**
Bo `violations-sink/` tworzy **sinki i kubełki logów**, a to jest infrastruktura wyprowadzania danych.
Rola dająca ją tworzyć w projekcie daje przy okazji zbudować kanał wynoszący logi gdzie indziej — i tego
konsekwentnie nie bierzemy, tak samo jak nie bierzemy `monitoring.editor` (stąd wąska
`vpcScMonitoringWriter` zamiast pary `monitoring.editor` + `logging.configWriter`). Cena jest jawna: ten
stack rusza rzadko i zawsze rękami człowieka.

**„Czy to nie da się zrobić bez uprawnień na organizacji?"**
Jedyna taka opcja to **scoped policy** — własna polityka ACM dla folderu dywizji, z uprawnieniami na tej
polityce zamiast na organizacji. To jednak oznacza osobny perimetr per dywizja, czyli rezygnację z wymogu
„jeden perimetr", a limitu 500 access leveli i tak nie dzieli (jest na organizację). Jesteśmy gotowi to
rozważyć, jeśli taka jest decyzja architektury.
