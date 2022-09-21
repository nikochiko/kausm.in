.PHONY: build deploy run

build:
	hugo

deploy: build
	rsync -a --delete --backup --backup-dir=/var/www/kausm.in.backup ./public/ personal-droplet:/var/www/kausm.in

run:
	hugo server
