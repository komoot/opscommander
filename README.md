Opscommander [![Build Status](https://travis-ci.org/komoot/opscommander.svg?branch=master)](https://travis-ci.org/komoot/opscommander)
============

Opscommander is a Ruby tool for managing OpsWorks stacks. The basic idea is to treat stacks, layers and application
settings as immutable values. All relevant settings for a stack are kept in a YAML file that completely describes
the stack and acts as its single source of truth. Given the information in the YAML file, Opscommander can perform an 
array of managerial tasks, such as performing a blue-green deployment of a stack, stopping and deleting stacks, renaming
and much more. See below for a list of commands.

The reason for developing Opscommander was to integrate OpsWorks stacks better with a continuous deployment chain, 
where for example Jenkins can run it to perform deployment tasks. We like OpsWorks a lot for user management, 
monitoring, Chef integration and so on, but using the AWS console to perform these tasks quickly becomes repetitive.

Blue-green deployments are also not possible out-of-the-box in OpsWorks. If your stack uses ELBs, Opscommander offers a solution 
to that problem using a strategy that includes creating a new stack in parallel and switching the ELBs from their attachment points
in the old stack to the new stack without downtime. See the [`bluegreen` command](https://github.com/komoot/opscommander#bluegreen).

## Installing and running Opscommander

### Dependencies

Before using Opscommander, install the following.

```
$> sudo gem install bundler
# For OS X users
$> xcode-select --install     
```

### Installation

You can install the gem into your local gem repository:

```
$> gem build opscommander.gemspec
$> gem install opscommander-1.0.7.gem
``` 

### Run without installing

It is also possible to run Opscommander directly with `ruby`:

```
$> bundle install
$> ruby -Ilib bin/opscommander ... 
```

### Running the tests

`
$> rspec
`

### Access credentials

Opscommander uses the Ruby AWS SDK internally. For more information on how to provide access credentials
to the SDK, see the [SDK documentation](http://docs.aws.amazon.com/AWSSdkDocsRuby/latest//DeveloperGuide/prog-basics-creds.html).

### Running in AWS cloud

If you decide to run Opscommander in the AWS cloud, for example as part of a continuous deployment setup,
you should be aware that the instance profile of the instance that Opscommander runs on needs to include 
EC2, ELB and OpsWorks full access policies.

### Using pry

Pry can be useful for trying out individual library methods:

```ruby
[1] pry(main)> AWS.config({:access_key_id => '...', :secret_access_key => '...', :region => '...'})
[2] pry(main)> aws_connection = AwsConfiguration.new 
[3] pry(main)> load './lib/aws/opsworks.rb'
[4] pry(main)> ops = OpsWorks.build(aws_connection)
[5] pry(main)> stack = ops.find_stack 'some-stack-shortname'
[6] pry(main)> stack.find_layers_by_name.first 
...
```

## Stack configuration

See [awesome.yaml.erb](https://github.com/komoot/opscommander/blob/master/examples/awesome.yaml.erb) for
a complete stack configuration example. Note that the attribute names closely correspond to the attributes
used for the various commands in the [OpsWorks client in the AWS Ruby SDK](http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/OpsWorks/Client.html) - 
familiarity with this and other classes in the AWS Ruby SDK is helpful for understanding how Opscommander works. 

## Commands

All commands have usage instructions:

```
$> opscommander bootstrap --help
```

### Global options

* `--yes`: Automatically accept any input prompts with a "Yes". Useful for CI environments.
* `--verbose`: Enable verbose mode.

Any command that takes a `--config-file` parameter, meaning that it reads stack information from a stack 
configuration file, also takes a `--variables` parameter. These variables are used as template variables 
for the stack configuration file. 

```
$> opscommander bootstrap --config-file examples/awesome.yaml.erb --variables environment=live,tag=latest
```

### bootstrap

Bootstraps an OpsWorks stack from scratch. Optionally creates ELBs and CloudWatch alarms as well, if 
these are configured in the stack configuration file.

##### Options

* `--config-file`: stack configuration file
* `--variables`: template variables for the stack configuration file
* `--start`: start layer after it is created
* `--create-elbs`: create ELBs and CloudWatch alarms as well

##### Example

```
$> opscommander bootstrap --config-file examples/awesome.yaml.erb --variables environment=live,tag=latest --start
```

### delete

Stops all instances in all layers, deletes layers and apps and deletes the stack.

##### Example

```
$> opscommander delete notsoawesome-stack
```

### rename

Renames a stack. Also updates the EC2 instance tags that OpsWorks sets when creating an instance to reflect
the new stack name.

##### Example

```
$> opscommander rename awesome-stack another-stack
```

### create_app

Creates an application, overwriting any application with the same name. The application must be
defined in the stack configuration file.

##### Options

* `--config-file`: stack configuration file
* `--variables`: template variables for the stack configuration file

##### Example

```
$> opscommander create_app --config-file examples/awesome.yaml.erb --variables version=1.23 awesome-app
```

### deploy_app

Runs an OpsWorks deployment of an application on all instances. The application
must be defined in the stack configuration file and must be created in OpsWorks
(see the create_app command). 

For finer-grained control over which instances the application is deployed to,
it is recommended to use an application tag which indicates the layers/instances
it should be deployed to and check for this tag in your deployment recipe. 
See [this blog post](http://blogs.aws.amazon.com/application-management/post/Tx2FPK7NJS5AQC5/Running-Docker-on-AWS-OpsWorks) for 
one example of such an approach.

##### Example

```
$> opscommander deploy_app --config-file examples/awesome.yaml.erb awesome-app
```

### bluegreen

Performs a blue-green deployment using the following pattern:

1. The currently running stack is renamed to \<stack name\>-green.
2. A new \<stack name\>-blue stack is created and started.
3. When the blue stack is online, ELBs are switched over from the green stack. The ELBs will for a short while contain instances from both stacks. This mixed-state duration can be increased with an optional argument, see below.
4. The green stack is stopped and deleted.
5. The blue stack is renamed to \<stack name\> and is now the new live stack.

If the deployment fails, the `bluegreen` command can generally be re-run. It will for example detect if there is already 
\<stack name\>-green stack running and assume that this is the live stack that we want to replace. 

For scenarios with multiple apps and layers, it is recommended to use an application tag which indicates the layers/instances
it should be deployed to and check for this tag in your deployment recipe. See [this blog post](http://blogs.aws.amazon.com/application-management/post/Tx2FPK7NJS5AQC5/Running-Docker-on-AWS-OpsWorks) for 
one example of such an approach.

Note that it in order to avoid downtime, the OpsWorks deployment **should not finish before the application is online and ready to go!** Some polling
may have to be implemented as part of the deployment recipe if the application takes a while to start. 

##### Options

* `--config-file`: stack configuration file
* `--variables`: template variables for the stack configuration file
* `--mixed-state-duration`: desired mixed-state duration, in seconds. In some cases it may be desirable to increase the mixed-state duration, e.g. for warm-up purposes. Default = 0.

##### Example

```
# --yes means any input prompts will automatically be accepted with a "Yes" answer.
# It is a global option that can be used with any command.
$> opscommander bluegreen --config-file examples/awesome.yaml.erb awesome-app
```

### cat

Echoes back the parsed and templated stack configuration file. Useful for debugging your stack configuration.

##### Options

* `--config-file`: stack configuration file
* `--variables`: template variables for the stack configuration file

##### Example

```
$> opscommander cat --config-file examples/awesome.yaml.erb --variables environment=where_does_this_variable_go?
```

### whoami

Uses the current AWS credentials and displays user information.

##### Example

```
$> opscommander whoami
```

## License

Licensed under the Apache License, version 2.0. See [LICENSE](https://github.com/komoot/opscommander/blob/master/LICENSE).

