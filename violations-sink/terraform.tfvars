org_id          = "179248107504"
sink_project_id = "rwlab-vpcsc-adm-46bc"

# Konto, którym `violations-report.yml` czyta dowód (to samo `PLAN_SERVICE_ACCOUNT` co w zmiennych repo).
report_service_account = "sa-vpcsc-plan@rwlab-vpcsc-adm-46bc.iam.gserviceaccount.com"

# Lokalizacja WYMUSZONA przez org policy: `constraints/gcp.resourceLocations = in:eu-locations`.
# `global` pada na apply komunikatem o polityce, nie o złej wartości.
bucket_location = "eu"

# 30 dni = sufit darmowy Cloud Logging; okno bramki promocji to 14 + 7 dni.
retention_days = 30

# Ludzie z wglądem w surowy strumień odmów — JAWNIE i imiennie. W labie nikt poza właścicielem
# organizacji; w większym wdrożeniu tu wchodzi grupa Security, nie „wszyscy z dostępem do repo".
violations_reader_principals = ["user:mail@rafalwalas.com"]
