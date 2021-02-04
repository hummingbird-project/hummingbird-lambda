# SNS to Slack

This is a Swift based AWS Lambda that will publish Simple Notification System (SNS) messages to a Slack channel.

## Setup Slack incoming webhook

Click [here](https://api.slack.com/apps) to go to the Slack Apps setup page. Click on "Create New App". Provide a name for your app and choose the workspace you want to post to. Click on "Incoming Webhooks". Click the switch to activate incoming webhooks. Click on "Add new webhook". Choose a channel to post to and click "Allow". You now have a webhook URL. You can go to do the bottom of the "Incoming Webhooks" page and copy the URL.

## Build and install

Before continuing you will need [Docker Desktop for Mac](https://docs.docker.com/docker-for-mac/install/) installed. You will also need the AWS command line interface installed. You can install `awscli` with Homebrew.
```
brew install awscli
```

There are four stages to getting the Lambda installed. I have collated all of these into a series of shell scripts, which are a mixture of my own work and bastardised versions of the scripts to be found in the [swift-aws-lambda-runtime](https://github.com/swift-server/swift-aws-lambda-runtime/tree/master/Examples/LambdaFunctions/scripts) repository.

If you just want the Lambda function installed and don't care about the details, just run the install script which runs all the stages.
```
./script/install.sh
```
The install process can be broken into four stages.
1) Build a Docker image for building the Lambda. `scripts/build-lambda-builder.sh`
2) Compile the code. First part of `scripts/build-and-package.sh`
3) Package the compiled Lambda into a zip with required runtime libraries. Second part of `scripts/build-and-package.sh`
4) Deploy the packaged Lambda. `deploy.sh`

If this is the first time you are running the install, the `deploy.sh` script will create a new IAM role to run the Lambda and create a new Lambda function. Otherwise it will just update the already created Lambda.

## Link to Slack

The Lambda uses the Environment variable SLACK_HOOK_URL to get the URL to post to. You can set this using the aws cli or on the AWS dashboard. You can do it using the awscli as follows
```
aws lambda update-function-configuration --function-name swift-sns-to-slack --environment "Variables={SLACK_HOOK_URL=https://hooks.slack.com/services/<my-slack-webhook>}"
```

