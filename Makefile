.PHONY: push
push:
	git submodule update --recursive --remote
	git add .
	git commit -m "auto push"
	git push origin master

.PHONY: clean
clean:
	rm -rf public
	rm -rf resources
	rm -rf .hugo_build.lock

.PHONY: build
build: clean
	hugo --minify

.PHONY: server
server: clean
	hugo server --bind 0.0.0.0 --minify --disableFastRender