
A suite of integration tests for Sarracenia and Sarrac packages.

The sampledata directory contains some data captured from the original data mart,
so that it can be replayed at will and behaviour of both the C and python implementations
confirmed.


* tests/ directory contains unit tests for python modules (from Sarracenia)

* polling/   Test a few cases of polling configurations, with sarra/subscriber consumers.

* static_flow/  is the simplest integration test. Confirms the basic functioning of both C and python units.
  Only single instances are used, message forwarding (consuming and posting) is confirmed, posting from files.
  This test is self-contained on the host running it, reading files from the sampledata directory, and posting
  it to one tree, and then a few more.

* flaky_boker/  adds broker restarts in the middle of the static_flow test to validate robustness.  Otherwise
  intended to be identical to static_flow.

* dynamic_flow/  subscribes to a datamart, and obtains a configurable number of files from that live datamart.
  It broadens the areas under test when compared to static_flow by adding:  winnowing, the use of multiple instances
  for many components, and testing of the sr_retry by faking download failures. It is the most complex test
  in the suite, and the ancestor of the others.
  
