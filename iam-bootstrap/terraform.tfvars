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

# WŁĄCZONE 2026-08-11 (#1966). Warstwa istnieje, jest ZMIERZONA i nie opiera się już na deklaracji.
#
# Stan przed: `gcloud iam policies list --kind=denypolicies` na organizacji zwracał `{}` — zero polityk
# deny w całym orgu. Warstwa opisana w README i na diagramie jako „twardy zakaz ponad rolami" nie chroniła
# niczego, a `403` z `denypolicies.get` maskował to jako „chyba jest, tylko nie widzę" (#1960, GCP-0062).
#
# JAK POWSTAŁA I DLACZEGO NIKT NIE MA DZIŚ `roles/iam.denyAdmin`. Zapisu tej warstwy nie da się zawęzić:
# `denypolicies.create/update/delete` mają `customRolesSupportLevel = NOT_SUPPORTED`, a jedyną rolą, która
# je niesie, jest `roles/iam.denyAdmin` — razem z prawem skasowania KAŻDEJ polityki deny w organizacji.
# Rola została nadana na czas apply i testu, po czym ODEBRANA (wariant C z GCP-0062): warstwa stoi,
# `vpcScDenyReader` nadal ją CZYTA (więc `plan` schodzi do `No changes` na samym odczycie), a jej zmiana
# wymaga świadomego ponownego nadania. To break-glass dla samego guardrailu, nie stały grant.
#
# CO ZOSTAŁO ZMIERZONE (Policy Troubleshooter v3, `sa-vpcsc-apply` z tymczasowym `policyEditor`,
# perimetr jednorazowy — nigdy `ai_core`):
#   servicePerimeters.delete -> allow ALLOW_ACCESS_STATE_GRANTED + deny DENY_ACCESS_STATE_DENIED
#                               => overallAccessState CANNOT_ACCESS        (Deny BIJE allow)
#   servicePerimeters.update -> deny DENY_ACCESS_STATE_NOT_DENIED => CAN_ACCESS   (kontrola pozytywna)
# Uwaga operacyjna, która wywraca naiwny test: odmowa z Deny wygląda w API DOKŁADNIE tak samo jak brak
# roli (`PERMISSION_DENIED: The caller does not have permission.`) — bez nazwy polityki i bez słowa „deny".
# Dowodem jest Policy Troubleshooter, nie treść komunikatu.
#
# Wpisanie tu `false` = skasowanie polityki przy najbliższym apply. Przed tym przeczytaj GCP-0062;
# po każdej zmianie potwierdzaj `tools/deny_check.sh --org 179248107504` (kod 0), nie samym „apply zielony".
manage_deny_policy = true
