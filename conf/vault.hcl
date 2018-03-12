storage "file" {
	path = "/vault/file"
}

listener "tcp" {
  address = "0.0.0.0:9200"
  tls_disable = 1
}
disable_mlock = true
