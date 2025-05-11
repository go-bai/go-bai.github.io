.PHONY: init
init:
	CGO_ENABLED=1 go install -tags extended github.com/gohugoio/hugo@latest
	git submodule update --init --recursive
	git submodule foreach git pull origin master

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

.PHONY: gen-blog-index
gen-blog-index:
	bash scripts/gen-blog-index.sh

.PHONY: build
build: clean gen-blog-index
	hugo --minify

.PHONY: server
server: clean gen-blog-index
	hugo server --bind 0.0.0.0 --minify --disableFastRender