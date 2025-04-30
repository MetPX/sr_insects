SR_INSECTS test for SR3
=======================

The sr_insects repository contains a collection of integration tests to
validate behaviour of Sarracenia.

The group of tests is expected to run on a stand-alone VM or container.
It is used by the Github Actions for the sarracenia package. These tests build
pumps configurations where an initial set of files are posted and repeatedly copied
in different ways to exercise different code paths.

The tests demonstrate different, progressively more complex, functionality in the sr3
application. testing should start with the first one, and if it fails, fix
that one before progressing.

Tests:

* static_flow/flow_maint_test.sh

  Test installs an rabbitmq broker, and configures it for use.
  Test runs through a complex set of declarations with administrative permissions. 
  Test runs rudimentary API tests. 
  Whenever the API changes, this test must be updated. 

* static_flow

  There is a directory tree of sample files used for localized testing.
  Test installs a pair of local file posters to post that tree.
  Other configurations are subscribers to those posts.
  Tests winnowing (duplicate suppression.), all normal single process flows.
  single subscriber, and single publisher, single instance (process) per component flow.
  
* multi_static_flow

  Using the static data set, configure several components with multiple 
  publishers and subscribers for a single configuration.
  This test uses both mqtt and amqp brokers explicitly, publishing and subscribing
  to both at various times.

* flakey_broker

  Run the same tests as static, but stop and restart the broker three times during 
  the test. Looks for message loss in failure processing.

* restart_server

  Run the same tests as static, but stop and restart sr3 multiple times during the test.

* dynamic_flow

  instead of posting local files, subscribe to public datamarts with two shovels.
  The default number of messages to download from each datamart is 700.
  A numeric argument given to flow_limit.sh will change that default.

  flows here are similar to the ones in static, except the source is remote,
  and many components run as multiple instances (aka collaborating processes on
  each component flow configurations.)



Generalities:
-------------

How the flow tests generally work:

* flow_maint invocation:
  ( https://github.com/MetPX/sarracenia/blob/development/.github/workflows/flow_basic.yml )

* Rest of these tests are invoked as a matrix by:
  ( https://github.com/MetPX/sarracenia/blob/development/.github/workflows/flow.yml )

Essentially:

the script runs code from the sr3 repo to set the VM or container up:

```

    travis/flow_autoconfig.sh -- configure a plain old ubuntu vm adding a rabbitmq.
    travis/flow_autoconfig_add_mosquitto.sh -- add a mosquitto broker to the vm. (if desired.)
    travis/ssh_localhost.sh  -- enable passwordless ssh through localhost.
    cd sr_insects/*test*
    ./flow_setup.sh -- install the configurations, do the declarations, start the tests.
    ./flow_limit.sh -- monitor the tests, return when finished.
    ./flow_check.sh -- collate, print a summary of results.
    ./flow_cleanup.sh -- remove queue/exchange definitions from broker (reset to pristine.)

```

Developers are expected to run a large swath, preferably all, of these tests as part of 
their routine work prior to submitting a pull request.  The tests will be run to verify
that using github actions, whenever a PR is opened.

Most tests use the rabbitmq broker alone.  By changing the MQP setting in 
~/.config/sr3/default.conf to be mqtt instead of amqp before invoking ./flow_setup.sh,
the tests will run using mqtt for local component traffic where possible.

When there are failed tests, the primary source for debugging, is the log files
placed under ~/.cache.

each flow test may have a doc/ subdirectory with additional information.
Typically, a .dia file (usable by gnome dia) gives a diagram of the relationships
between the components in the test flows.


Tests Wanted
------------


winnowing
~~~~~~~~~
test winnowing by itself, using mutliple posts, and and a winnow... no downloading needed.


Polling
~~~~~~~ 

Unit testing...  of various 

