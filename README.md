# papermerge-aws

## Prerequisites
1. Linux
1. [AWSCli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

## Bootstrap autodeploy
1) Fork repo to your 
1) Rename `.envrc_example` to `.envrc` and replace example AWS access keys with yours.
1) Update the `GITHUB_OWNER` and `GITHUB_REPO` parameter values in `.envrc` for your fork.
1) Create a new GitHub personal access token (fine grained) for this application. See [here](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/) for how to do this - CodePipeline needs just the `Read and Write access to repository hooks` permissions. I recommend you name the token for this particular pipeline, at least to get started, and that you store the token somewhere safe, like a password manager.
1) Replace example `GITHUB_TOKEN` in `.envrc` with yours.
1) :warning: The user associated with the personal access token above **MUST** have administrative rights for the Github repo - either by being an owner of the repo, or having been granted admin privs. Simply having write access is not sufficient, because this template attempts to create a webhook in Github. If your user has insufficient privileges the pipeline creation process will fail, but will create an stranded / undeletable version of your application stack.
1) Commit all your changes to source control. :warning: Check that `.envrc` is gitignored so you don't leak your secrets.
1) Now from a terminal run the following (this assumes the AWS CLI is installed and configured, github token is set, github repo and owner variables updated). Make sure the `AWS_DEFAULT_REGION` in `.envrc` is configured to use the AWS region where you want the pipeline itself to run, and that it is configured to use the account where the pipeline and application will run.

``` bash
$ ./control.sh --create-pipeline
```

Once you've run this last command then watch both the CloudFormation and then CodePipeline consoles to evaluate whether the process has been successful. You should have two new CloudFormation stacks - one for the pipeline and one for the application, and you should be able to see a new Pipeline in CodePipeline.

To update pipeline make changes to `pipeline.yaml` and deploy changes via

```bash
$ ./control.sh --update-pipeline
```

## Control script

`control.sh` can be used not only for pipeline deployment but also for controlling application deployment.

To stop application(scale down application to 0):
```bash
$ ./control.sh --stop
```

To start application(scale to 1 replica):
```bash
$ ./control.sh --start
```

To restart application(perform scale down and scale up):
```bash
$ ./control.sh --restart
```

To destroy application(all data will be lost):
```bash
$ ./control.sh --destroy
```

To deploy application from scratch(blank application):
```bash
$ ./control.sh --deploy
```

