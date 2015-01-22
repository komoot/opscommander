Opscommander
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

(example stack configuration here)

## Commands

### blue_green



### Example Usage ###

```
ruby -Ilib bin/opscommander bluegreen --config-file wanderwalter.yml.erb --variables environment=live,version=1.xx
```


