image:
	docker build --pull -t mqtt-broker .
	docker build --pull -f Dockerfile.mosquitto -t mqtt-edge-broker .

run:
	docker compose up -d --build

clean:
	docker image rm -f mqtt-broker || true
	docker image rm -f mqtt-edge-broker || true
