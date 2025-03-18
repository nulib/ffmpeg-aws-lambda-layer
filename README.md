# FFmpeg/FFprobe for AWS Lambda

A Lambda layer containing a static version of FFmpeg/FFprobe utilities from the [`FFmpeg`](https://www.ffmpeg.org/) Linux package, compatible with [Amazon Linux 2023 runtimes](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html).

## Usage

Absolutely the easiest way of using this is to pull it directly from the AWS Serverless Application repository into a CloudFormation/SAM application, or deploy directly from the Serverless Application Repository into your account, and then link as a layer. 

The `ffmpeg` and `ffprobe` binaries will be in `/opt/bin/` after linking the layer to a Lambda function.

For more information, check out the [ffmpeg-lambda-layer](https://serverlessrepo.aws.amazon.com/applications/arn:aws:serverlessrepo:us-east-1:145266761615:applications~ffmpeg-lambda-layer) application in the Serverless App Repository.

For manual deployments and custom builds, read below...

## Prerequisites

* Unix Make environment
* AWS command line utilities (just for deployment)

## Deploying to AWS as a layer

This package will create a static build of FFmpeg 7.1 from source with a number of free (GPL-compatible) codecs.

The output will be in the `result` dir.

Run the following command to deploy the compiled result as a layer in your AWS account.

```
make deploy DEPLOYMENT_BUCKET=<YOUR BUCKET NAME>
```

### configuring the deployment

By default, this uses `ffmpeg-lambda-layer` as the stack name. Provide a `STACK_NAME` variable when calling `make deploy` to use an alternative name.

For more information on using FFmpeg and FFprobe, check out <https://ffmpeg.org/documentation.html>

## Author

Gojko Adzic <https://gojko.net>

## License

* These scripts: [MIT](https://opensource.org/licenses/MIT)
* FFmpeg: GPLv2.1 <http://ffmpeg.org/legal.html>, John Van Sickle's static build GPL v3 <https://johnvansickle.com/ffmpeg/>

## LGPL version

*  [Giuseppe Battista](http://github.com/giusedroid) created a build that contains only LGPL components, for organisations that are concerned about GPL licensing. See it at <https://github.com/giusedroid/ffmpeg-aws-lambda-layer/tree/license/lgpl>
