.PHONY: build deploy run

DOMAINS = "kausm.in" "kaustubh.page"

deploy:
	for domain in $(DOMAINS); do \
		hugo -b "https://$$domain/" && \
		rsync -a --delete --backup --backup-dir=/var/www/$$domain.backup ./public/ personal-droplet:/var/www/$$domain; \
	done

run:
	hugo server
