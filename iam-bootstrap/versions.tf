terraform {
  required_version = ">= 1.8, < 2.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    # google-beta TYLKO dla google_iam_deny_policy — ten zasób nie ma odpowiednika w GA.
    # Reszta stacku jedzie na providerze GA.
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.0"
    }
  }

  # Backend GCS — stan warstwy TOŻSAMOŚCI. Bez tego bloku stan jest LOKALNY, czyli w praktyce nie istnieje:
  # klon na maszynie kolejnej osoby (albo świeży klon tej samej) nie zna ani jednego zasobu, a `apply` próbuje
  # utworzyć od zera konta, role i pulę WIF, które stoją na organizacji od miesięcy. Część takich prób pada na
  # „already exists", część przechodzi — i wtedy warstwa uprawnień jest w stanie, którego nikt nie opisał.
  # Zmierzone: `terraform plan` ze świeżego klonu pokazywał `23 to add` przy dwóch zamierzonych dodaniach.
  #
  # DLACZEGO PREFIKS INNY NIŻ U PERIMETRU (`vpc-sc/perimeter` w terraform/versions.tf), skoro bucket ten sam:
  # to jest granica uprawnień, nie porządki w nazewnictwie. `iam-bootstrap/main.tf` daje kontom `sa-vpcsc-plan`
  # i `sa-vpcsc-apply` rolę `storage.objectAdmin` na buckecie stanu z warunkiem IAM
  # `resource.name.startsWith(".../objects/vpc-sc/perimeter")`. Wspólny prefiks znaczyłby, że pipeline perimetru
  # ma prawo ZAPISU do stanu stacku, który nadaje mu uprawnienia — a wtedy tożsamość mogłaby jednym PR-em
  # poszerzyć własne role (albo po prostu podmienić stan i sprowokować rekreację ról pod swoje dyktando).
  # Ten sam powód, dla którego katalog i właściciel są osobne; prefiks domyka to po stronie danych.
  #
  # UWAGA NA KSZTAŁT NAZWY: warunek IAM to `startsWith`, nie równość. Prefiks zaczynający się od
  # `vpc-sc/perimeter` (np. `vpc-sc/perimeter-iam`) wpadłby POD ten warunek i po cichu oddał ten stan
  # pipeline'owi perimetru. `vpc-sc/iam-bootstrap` jest rozłączny na pierwszym członie po `vpc-sc/`.
  #
  # Ten stan czyta i pisze WYŁĄCZNIE człowiek z uprawnieniami org-admin (patrz nagłówek main.tf) — konta CI
  # nie mają do niego dostępu i mieć nie mają. `storage.legacyBucketReader` z main.tf daje im listowanie
  # bucketa (backend GCS wylicza workspace'y), czyli metadane obiektu; treści stanu nie odczytają.
  backend "gcs" {
    bucket = "rwlab-vpcsc-tfstate-46bc"
    prefix = "vpc-sc/iam-bootstrap"
  }
}

provider "google" {}
provider "google-beta" {}
