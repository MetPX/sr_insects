
First flow "A" doing initial download from datamart.

A00. shovel/t_dd1_f00 and t_dd2_f00  
   * shovel messages from a datamart ( https://hpfx.collab.science.gc.ca ) 
   * convert the inbound v02 messages to v03 exchange xwinnow00 and 01 (with post_exchange_split 2).
   * math: amount bounded by limit (default to 1000.) call it L
   * test 1 shovel (establishes L.)

A01. winnow/t00_f10 and t01_f10
   * subscribed to xwinnow00 and xwinnow01 respectively
   * apply duplicate suppression to v03 messages from 1.
   * post to exchange: xsarra
   * math: combined, both should ingest  2*L messages, and combined publish should be L (duplicate suppression.)
   * test 2 winnow.

A02. sarra/download_f20
   * Subscribe to xsarra, 
   * download the files from hpfx.collab 
   * write to local: ${TESTDOCROOT} ( AKA ~/sarra_devdocroot )
   * publishing to exchange: xflow_public .. with base_url = http://localhost:8001
   * math: should be L
   * test 3: sarra (totsarp) 

A03. subscribe/amqp_f30
   * Subscribe to xflow_public, 
   * "download" (via http) 
   * write to ${TESTDOCROOT}/downloaded_by_sub_amqp
   * no posting... so initial AMQP message flow ends here.
   * math: should be L
   * test 5: amqp_f30 ...

Second Flow "B" watches the files by flow A into downloaded_by_sub_amqp

B04. watch/f40
   * look at files in ${TESTDOCROOT}/downloaded_by_sub_amqp.
   * Create new v03 messages for files that arrive or depart 
   * publish to : xs_tsource
   * first wave of files arrives from subscribe/amqp_f30
   * second wave of files comes from B26 shovel/pclean_f90.conf
   * 

B05. sender/tsource2send_f50

   * subscribes to watch output (exchange: xs_tsource ) 
   * sends the files via localhost to the: ${TESTDOCROOT}/sent_by_tsource2send directory.  
   * publish to xs_tsource_output with base_url= sftp://${SFTPUSER}@localhost

B06 subscribe/u_sftp_f60
  * subscribe to xs_tsource_output
  * download via SFTP, placing result in ${TESTDOCROOT}/downloaded_by_sub_u
  * no publish

B15 shovel/rabbitmqtt_f22.conf 
  * subscribe to xs_tsource 
  * post to xs_mqtt_public

B16 subscribe/rabbitmqtt_f31.conf
  * subscribe to xs_mqtt_public
  * download to  ${TESTDOCROOT}/downloaded_by_sub_rabbitmqtt
  * no publish.

B17 subscribe/cp_f61.conf
  * subscribe xs_tsource_output 
  * "download" via "cp" to ${TESTDOCROOT}/downloaded_by_sub_cp
  * no publish.

B26 shovel/pclean_f90.conf
  * subscribe to xs_tsource
  * queue every file for 20 seconds (with msg_fdelay)  
  * all_fxx_dirs = downloaded_by_sub_amqp, downloaded_by_sub_rabbitmqtt, sent_by_tsource2send, downloaded_by_sub_u, downloaded_by_sub_cp, posted_by_shim, posted_by_srpost_test2, recd_by_srpoll_test1
  * check that copies of the file exist in all locations (propagation has occurred.)
  * pick an extension from .slink, .hlink, .moved ...
    * looking at directory: downlloaded_by_sub_amqp.
    * symlink, hardlink, or rename a file as per the extension selected.
    * since that directory is watched, it feeds back to B04.
    * post to: xs_tsource_clean_f90

B27 shovel/pclean_f92.conf
    * subscribe to xs_tsource_clean_f90
    * files here exist everywhere so propation is complete
    * removes all files... in all locations to clean up allow continuous flow.


C06 flow_post.sh .. post/test2_f61.conf
   * post to xs_tsource_post
   * announcing FTP urls.


C07. subscribe/ftp_f70.conf
   * subscribe to xs_tsource_post
   * download via ftp via localhost to: ${TESTDOCROOT}/posted_by_srpost_test2
   * no post.

D06 poll/f62.conf
   * polls sftp://SFTPUSER@localhost/${TESTDOCROOT}/sent_by_tsource2send.
   * posts what it finds to xs_tsource_poll

D07. subscribe/q_f71.conf
   * subscribe to xs_tsource_poll
   * download via scp?  to: ${TESTDOCROOT}/recd_by_srpoll_test1
   * no post.


E06 flow_post.sh ... post/shim_f63 
   * flow_post.sh load shim library
   * run ls of sent_by_tsource2send  from time to time.
   * calculate a diff file to see new stuff that showed up.
   * cp files to ${httpdocroot}/posted_by_shim
   * post to xs_tsource_shim





