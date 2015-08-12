#### 1.0.11

- Pre-launch same number of load instances as in the green layer when doing blue-green deployments.

#### 1.0.10

- Disable time-based auto-scaling when shutting down layer.

#### 1.0.9

- Support for time-based auto-scaling. Times are in UTC, see the [sample YAML config](https://github.com/komoot/opscommander/blob/master/examples/awesome.yaml.erb) for a complete example:

```
time_based_auto_scaling:
  default:
    saturday: 10-16
    sunday: 8-20

```

#### 1.0.8

- Apps can now have secret environment variables.

#### 1.0.7

- For blue-green deployments, load-based auto scaling is enabled only after the deployment is finished. This may help to avoid unnecessary load-based scaling directly after deployment.

#### 1.0.6

- Don't trigger Configure event on stack renaming, as this is a potentially expensive operation to perform right after boot.

#### 1.0.5

- Allow a configurable mixed state period during blue-green deploys.

#### 1.0.4

- Bugfix: multiple apps now supported.

#### 1.0.3

- Initial stable release.



