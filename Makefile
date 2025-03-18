STACK_NAME ?= ffmpeg-lambda-layer

clean:
	rm -rf .aws-sam

distclean: clean
	rm -rf build

docker-image:
	@if [ -z "$(shell docker images -q nulib/ffmpeg-lambda:latest)" ]; then \
		echo "Docker image not found. Building image..."; \
		docker build -t nulib/ffmpeg-lambda:latest .; \
	else \
		echo "Docker image already exists."; \
	fi

build/layer/bin/ffmpeg: docker-image
	mkdir -p build/layer/bin ;\
	docker run --rm -t --user $$(id -u):$$(id -g) -v $$PWD/build/layer/bin:/output nulib/ffmpeg-lambda:latest
	
.aws-sam/build/template.yaml: build/layer/bin/ffmpeg
	sam build

build/output.yaml: .aws-sam/build/template.yaml
	sam package --output-template-file build/output.yaml --resolve-s3

build: .aws-sam/build/template.yaml

package: build/output.yaml

deploy: .aws-sam/build/template.yaml
	sam deploy --template-file .aws-sam/build/template.yaml --resolve-s3 --stack-name $(STACK_NAME)

publish: build/output.yaml
	sam publish --template build/output.yaml

