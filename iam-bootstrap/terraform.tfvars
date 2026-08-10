org_id              = "179248107504"
identity_project_id = "rwlab-vpcsc-adm-46bc"
github_repository   = "CptDolphin/gcp-vpc-sc"
state_bucket        = "rwlab-vpcsc-tfstate-46bc"
contracts_bucket    = "rwlab-vpcsc-contracts-46bc"

# Musi zgadzać się z `monitoring.project_id` w perimeter/policy.yaml. Tu wszystkie role płaszczyzny
# sterowania pełni jeden projekt, więc wartość powtarza `identity_project_id` — to zbieg okoliczności tej
# organizacji, nie reguła; w większym wdrożeniu monitoring bywa osobnym projektem centralnym.
#
# UWAGA: sam wpis niczego nie nadaje. Granty powstają dopiero przy `terraform apply` w TYM katalogu,
# a robi to człowiek z uprawnieniami org-admin — nie pipeline perimetru (patrz nagłówek main.tf).
monitoring_project_id = "rwlab-vpcsc-adm-46bc"

# --- warstwa IAM Deny -------------------------------------------------------------------------------
# Kto UMIE sprawdzić, czy guardrail perimetru stoi. Bez tego grantu jedyną odpowiedzią API jest `403`,
# a `403` w tym API nie odróżnia „nie ma" od „nie widzę" — org-admin nie ma `iam.denypolicies.*` z urzędu.
deny_reader_principals = ["user:mail@rafalwalas.com"]

# WYŁĄCZONE ŚWIADOMIE, nie z zapomnienia — i to jest zapis stanu faktycznego, nie preferencji.
#
# Zmierzone 2026-08-10 rolą `vpcScDenyReader` (wcześniej to pytanie w ogóle nie miało odpowiedzi):
#   gcloud iam policies list --attachment-point=…/organizations/179248107504 --kind=denypolicies  ->  {}
#   GET …/denypolicies/vpcsc-ci-no-destroy                                     ->  HTTP 404 POLICY_NOT_FOUND
# Polityki NIE MA. Nigdy nie powstała — dotąd wyglądało to na `403`, czyli na brak dostępu do czegoś,
# co jest. Warstwa opisywana w README i na diagramie jako obecna nie chroniła niczego.
#
# Utworzenie jej wymaga `iam.denypolicies.create`, które niesie WYŁĄCZNIE `roles/iam.denyAdmin` (jedyna
# z 2382 ról predefiniowanych), a roli własnej z tym uprawnieniem zbudować się nie da
# (`customRolesSupportLevel = NOT_SUPPORTED`). Ta sama rola daje `denypolicies.delete` na KAŻDEJ polityce
# deny w organizacji, więc grant jest decyzją o modelu uprawnień człowieka na org, a nie krokiem apply —
# rozpisaną w ADR razem z odrzuconymi wariantami. Do czasu jej podjęcia stack ma nie udawać, że warstwa
# stoi: `false` daje `plan` bez różnic i jawny brak, zamiast wiecznego `1 to add`, którego nikt nie stosuje.
#
# Zdjęcie tej linijki = włączenie warstwy. Przed tym: nadaj `roles/iam.denyAdmin` tożsamości applikującej,
# a po apply potwierdź `tools/deny_check.sh --org 179248107504` (kod 0), nie samym „apply zielony".
manage_deny_policy = false
