package sovereign.validate_config

default allow = false

allow {
  input.project_id != ""
  input.region != ""
}

deny[msg] {
  input.project_id == ""
  msg := "workstation.config: project_id must not be empty"
}

deny[msg] {
  input.region == ""
  msg := "workstation.config: region must not be empty"
}
