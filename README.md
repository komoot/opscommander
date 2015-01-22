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
$> gem install opscommander-1.0.4.gem
``` 

### Run without installing

It is also possible to run Opscommander directly with `ruby`:

```
$> bundle install
$> ruby -Ilib bin/opscommander ... 
```

### Access credentials

Opscommander uses the Ruby AWS SDK internally. For more information on how to provide access credentials
to the SDK, see the [SDK documentation](http://docs.aws.amazon.com/AWSSdkDocsRuby/latest//DeveloperGuide/prog-basics-creds.html).

### Running in AWS cloud

If you decide to run Opscommander in the AWS cloud, for example as part of a continuous deployment setup,
you should be aware that the instance profile of the instance that Opscommander runs on needs to include 
EC2, ELB and OpsWorks full access policies.

## Stack configuration

See [awesome.yaml.erb](https://github.com/komoot/opscommander/blob/master/examples/awesome.yaml.erb) for
a complete stack configuration example. Note that the attribute names closely correspond to the attributes
used for the various commands in the (OpsWorks client in the AWS Ruby SDK)[http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/OpsWorks/Client.html] - 
familiarity with this and other classes in the AWS Ruby SDK is helpful for understanding how Opscommander works. 

## Commands

All commands have usage instructions:

```
$> opscommander bootstrap --help
```

Any command that takes a `--config-file` parameter, meaning that it reads stack information from a stack 
configuration file, also takes a `--variables` parameter. These variables are used as template variables 
for the stack configuration file. 

```
$> opscommander bootstrap --config-file examples/awesome.yaml.erb --variables environment=live,tag=latest
```

### bootstrap

Bootstraps an OpsWorks stack from scratch. Optionally creates ELBs and CloudWatch alarms as well, if 
these are configured in the stack configuration file.

#### Options

* `--config-file`: stack configuration file
* `--variables`: template variables for the stack configuration file
* `--start`: start layer after it is created
* `--create-elbs': create ELBs and CloudWatch alarms as well

#### Example

```
$> opscommander bootstrap --config-file examples/awesome.yaml.erb --variables environment=live,tag=latest --start
```

### delete

Stops all instances in all layers, deletes layers and apps and deletes the stack.

#### Example

```
$> opscommander delete notsoawesome-stack
```

### rename

Renames a stack. Also updates the EC2 instance tags that OpsWorks sets when creating an instance to reflect
the new stack name. Triggers the "Configuration" OpsWorks lifecycle event which you can hook into for e.g. 
updating logging configuration, if the stack name is used there.

#### Example

```
$> opscommander rename awesome-stack another-stack
```


