.PHONY: init helm-unittest

init: helm-unittest
	echo "Container initialised..."

helm-unittest:
	helm plugin install https://github.com/helm-unittest/helm-unittest.git

test:
	helm unittest ./charts/** -f templates/tests/*.yaml
