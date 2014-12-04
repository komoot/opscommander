OpsWorks deployment tool
============

Bootstraps, Tests and Deploys OpsWorks stacks with different strategies (blue/green, rolling, quick)

### Dependencies ###
```
$> sudo gem install bundler
$> xcode-select --install
```

### Installation ###

```
$> gem build opscommander.gemspec
$> gem install opscommander-0.1.0.gem
``` 

### Run without installing ###

```
$> bundle install
$> ruby -Ilib bin/opscommander ... 
```

### Running in AWS cloud ###

The instance that opscommander runs on needs EC2 (ELB) and OpsWorks full access policies.

### Example Usage ###

```
ruby -Ilib bin/opscommander bluegreen --config-file wanderwalter.yml.erb --variables environment=live,version=1.xx
```


