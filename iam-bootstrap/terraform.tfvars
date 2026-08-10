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
