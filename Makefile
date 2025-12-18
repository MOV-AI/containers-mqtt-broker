image:
	docker build --pull -t mqtt-broker .

run:
	docker compose up -d --build

clean:
	docker image rm -f mqtt-broker || true
