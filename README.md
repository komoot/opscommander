OpsWorks deployment tool
============

Bootstraps, Tests and Deploys OpsWorks stacks with different strategies (blue/green, rolling, quick)

### Dependencies ###
```
$> sudo gem install bundler
$> xcode-select --install
```

### Installation

```
$> gem build opscommander.gemspec
$> gem install opscommander-0.1.0.gem
``` 

### Run without installing

```
$> bundle install
$> ruby -Ilib bin/opscommander ... 
```




